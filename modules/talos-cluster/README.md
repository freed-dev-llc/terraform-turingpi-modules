# Turing Pi Talos Cluster Module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest/submodules/talos-cluster)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to deploy a Talos Kubernetes cluster on Turing Pi 2.5 nodes using the native [Talos Terraform Provider](https://registry.terraform.io/providers/siderolabs/talos/latest).

## Usage

```hcl
module "cluster" {
  source  = "freed-dev-llc/modules/turingpi//modules/talos-cluster"
  version = ">= 1.3.0"

  cluster_name     = "my-cluster"
  cluster_endpoint = "https://192.168.1.101:6443"

  # Pin versions to match your Talos image
  talos_version      = "v1.9.2"
  kubernetes_version = "v1.32.1"

  control_plane = [
    { host = "192.168.1.101", hostname = "cp1" }
  ]

  workers = [
    { host = "192.168.1.102", hostname = "worker1" },
    { host = "192.168.1.103", hostname = "worker2" },
    { host = "192.168.1.104", hostname = "worker3" }
  ]

  kubeconfig_path = "./kubeconfig"
}
```

### With NVMe Storage (for Longhorn)

```hcl
module "cluster" {
  source  = "freed-dev-llc/modules/turingpi//modules/talos-cluster"
  version = ">= 1.3.0"

  cluster_name     = "my-cluster"
  cluster_endpoint = "https://192.168.1.101:6443"

  talos_version      = "v1.9.2"
  kubernetes_version = "v1.32.1"

  control_plane = [{ host = "192.168.1.101" }]
  workers = [
    { host = "192.168.1.102" },
    { host = "192.168.1.103" },
    { host = "192.168.1.104" }
  ]

  # Enable NVMe storage for Longhorn
  nvme_storage_enabled = true
  nvme_device          = "/dev/nvme0n1"
  nvme_mountpoint      = "/var/mnt/longhorn"
  nvme_control_plane   = true  # Also configure NVMe on control plane

  kubeconfig_path  = "./kubeconfig"
  talosconfig_path = "./talosconfig"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | >= 0.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | >= 0.7 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Kubernetes API endpoint (<https://IP:6443>) | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | n/a | yes |
| <a name="input_control_plane"></a> [control\_plane](#input\_control\_plane) | Control plane node configurations | <pre>list(object({<br/>    host     = string<br/>    hostname = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_controlplane_patches"></a> [controlplane\_patches](#input\_controlplane\_patches) | Config patches for control plane nodes (YAML strings) | `list(string)` | `[]` | no |
| <a name="input_kubeconfig_path"></a> [kubeconfig\_path](#input\_kubeconfig\_path) | Path to write kubeconfig file (optional) | `string` | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version (e.g., 'v1.32.1'). Must be compatible with the Talos version. | `string` | `null` | no |
| <a name="input_nvme_control_plane"></a> [nvme\_control\_plane](#input\_nvme\_control\_plane) | Configure NVMe on control plane nodes (in addition to workers) | `bool` | `true` | no |
| <a name="input_nvme_device"></a> [nvme\_device](#input\_nvme\_device) | NVMe device path | `string` | `"/dev/nvme0n1"` | no |
| <a name="input_nvme_mountpoint"></a> [nvme\_mountpoint](#input\_nvme\_mountpoint) | Mount point for NVMe storage | `string` | `"/var/mnt/longhorn"` | no |
| <a name="input_nvme_storage_enabled"></a> [nvme\_storage\_enabled](#input\_nvme\_storage\_enabled) | Enable NVMe storage configuration for Longhorn | `bool` | `false` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos version for config generation (e.g., 'v1.11.6'). Must match the Talos image on nodes. | `string` | `null` | no |
| <a name="input_talosconfig_path"></a> [talosconfig\_path](#input\_talosconfig\_path) | Path to write talosconfig file (optional) | `string` | `null` | no |
| <a name="input_worker_patches"></a> [worker\_patches](#input\_worker\_patches) | Config patches for worker nodes (YAML strings) | `list(string)` | `[]` | no |
| <a name="input_workers"></a> [workers](#input\_workers) | Worker node configurations | <pre>list(object({<br/>    host     = string<br/>    hostname = optional(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_configuration"></a> [client\_configuration](#output\_client\_configuration) | Talos client configuration for talosctl |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig for cluster access |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Path to kubeconfig file (if written) |
| <a name="output_machine_secrets"></a> [machine\_secrets](#output\_machine\_secrets) | Talos machine secrets (for backup) |
| <a name="output_nvme_enabled"></a> [nvme\_enabled](#output\_nvme\_enabled) | Whether NVMe storage is configured |
| <a name="output_nvme_mountpoint"></a> [nvme\_mountpoint](#output\_nvme\_mountpoint) | NVMe mount point (if enabled) |
<!-- END_TF_DOCS -->

## NVMe Storage Configuration

When `nvme_storage_enabled = true`, the module automatically generates Talos machine configuration patches to:

1. Partition the NVMe device
2. Mount it at the specified mountpoint
3. Make it available for Longhorn distributed storage

This is equivalent to applying the following Talos config patch:

```yaml
machine:
  disks:
    - device: /dev/nvme0n1
      partitions:
        - mountpoint: /var/mnt/longhorn
