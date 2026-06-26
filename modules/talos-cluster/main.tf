# Generate NVMe config patch if enabled
locals {
  nvme_config_patch = var.nvme_storage_enabled ? yamlencode({
    machine = {
      disks = [
        {
          device = var.nvme_device
          partitions = [
            {
              mountpoint = var.nvme_mountpoint
            }
          ]
        }
      ]
    }
  }) : null

  # Combine user patches with NVMe patch
  controlplane_patches_combined = var.nvme_storage_enabled && var.nvme_control_plane ? concat(
    var.controlplane_patches,
    [local.nvme_config_patch]
  ) : var.controlplane_patches

  worker_patches_combined = var.nvme_storage_enabled ? concat(
    var.worker_patches,
    [local.nvme_config_patch]
  ) : var.worker_patches

  # Per-node hostname patch. The role config above is shared across nodes, so
  # machine.network.hostname is applied per node here. Both roles are merged
  # into one map keyed by node host — matching each apply resource's
  # host-keyed for_each (#69) — so the guard logic lives in exactly one place.
  # null, empty, or whitespace-only hostnames are a no-op (Talos keeps its
  # auto-generated name); non-blank values are trimmed. try() covers trimspace
  # against the null case. (fixes #56)
  hostname_nodes = merge(
    { for node in var.control_plane : node.host => node },
    { for node in var.workers : node.host => node },
  )
  hostname_patches = {
    for host, node in local.hostname_nodes : host => (
      try(trimspace(node.hostname), "") != "" ? [
        yamlencode({ machine = { network = { hostname = trimspace(node.hostname) } } })
      ] : []
    )
  }

  # Cross-node hostname uniqueness (#68). A duplicate hostname makes two nodes
  # register in Talos/Kubernetes under the same node identity (kubelet
  # registration collision — one node shadows the other) with no plan-time
  # signal. The per-variable validation blocks can only check format within
  # one variable, so uniqueness across control_plane + workers is asserted by
  # a precondition on talos_machine_secrets.this (always present). Compare the
  # compacted, trimmed hostnames; null/empty/whitespace stay exempt (no-op).
  all_hostnames = compact([
    for node in concat(var.control_plane, var.workers) : try(trimspace(node.hostname), "")
  ])
  duplicate_hostnames = distinct([
    for h in local.all_hostnames : h
    if length([for x in local.all_hostnames : x if x == h]) > 1
  ])
}

# Generate machine secrets (PKI)
resource "talos_machine_secrets" "this" {
  lifecycle {
    # Fail the plan when two nodes share a non-blank hostname (#68).
    precondition {
      condition     = length(local.duplicate_hostnames) == 0
      error_message = "Node hostnames must be unique across control_plane and workers. Duplicate hostname(s): ${join(", ", local.duplicate_hostnames)}."
    }
  }
}

# Generate control plane machine configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = local.controlplane_patches_combined
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

# Generate worker machine configuration
data "talos_machine_configuration" "worker" {
  count = length(var.workers) > 0 ? 1 : 0

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = local.worker_patches_combined
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

# Apply configuration to control plane nodes
resource "talos_machine_configuration_apply" "controlplane" {
  # Keyed by host (not list index) so removing/reordering a node doesn't shift
  # the keys of the remaining nodes and force a config re-push to live nodes (#69).
  for_each = { for node in var.control_plane : node.host => node }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.host

  # Per-node hostname patch, computed once in local.hostname_patches (keyed by host).
  config_patches = local.hostname_patches[each.key]
}

# Apply configuration to worker nodes
resource "talos_machine_configuration_apply" "worker" {
  # Keyed by host (not list index) — see the control-plane apply above (#69).
  for_each = { for node in var.workers : node.host => node }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[0].machine_configuration
  node                        = each.value.host

  # Per-node hostname patch, computed once in local.hostname_patches (keyed by host).
  config_patches = local.hostname_patches[each.key]
}

# Bootstrap the cluster (first control plane only)
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_plane[0].host
}

# Get kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_plane[0].host
}

# Write kubeconfig to file if path specified
resource "local_file" "kubeconfig" {
  count           = var.kubeconfig_path != null ? 1 : 0
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = var.kubeconfig_path
  file_permission = "0600"
}

# Write talosconfig to file if path specified
# Format: proper talosctl YAML with context, endpoints, and nodes
resource "local_file" "talosconfig" {
  count = var.talosconfig_path != null ? 1 : 0
  content = yamlencode({
    context = var.cluster_name
    contexts = {
      (var.cluster_name) = {
        endpoints = [for node in var.control_plane : node.host]
        nodes = concat(
          [for node in var.control_plane : node.host],
          [for node in var.workers : node.host]
        )
        ca  = talos_machine_secrets.this.client_configuration.ca_certificate
        crt = talos_machine_secrets.this.client_configuration.client_certificate
        key = talos_machine_secrets.this.client_configuration.client_key
      }
    }
  })
  filename        = var.talosconfig_path
  file_permission = "0600"
}
