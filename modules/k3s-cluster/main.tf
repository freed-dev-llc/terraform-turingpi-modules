# Generate cluster token if not provided
resource "random_password" "cluster_token" {
  count   = var.cluster_token == "" ? 1 : 0
  length  = 64
  special = false
}

locals {
  cluster_token = var.cluster_token != "" ? var.cluster_token : random_password.cluster_token[0].result
  api_endpoint  = "https://${var.control_plane.host}:6443"

  # Build K3s server install arguments
  k3s_server_args = compact(concat(
    var.disable_traefik ? ["--disable=traefik"] : [],
    var.disable_servicelb ? ["--disable=servicelb"] : [],
    var.disable_local_storage ? ["--disable=local-storage"] : [],
    var.flannel_backend != "vxlan" ? ["--flannel-backend=${var.flannel_backend}"] : [],
    var.cluster_cidr != "10.42.0.0/16" ? ["--cluster-cidr=${var.cluster_cidr}"] : [],
    var.service_cidr != "10.43.0.0/16" ? ["--service-cidr=${var.service_cidr}"] : [],
    var.cluster_dns != "10.43.0.10" ? ["--cluster-dns=${var.cluster_dns}"] : [],
    ["--write-kubeconfig-mode=644"],
    var.extra_server_args
  ))

  k3s_server_args_str = join(" ", local.k3s_server_args)
  k3s_agent_args_str  = join(" ", var.extra_agent_args)

  # Cross-node hostname uniqueness (#68). A duplicate hostname makes two nodes
  # register in Kubernetes under the same node identity (kubelet registration
  # collision — one node shadows the other) with no plan-time signal. The
  # per-variable validation blocks can only check format within one variable,
  # so uniqueness across control_plane + workers is asserted by a precondition
  # on null_resource.k3s_control_plane (always present). control_plane is a
  # single object, so it's wrapped before concat. Compare the compacted,
  # trimmed hostnames; null/empty/whitespace stay exempt (no-op).
  all_hostnames = compact([
    for node in concat([var.control_plane], var.workers) : try(trimspace(node.hostname), "")
  ])
  duplicate_hostnames = distinct([
    for h in local.all_hostnames : h
    if length([for x in local.all_hostnames : x if x == h]) > 1
  ])
}

# =============================================================================
# SSH Key Bootstrap
# =============================================================================
# When both ssh_key AND ssh_password are supplied for a node, push the public
# key (derived from ssh_key) into the node's authorized_keys via a one-shot
# password-auth session before anything else runs. Fixes #30 — fresh Armbian
# images come with only the default root/1234 credentials and no way to
# authenticate the user's private key on the very first connection.
# Idempotent: grep -qxF before appending, so re-runs are no-ops.

data "tls_public_key" "cp_bootstrap" {
  count           = (var.control_plane.ssh_key != null && var.control_plane.ssh_password != null) ? 1 : 0
  private_key_pem = var.control_plane.ssh_key
}

data "tls_public_key" "workers_bootstrap" {
  # Keyed by host (not list index) so removing/reordering a worker doesn't
  # re-run provisioners against a shifted host (#69).
  for_each        = { for w in var.workers : w.host => w if w.ssh_key != null && w.ssh_password != null }
  private_key_pem = each.value.ssh_key
}

resource "null_resource" "bootstrap_ssh_cp" {
  count = (var.control_plane.ssh_key != null && var.control_plane.ssh_password != null) ? 1 : 0

  triggers = {
    host   = var.control_plane.host
    pubkey = data.tls_public_key.cp_bootstrap[0].public_key_openssh
  }

  connection {
    type     = "ssh"
    host     = var.control_plane.host
    user     = var.control_plane.ssh_user
    password = var.control_plane.ssh_password
    port     = var.control_plane.ssh_port
    timeout  = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh && chmod 700 ~/.ssh",
      "touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys",
      "grep -qxF '${trimspace(data.tls_public_key.cp_bootstrap[0].public_key_openssh)}' ~/.ssh/authorized_keys || echo '${trimspace(data.tls_public_key.cp_bootstrap[0].public_key_openssh)}' >> ~/.ssh/authorized_keys",
    ]
  }
}