```

### Using with Longhorn

After enabling NVMe storage, configure Longhorn to use it:

```hcl
module "longhorn" {
  source  = "freed-dev-llc/modules/turingpi//modules/addons/longhorn"
  version = ">= 1.3.0"

  depends_on = [module.cluster]

  default_data_path         = "/var/mnt/longhorn"
  create_nvme_storage_class = true
  nvme_replica_count        = 2
}
```

## Talos System Extensions

Some addon modules require Talos system extensions. Without these extensions, certain features won't work:

| Addon Module | Required Extension | Purpose |
|--------------|-------------------|---------|
| `longhorn` | `siderolabs/iscsi-tools` | iSCSI support for distributed storage |
| `longhorn` (NFS) | `siderolabs/nfs-utils` | NFSv3 file locking support |
| VMs | `siderolabs/qemu-guest-agent` | QEMU guest agent service |

### Building Talos Images with Extensions

Use the [Talos Image Factory](https://factory.talos.dev) to create custom images with extensions:

```bash
# Create a schematic with required extensions
curl -X POST https://factory.talos.dev/schematics \
  -H "Content-Type: application/yaml" \
  --data-binary @- << 'EOF'
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
EOF

# Response: {"id":"613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245"}

# Download the image for ARM64 (Turing RK1)
curl -LO "https://factory.talos.dev/image/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245/v1.12.1/metal-arm64.raw.xz"
```

### Pre-built Schematic IDs

| Extensions | Schematic ID |
|------------|--------------|
| iscsi-tools + util-linux-tools | `613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245` |

Use these IDs to download images directly:

```
https://factory.talos.dev/image/{SCHEMATIC_ID}/{TALOS_VERSION}/metal-arm64.raw.xz
```

### Checking Installed Extensions

```bash
talosctl get extensions --nodes <NODE_IP>
```

## Resetting Talos Nodes

### Automated Wipe Script

Use the included wipe script to cleanly wipe all drives, shutdown nodes, and verify power off via the TuringPi BMC:

```bash
# Dry run (shows commands without executing)
./scripts/talos-wipe.sh \
  --talosconfig ./talosconfig \
  --nodes 10.10.88.74,10.10.88.75,10.10.88.76 \
  --bmc 10.10.88.70 \
  --dry-run

# Execute wipe workflow
./scripts/talos-wipe.sh \
  --talosconfig ./talosconfig \
  --nodes 10.10.88.74,10.10.88.75,10.10.88.76 \
  --bmc 10.10.88.70

# Skip NVMe wipe (only wipe system partitions)
./scripts/talos-wipe.sh \
  --talosconfig ./talosconfig \
  --nodes 10.10.88.74,10.10.88.75,10.10.88.76 \
  --bmc 10.10.88.70 \
  --no-nvme
```

The script will:

1. Wipe STATE and EPHEMERAL partitions
2. Optionally wipe user disks (NVMe)
3. Shutdown all nodes
4. Verify power off via BMC API

### Manual Commands

```bash
# Reset and return to maintenance mode (wipes cluster state)
talosctl reset --nodes <NODE_IP> --graceful=false --reboot \
  --system-labels-to-wipe STATE \
  --system-labels-to-wipe EPHEMERAL

# Also wipe user data disks (NVMe, etc.)
talosctl reset --nodes <NODE_IP> --graceful=false --reboot \
  --system-labels-to-wipe STATE \
  --system-labels-to-wipe EPHEMERAL \
  --user-disks-to-wipe /dev/nvme0n1

# Reset multiple nodes at once
talosctl reset --nodes 10.10.88.74,10.10.88.75,10.10.88.76 \
  --graceful=false --reboot \
  --system-labels-to-wipe STATE \
  --system-labels-to-wipe EPHEMERAL
```

**Note:** After reset, nodes enter maintenance mode. To install a different OS, re-flash via the TuringPi BMC.

## Prerequisites

Nodes must be pre-flashed with Talos Linux. Use the [flash-nodes](../flash-nodes) module or the `turingpi_flash` resource.

## License

Apache 2.0 - See [LICENSE](../../LICENSE) for details.
