# K3s Cluster Module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest/submodules/k3s-cluster)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to deploy a K3s Kubernetes cluster on Turing Pi 2.5 nodes running Armbian (or other Debian-based distributions).

This module connects to nodes via SSH, prepares them (packages, NVMe storage), and installs K3s using the official installation script.

## Usage

### Basic Cluster (SSH Key)

```hcl
module "k3s" {
  source  = "freed-dev-llc/modules/turingpi//modules/k3s-cluster"
  version = ">= 1.3.0"

  cluster_name = "my-cluster"

  control_plane = {
    host     = "192.168.1.101"
    ssh_user = "root"
    ssh_key  = file("~/.ssh/id_rsa")
  }

  workers = [
    {
      host     = "192.168.1.102"
      ssh_user = "root"
      ssh_key  = file("~/.ssh/id_rsa")
    },
    {
      host     = "192.168.1.103"
      ssh_user = "root"
      ssh_key  = file("~/.ssh/id_rsa")
    },
    {
      host     = "192.168.1.104"
      ssh_user = "root"
      ssh_key  = file("~/.ssh/id_rsa")
    }
  ]

  kubeconfig_path = "./kubeconfig"
}
```

### Basic Cluster (SSH Password)

```hcl
module "k3s" {
  source  = "freed-dev-llc/modules/turingpi//modules/k3s-cluster"
  version = ">= 1.3.0"

  cluster_name = "my-cluster"

  control_plane = {
    host         = "192.168.1.101"
    ssh_user     = "root"
    ssh_password = var.ssh_password
  }

  workers = [
    {
      host         = "192.168.1.102"
      ssh_user     = "root"
      ssh_password = var.ssh_password
    }
  ]

  kubeconfig_path = "./kubeconfig"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}
```

### With NVMe Storage (for Longhorn)

```hcl
module "k3s" {
  source  = "freed-dev-llc/modules/turingpi//modules/k3s-cluster"
  version = ">= 1.3.0"

  cluster_name = "homelab"
  k3s_version  = "v1.31.4+k3s1"

  control_plane = {
    host     = "192.168.1.101"
    ssh_user = "root"
    ssh_key  = file("~/.ssh/id_rsa")
  }

  workers = [
    { host = "192.168.1.102", ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") },
    { host = "192.168.1.103", ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") },
    { host = "192.168.1.104", ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") }
  ]

  # Enable NVMe storage for Longhorn
  nvme_storage_enabled = true
  nvme_device          = "/dev/nvme0n1"
  nvme_mountpoint      = "/var/lib/longhorn"
  nvme_filesystem      = "ext4"
  nvme_control_plane   = true

  # Longhorn prerequisites (enabled by default)
  install_open_iscsi = true
  install_nfs_common = true

  kubeconfig_path = "./kubeconfig"
}
```

## Prerequisites