resource "null_resource" "bootstrap_ssh_workers" {
  # Keyed by host (not list index) — see data.tls_public_key.workers_bootstrap (#69).
  for_each = { for w in var.workers : w.host => w if w.ssh_key != null && w.ssh_password != null }

  triggers = {
    host   = each.value.host
    pubkey = data.tls_public_key.workers_bootstrap[each.key].public_key_openssh
  }

  connection {
    type     = "ssh"
    host     = each.value.host
    user     = each.value.ssh_user
    password = each.value.ssh_password
    port     = each.value.ssh_port
    timeout  = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh && chmod 700 ~/.ssh",
      "touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys",
      "grep -qxF '${trimspace(data.tls_public_key.workers_bootstrap[each.key].public_key_openssh)}' ~/.ssh/authorized_keys || echo '${trimspace(data.tls_public_key.workers_bootstrap[each.key].public_key_openssh)}' >> ~/.ssh/authorized_keys",
    ]
  }
}

# =============================================================================
# Control Plane Installation
# =============================================================================

# Prepare and install K3s on control plane
resource "null_resource" "k3s_control_plane" {
  depends_on = [null_resource.bootstrap_ssh_cp]

  lifecycle {
    # Fail the plan when two nodes share a non-blank hostname (#68).
    precondition {
      condition     = length(local.duplicate_hostnames) == 0
      error_message = "Node hostnames must be unique across control_plane and workers. Duplicate hostname(s): ${join(", ", local.duplicate_hostnames)}."
    }
  }

  triggers = {
    host               = var.control_plane.host
    k3s_version        = var.k3s_version
    server_args        = local.k3s_server_args_str
    nvme_enabled       = var.nvme_storage_enabled
    local_path_default = var.local_path_default
  }

  connection {
    type        = "ssh"
    host        = var.control_plane.host
    user        = var.control_plane.ssh_user
    private_key = var.control_plane.ssh_key
    password    = var.control_plane.ssh_password
    port        = var.control_plane.ssh_port
    timeout     = "5m"
  }

  # Set hostname BEFORE installing k3s. Fresh Armbian flashes all default
  # to "turing-rk1", which collides with k3s's hostname-based node identity
  # and causes worker joins to fail with "Node password rejected, duplicate
  # hostname" (fixes #31). No-op when the optional hostname is null, empty, or
  # whitespace-only (try() guards trimspace against the null case); the trimmed
  # value is shell-quoted to guard against word-splitting.
  provisioner "remote-exec" {
    inline = try(trimspace(var.control_plane.hostname), "") != "" ? [
      "#!/bin/bash",
      "set -e",
      "echo \"=== Setting hostname to ${trimspace(var.control_plane.hostname)} ===\"",
      "hostnamectl set-hostname \"${trimspace(var.control_plane.hostname)}\"",
      "if grep -qE '^127\\.0\\.1\\.1[[:space:]]' /etc/hosts; then sed -i -E 's/^127\\.0\\.1\\.1[[:space:]].*/127.0.1.1 ${trimspace(var.control_plane.hostname)}/' /etc/hosts; else echo \"127.0.1.1 ${trimspace(var.control_plane.hostname)}\" >> /etc/hosts; fi",
      ] : [
      "echo 'No hostname override for control plane (current: '$(hostname)')'"
    ]
  }

  # Install packages
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -e",
      "export DEBIAN_FRONTEND=noninteractive",
      "echo '=== Installing required packages ==='",
      "apt-get update -qq",
      var.install_open_iscsi ? "apt-get install -y -qq open-iscsi && systemctl enable --now iscsid" : "echo 'Skipping open-iscsi'",
      var.install_nfs_common ? "apt-get install -y -qq nfs-common" : "echo 'Skipping nfs-common'",
      "apt-get install -y -qq curl parted",
    ]
  }

  # Configure NVMe (if enabled)
  provisioner "remote-exec" {
    inline = var.nvme_storage_enabled && var.nvme_control_plane ? [
      "#!/bin/bash",
      "set -e",
      "echo '=== Configuring NVMe storage ==='",
      "if [ ! -b ${var.nvme_device} ]; then echo 'NVMe device ${var.nvme_device} not found, skipping'; exit 0; fi",
      "if mountpoint -q ${var.nvme_mountpoint} 2>/dev/null; then echo 'NVMe already mounted at ${var.nvme_mountpoint}'; exit 0; fi",
      "if [ ! -b ${var.nvme_device}p1 ]; then echo 'Creating partition on ${var.nvme_device}'; parted -s ${var.nvme_device} mklabel gpt; parted -s ${var.nvme_device} mkpart primary ${var.nvme_filesystem} 0% 100%; sleep 2; partprobe ${var.nvme_device}; fi",
      "if ! blkid ${var.nvme_device}p1 2>/dev/null | grep -q 'TYPE='; then echo 'Formatting ${var.nvme_device}p1 as ${var.nvme_filesystem}'; mkfs.${var.nvme_filesystem} ${var.nvme_device}p1; fi",
      "mkdir -p ${var.nvme_mountpoint}",
      "mount ${var.nvme_device}p1 ${var.nvme_mountpoint}",
      "if ! grep -q '${var.nvme_device}p1' /etc/fstab; then echo '${var.nvme_device}p1 ${var.nvme_mountpoint} ${var.nvme_filesystem} defaults,nofail 0 2' >> /etc/fstab; fi",
      "echo 'NVMe configured at ${var.nvme_mountpoint}'"
    ] : ["echo 'NVMe not enabled for control plane'"]
  }

  # Install K3s server
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -e",
      "echo '=== Installing K3s server ==='",
      "swapoff -a || true",
      "sed -i '/swap/d' /etc/fstab 2>/dev/null || true",
      "if systemctl is-active --quiet k3s 2>/dev/null; then echo 'K3s server already running'; kubectl get nodes; exit 0; fi",
      "echo 'Installing K3s ${var.k3s_version != "" ? var.k3s_version : "latest"}...'",
      "curl -sfL https://get.k3s.io | ${var.k3s_version != "" ? "INSTALL_K3S_VERSION='${var.k3s_version}'" : ""} K3S_TOKEN='${local.cluster_token}' sh -s - server ${local.k3s_server_args_str}",
      "echo 'Waiting for K3s to be ready...'",
      "for i in $(seq 1 60); do if kubectl get nodes 2>/dev/null | grep -q ' Ready'; then echo 'K3s server is ready!'; kubectl get nodes; exit 0; fi; echo \"Waiting... ($i/60)\"; sleep 5; done",
      "echo 'ERROR: Timeout waiting for K3s'",
      "exit 1"
    ]
  }

  # Ensure a single default StorageClass: when local_path_default is false (and
  # local-storage isn't disabled outright), make K3s's built-in local-path
  # non-default so a separately-installed default (e.g. Longhorn) is the sole
  # default — avoiding the "two default StorageClasses" ambiguity (#51).
  #
  # A bare `kubectl annotate` is NOT durable: K3s re-applies its bundled
  # local-storage manifest (which hardcodes is-default-class=true) on every
  # restart, reverting it. So we first drop a `.skip` beside the bundled
  # manifest — K3s then stops re-applying it, and per the K3s docs `.skip` does
  # NOT remove the already-created resources, so the local-path provisioner + SC
  # keep working — then clear the default annotation, which now sticks across
  # restarts. We wait for the SC first so we only skip after it exists.
  # Trade-off: local-path is no longer managed by K3s (won't auto-upgrade).
  # Idempotent: touch + annotate --overwrite are no-ops on re-run.
  provisioner "remote-exec" {
    inline = (!var.local_path_default && !var.disable_local_storage) ? [
      "#!/bin/bash",
      "set -e",
      "echo '=== Making local-path non-default durably (#51) ==='",
      "for i in $(seq 1 30); do kubectl get sc local-path >/dev/null 2>&1 && break; echo \"waiting for local-path SC ($i/30)\"; sleep 2; done",
      "touch /var/lib/rancher/k3s/server/manifests/local-storage.yaml.skip",
      "kubectl annotate sc local-path storageclass.kubernetes.io/is-default-class=false --overwrite || echo 'local-path SC not present; nothing to unset'",
      ] : [
      "echo 'local-path remains default StorageClass (local_path_default=${var.local_path_default})'"
    ]
  }
}

