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
  # into one map (keyed "cp-<idx>"/"w-<idx>" to match each apply resource's
  # for_each) so the guard logic lives in exactly one place. null, empty, or
  # whitespace-only hostnames are a no-op (Talos keeps its auto-generated name);
  # non-blank values are trimmed. try() covers trimspace against the null case.
  # (fixes #56)
  hostname_nodes = merge(
    { for idx, node in var.control_plane : "cp-${idx}" => node },
    { for idx, node in var.workers : "w-${idx}" => node },
  )
  hostname_patches = {
    for key, node in local.hostname_nodes : key => (
      try(trimspace(node.hostname), "") != "" ? [
        yamlencode({ machine = { network = { hostname = trimspace(node.hostname) } } })
      ] : []
    )
  }
}

# Generate machine secrets (PKI)
resource "talos_machine_secrets" "this" {}

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
  for_each = { for idx, node in var.control_plane : idx => node }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.host

  # Per-node hostname patch, computed once in local.hostname_patches.
  config_patches = local.hostname_patches["cp-${each.key}"]
}

# Apply configuration to worker nodes
resource "talos_machine_configuration_apply" "worker" {
  for_each = { for idx, node in var.workers : idx => node }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[0].machine_configuration
  node                        = each.value.host

  # Per-node hostname patch, computed once in local.hostname_patches.
  config_patches = local.hostname_patches["w-${each.key}"]
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