1. **Nodes pre-flashed with Armbian** - Use the [flash-nodes](../flash-nodes) module to flash Armbian
2. **SSH access configured** - SSH key or password authentication
3. **Network connectivity** - Nodes must reach each other and the internet

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the K3s cluster | `string` | n/a | yes |
| <a name="input_control_plane"></a> [control\_plane](#input\_control\_plane) | Control plane node configuration | <pre>object({<br/>    host         = string<br/>    ssh_user     = string<br/>    ssh_key      = optional(string)<br/>    ssh_password = optional(string)<br/>    ssh_port     = optional(number, 22)<br/>    hostname     = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_cluster_cidr"></a> [cluster\_cidr](#input\_cluster\_cidr) | CIDR for pod networking | `string` | `"10.42.0.0/16"` | no |
| <a name="input_cluster_dns"></a> [cluster\_dns](#input\_cluster\_dns) | Cluster DNS service IP | `string` | `"10.43.0.10"` | no |
| <a name="input_cluster_token"></a> [cluster\_token](#input\_cluster\_token) | Cluster token for node authentication. Auto-generated if not specified. | `string` | `""` | no |
| <a name="input_disable_local_storage"></a> [disable\_local\_storage](#input\_disable\_local\_storage) | Disable the built-in local-path storage provisioner | `bool` | `false` | no |
| <a name="input_disable_servicelb"></a> [disable\_servicelb](#input\_disable\_servicelb) | Disable the built-in ServiceLB (Klipper) | `bool` | `true` | no |
| <a name="input_disable_traefik"></a> [disable\_traefik](#input\_disable\_traefik) | Disable the built-in Traefik ingress controller | `bool` | `true` | no |
| <a name="input_extra_agent_args"></a> [extra\_agent\_args](#input\_extra\_agent\_args) | Extra arguments for K3s agent | `list(string)` | `[]` | no |
| <a name="input_extra_server_args"></a> [extra\_server\_args](#input\_extra\_server\_args) | Extra arguments for K3s server | `list(string)` | `[]` | no |
| <a name="input_flannel_backend"></a> [flannel\_backend](#input\_flannel\_backend) | Flannel backend (vxlan, host-gw, wireguard-native, none) | `string` | `"vxlan"` | no |
| <a name="input_install_nfs_common"></a> [install\_nfs\_common](#input\_install\_nfs\_common) | Install nfs-common for NFS storage support | `bool` | `true` | no |
| <a name="input_install_open_iscsi"></a> [install\_open\_iscsi](#input\_install\_open\_iscsi) | Install open-iscsi for Longhorn (required for Longhorn) | `bool` | `true` | no |
| <a name="input_k3s_version"></a> [k3s\_version](#input\_k3s\_version) | K3s version to install (e.g., v1.31.4+k3s1). Leave empty for latest stable. | `string` | `""` | no |
| <a name="input_kubeconfig_path"></a> [kubeconfig\_path](#input\_kubeconfig\_path) | Path to write kubeconfig file (optional) | `string` | `null` | no |
| <a name="input_nvme_control_plane"></a> [nvme\_control\_plane](#input\_nvme\_control\_plane) | Configure NVMe on control plane node (in addition to workers) | `bool` | `true` | no |
| <a name="input_nvme_device"></a> [nvme\_device](#input\_nvme\_device) | NVMe device path | `string` | `"/dev/nvme0n1"` | no |
| <a name="input_nvme_filesystem"></a> [nvme\_filesystem](#input\_nvme\_filesystem) | Filesystem type for NVMe partition (ext4, xfs) | `string` | `"ext4"` | no |
| <a name="input_nvme_mountpoint"></a> [nvme\_mountpoint](#input\_nvme\_mountpoint) | Mount point for NVMe storage | `string` | `"/var/lib/longhorn"` | no |
| <a name="input_nvme_storage_enabled"></a> [nvme\_storage\_enabled](#input\_nvme\_storage\_enabled) | Enable NVMe storage configuration for Longhorn | `bool` | `false` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | CIDR for service networking | `string` | `"10.43.0.0/16"` | no |
| <a name="input_workers"></a> [workers](#input\_workers) | Worker node configurations | <pre>list(object({<br/>    host         = string<br/>    ssh_user     = string<br/>    ssh_key      = optional(string)<br/>    ssh_password = optional(string)<br/>    ssh_port     = optional(number, 22)<br/>    hostname     = optional(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | Kubernetes API endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name |
| <a name="output_cluster_token"></a> [cluster\_token](#output\_cluster\_token) | Cluster token for joining nodes |
| <a name="output_control_plane_host"></a> [control\_plane\_host](#output\_control\_plane\_host) | Control plane host IP/hostname |
| <a name="output_k3s_version"></a> [k3s\_version](#output\_k3s\_version) | Installed K3s version |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig for cluster access |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Path to kubeconfig file (if written) |
| <a name="output_nvme_enabled"></a> [nvme\_enabled](#output\_nvme\_enabled) | Whether NVMe storage is configured |
| <a name="output_nvme_mountpoint"></a> [nvme\_mountpoint](#output\_nvme\_mountpoint) | NVMe mount point (if enabled) |
| <a name="output_worker_hosts"></a> [worker\_hosts](#output\_worker\_hosts) | Worker node host IPs/hostnames |
<!-- END_TF_DOCS -->

### Node Configuration Object

```hcl
{
  host         = string           # IP or hostname
  ssh_user     = string           # SSH username
  ssh_key      = optional(string) # SSH private key content
  ssh_password = optional(string) # SSH password
  ssh_port     = optional(number) # SSH port (default: 22)
  hostname     = optional(string) # Custom hostname
}
```

## K3s Configuration

By default, this module:

- **Disables Traefik** - Use ingress-nginx addon instead
- **Disables ServiceLB** - Use MetalLB addon instead
- **Installs open-iscsi** - Required for Longhorn
- **Installs nfs-common** - For NFS storage support

These defaults are optimized for use with the addon modules (MetalLB, Ingress-NGINX, Longhorn).

## Using with Addons

After cluster creation, deploy addons using the kubeconfig output:

```hcl
# K3s cluster
module "k3s" {
  source = "freed-dev-llc/modules/turingpi//modules/k3s-cluster"
  # ... configuration
}

# Configure Kubernetes providers
provider "helm" {
  kubernetes {
    config_path = module.k3s.kubeconfig_path
  }
}

provider "kubectl" {
  config_path = module.k3s.kubeconfig_path
}

# MetalLB for LoadBalancer services
module "metallb" {
  source     = "freed-dev-llc/modules/turingpi//modules/addons/metallb"
  depends_on = [module.k3s]
  ip_range   = "192.168.1.200-192.168.1.220"
}

# Ingress NGINX
module "ingress" {
  source          = "freed-dev-llc/modules/turingpi//modules/addons/ingress-nginx"
  depends_on      = [module.metallb]
  loadbalancer_ip = "192.168.1.200"
}

# Longhorn storage (with NVMe)
module "longhorn" {
  source            = "freed-dev-llc/modules/turingpi//modules/addons/longhorn"
  depends_on        = [module.k3s]
  default_data_path = "/var/lib/longhorn"
}

# Monitoring
module "monitoring" {
  source     = "freed-dev-llc/modules/turingpi//modules/addons/monitoring"
  depends_on = [module.longhorn]

  grafana_admin_password = var.grafana_password
  storage_class          = "longhorn"
}

# Portainer
module "portainer" {
  source          = "freed-dev-llc/modules/turingpi//modules/addons/portainer"
  depends_on      = [module.metallb]
  loadbalancer_ip = "192.168.1.201"
}
```

## Differences from Talos

| Feature | K3s (Armbian) | Talos |
|---------|---------------|-------|
| OS | Armbian/Debian | Talos Linux |
| Access | SSH | talosctl API |
| Updates | apt + k3s script | Image-based |
| Customization | Full Linux | Limited (secure) |
| NVMe Setup | Partition + mount | Machine config |
| Storage Default | local-path | None |

## Troubleshooting

### SSH Connection Failed

- Verify node is accessible: `ssh root@<ip>`
- Check SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
- Ensure node has completed boot

### K3s Installation Timeout

- Check node internet connectivity
- Verify DNS resolution on nodes
- Review logs: `journalctl -u k3s`

### Worker Not Joining

- Verify control plane is ready
- Check network connectivity between nodes
- Review agent logs: `journalctl -u k3s-agent`

### NVMe Not Detected

- Verify device exists: `lsblk`
- Check NVMe is properly seated
- Device may be `/dev/nvme0n1` or similar

## License

Apache 2.0 - See [LICENSE](../../LICENSE) for details.