# =============================================================================
# Worker Installation
# =============================================================================

# Prepare and install K3s agent on workers
resource "null_resource" "k3s_workers" {
  # Keyed by host (not list index) so removing/reordering a worker doesn't
  # shift the keys of the remaining workers and re-run the install provisioners
  # against a different node (#69). each.key is the host in the log lines below.
  for_each = { for worker in var.workers : worker.host => worker }

  depends_on = [
    null_resource.k3s_control_plane,
    null_resource.bootstrap_ssh_workers,
  ]

  triggers = {
    host         = each.value.host
    k3s_version  = var.k3s_version
    server_host  = var.control_plane.host
    nvme_enabled = var.nvme_storage_enabled
  }

  connection {
    type        = "ssh"
    host        = each.value.host
    user        = each.value.ssh_user
    private_key = each.value.ssh_key
    password    = each.value.ssh_password
    port        = each.value.ssh_port
    timeout     = "5m"
  }

  # Set hostname BEFORE installing the k3s agent — see comment on the
  # control plane equivalent (fixes #31).
  provisioner "remote-exec" {
    inline = try(trimspace(each.value.hostname), "") != "" ? [
      "#!/bin/bash",
      "set -e",
      "echo \"=== Setting hostname to ${trimspace(each.value.hostname)} on worker ${each.key} ===\"",
      "hostnamectl set-hostname \"${trimspace(each.value.hostname)}\"",
      "if grep -qE '^127\\.0\\.1\\.1[[:space:]]' /etc/hosts; then sed -i -E 's/^127\\.0\\.1\\.1[[:space:]].*/127.0.1.1 ${trimspace(each.value.hostname)}/' /etc/hosts; else echo \"127.0.1.1 ${trimspace(each.value.hostname)}\" >> /etc/hosts; fi",
      ] : [
      "echo 'No hostname override for worker ${each.key} (current: '$(hostname)')'"
    ]
  }

  # Install packages
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -e",
      "export DEBIAN_FRONTEND=noninteractive",
      "echo '=== Installing required packages on worker ${each.key} ==='",
      "apt-get update -qq",
      var.install_open_iscsi ? "apt-get install -y -qq open-iscsi && systemctl enable --now iscsid" : "echo 'Skipping open-iscsi'",
      var.install_nfs_common ? "apt-get install -y -qq nfs-common" : "echo 'Skipping nfs-common'",
      "apt-get install -y -qq curl parted",
    ]
  }

  # Configure NVMe (if enabled)
  provisioner "remote-exec" {
    inline = var.nvme_storage_enabled ? [
      "#!/bin/bash",
      "set -e",
      "echo '=== Configuring NVMe storage on worker ${each.key} ==='",
      "if [ ! -b ${var.nvme_device} ]; then echo 'NVMe device ${var.nvme_device} not found, skipping'; exit 0; fi",
      "if mountpoint -q ${var.nvme_mountpoint} 2>/dev/null; then echo 'NVMe already mounted at ${var.nvme_mountpoint}'; exit 0; fi",
      "if [ ! -b ${var.nvme_device}p1 ]; then echo 'Creating partition on ${var.nvme_device}'; parted -s ${var.nvme_device} mklabel gpt; parted -s ${var.nvme_device} mkpart primary ${var.nvme_filesystem} 0% 100%; sleep 2; partprobe ${var.nvme_device}; fi",
      "if ! blkid ${var.nvme_device}p1 2>/dev/null | grep -q 'TYPE='; then echo 'Formatting ${var.nvme_device}p1 as ${var.nvme_filesystem}'; mkfs.${var.nvme_filesystem} ${var.nvme_device}p1; fi",
      "mkdir -p ${var.nvme_mountpoint}",
      "mount ${var.nvme_device}p1 ${var.nvme_mountpoint}",
      "if ! grep -q '${var.nvme_device}p1' /etc/fstab; then echo '${var.nvme_device}p1 ${var.nvme_mountpoint} ${var.nvme_filesystem} defaults,nofail 0 2' >> /etc/fstab; fi",
      "echo 'NVMe configured on worker ${each.key}'"
    ] : ["echo 'NVMe not enabled'"]
  }

  # Install K3s agent
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -e",
      "echo '=== Installing K3s agent on worker ${each.key} ==='",
      "swapoff -a || true",
      "sed -i '/swap/d' /etc/fstab 2>/dev/null || true",
      "if systemctl is-active --quiet k3s-agent 2>/dev/null; then echo 'K3s agent already running'; exit 0; fi",
      "echo 'Installing K3s agent...'",
      "curl -sfL https://get.k3s.io | ${var.k3s_version != "" ? "INSTALL_K3S_VERSION='${var.k3s_version}'" : ""} K3S_URL='https://${var.control_plane.host}:6443' K3S_TOKEN='${local.cluster_token}' sh -s - agent ${local.k3s_agent_args_str}",
      "echo 'K3s agent installed on worker ${each.key}'"
    ]
  }
}

# Wait for all workers to be ready
resource "null_resource" "wait_for_cluster" {
  count = length(var.workers) > 0 ? 1 : 0

  depends_on = [null_resource.k3s_workers]

  triggers = {
    worker_count = length(var.workers)
  }

  connection {
    type        = "ssh"
    host        = var.control_plane.host
    user        = var.control_plane.ssh_user
    private_key = var.control_plane.ssh_key
    password    = var.control_plane.ssh_password
    port        = var.control_plane.ssh_port
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "echo '=== Waiting for all ${length(var.workers) + 1} nodes to be ready ==='",
      "EXPECTED=$((1 + ${length(var.workers)}))",
      "for i in $(seq 1 60); do READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready' || echo 0); echo \"Ready nodes: $READY / $EXPECTED (attempt $i/60)\"; if [ \"$READY\" -ge \"$EXPECTED\" ]; then echo 'All nodes are ready!'; kubectl get nodes -o wide; exit 0; fi; sleep 5; done",
      "echo 'Warning: Timeout waiting for all nodes'",
      "kubectl get nodes -o wide",
      "exit 0"
    ]
  }
}

# =============================================================================
# Kubeconfig Management
# =============================================================================

# Materialize the control-plane SSH key to a 0600 tempfile so the scp
# in null_resource.fetch_kubeconfig can pass -i. Terraform's connection
# block accepts PEM contents directly; scp does not, so we have to land
# the bytes on disk first (fixes #32).
resource "local_sensitive_file" "fetch_kubeconfig_key" {
  count           = var.control_plane.ssh_key != null ? 1 : 0
  content         = var.control_plane.ssh_key
  filename        = "${path.module}/.fetch_kubeconfig_id"
  file_permission = "0600"
}

# Fetch kubeconfig from control plane
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [
    null_resource.k3s_control_plane,
    null_resource.wait_for_cluster,
    local_sensitive_file.fetch_kubeconfig_key,
  ]

  triggers = {
    control_plane_id = null_resource.k3s_control_plane.id
  }

  connection {
    type        = "ssh"
    host        = var.control_plane.host
    user        = var.control_plane.ssh_user
    private_key = var.control_plane.ssh_key
    password    = var.control_plane.ssh_password
    port        = var.control_plane.ssh_port
    timeout     = "2m"
  }

  # Copy kubeconfig and modify server address
  provisioner "remote-exec" {
    inline = [
      "cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/${var.control_plane.host}/g' | sed 's/localhost/${var.control_plane.host}/g' > /tmp/kubeconfig-external.yaml",
      "cat /var/lib/rancher/k3s/server/node-token > /tmp/node-token.txt"
    ]
  }

  # Fetch kubeconfig to local. IdentitiesOnly=yes prevents an agent-loaded
  # key from being tried instead of the one we explicitly pass.
  provisioner "local-exec" {
    command = <<-EOT
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${var.control_plane.ssh_key != null ? "-i ${path.module}/.fetch_kubeconfig_id -o IdentitiesOnly=yes" : ""} \
        -P ${var.control_plane.ssh_port} \
        ${var.control_plane.ssh_user}@${var.control_plane.host}:/tmp/kubeconfig-external.yaml \
        ${path.module}/.kubeconfig.tmp
    EOT
  }

  # Wipe the on-disk key copy as soon as scp finishes.
  provisioner "local-exec" {
    command = "rm -f ${path.module}/.fetch_kubeconfig_id"
  }
}

# Read kubeconfig
data "local_file" "kubeconfig" {
  depends_on = [null_resource.fetch_kubeconfig]
  filename   = "${path.module}/.kubeconfig.tmp"
}

# Write kubeconfig to specified path if provided
resource "local_file" "kubeconfig" {
  count           = var.kubeconfig_path != null ? 1 : 0
  depends_on      = [data.local_file.kubeconfig]
  content         = data.local_file.kubeconfig.content
  filename        = var.kubeconfig_path
  file_permission = "0600"
}
