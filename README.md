# Terraform Turing Pi Modules

![Terraform Turing Pi Modules](docs/assets/turing-cluster/logos/turing_cluster_logo_horizontal.svg)

[![Terraform Validate](https://github.com/freed-dev-llc/terraform-turingpi-modules/actions/workflows/validate.yml/badge.svg)](https://github.com/freed-dev-llc/terraform-turingpi-modules/actions/workflows/validate.yml)
[![Security](https://github.com/freed-dev-llc/terraform-turingpi-modules/actions/workflows/security.yml/badge.svg)](https://github.com/freed-dev-llc/terraform-turingpi-modules/actions/workflows/security.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest)
[![OpenTofu Registry](https://img.shields.io/badge/OpenTofu%20Registry-freed--dev--llc%2Fturingpi-blue?logo=opentofu)](https://search.opentofu.org/module/freed-dev-llc/modules/turingpi/latest)
[![Release](https://img.shields.io/github/v/release/freed-dev-llc/terraform-turingpi-modules?sort=semver&logo=github&color=blue)](https://github.com/freed-dev-llc/terraform-turingpi-modules/releases)

Reusable Terraform modules for Turing Pi cluster provisioning and management.

## Cluster Modules

| Module | Description |
|--------|-------------|
| [flash-nodes](./modules/flash-nodes) | Flash firmware to Turing Pi nodes |
| [talos-image](./modules/talos-image) | Generate Talos images with extensions (Longhorn support) |
| [talos-cluster](./modules/talos-cluster) | Deploy Talos Linux Kubernetes cluster |
| [k3s-cluster](./modules/k3s-cluster) | Deploy K3s Kubernetes cluster on Armbian |

## Addon Modules

| Module | Description |
|--------|-------------|
| [cert-manager](./modules/addons/cert-manager) | TLS certificate management with Let's Encrypt + DNS01 (Cloudflare) |
| [ingress-nginx](./modules/addons/ingress-nginx) | NGINX Ingress controller |
| [longhorn](./modules/addons/longhorn) | Distributed block storage with NVMe support |
| [metallb](./modules/addons/metallb) | MetalLB load balancer |
| [monitoring](./modules/addons/monitoring) | Prometheus, Grafana, Alertmanager stack |
| [portainer](./modules/addons/portainer) | Cluster management agent (CE/BE) |

## Quick Start - Talos

```hcl
# Deploy Talos cluster
module "talos" {
  source  = "freed-dev-llc/modules/turingpi//modules/talos-cluster"
  version = "~> 1.4"

  cluster_name     = "homelab"
  cluster_endpoint = "https://10.10.88.73:6443"

  control_plane = [{ host = "10.10.88.73" }]
  workers = [
    { host = "10.10.88.74" },
    { host = "10.10.88.75" },
    { host = "10.10.88.76" }
  ]

  # Enable NVMe for Longhorn
  nvme_storage_enabled = true

  kubeconfig_path = "./kubeconfig"
}

# Add MetalLB
module "metallb" {
  source     = "freed-dev-llc/modules/turingpi//modules/addons/metallb"
  depends_on = [module.talos]
  ip_range   = "10.10.88.80-10.10.88.89"
}
```

## Quick Start - K3s (Armbian)

```hcl
# Deploy K3s cluster
module "k3s" {
  source  = "freed-dev-llc/modules/turingpi//modules/k3s-cluster"
  version = "~> 1.4"

  cluster_name = "homelab"

  control_plane = {
    host     = "10.10.88.73"
    ssh_user = "root"
    ssh_key  = file("~/.ssh/id_rsa")
  }

  workers = [
    { host = "10.10.88.74", ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") },
    { host = "10.10.88.75", ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") },
    { host = "10.10.88.76", ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") }
  ]

  # Enable NVMe for Longhorn
  nvme_storage_enabled = true

  kubeconfig_path = "./kubeconfig"
}

# Add MetalLB
module "metallb" {
  source     = "freed-dev-llc/modules/turingpi//modules/addons/metallb"
  depends_on = [module.k3s]
  ip_range   = "10.10.88.80-10.10.88.89"
}
```

## Full Stack Example

```hcl
# Cluster (Talos or K3s)
module "cluster" {
  source = "..."  # talos-cluster or k3s-cluster
  # ... cluster config
}

# MetalLB for LoadBalancer services
module "metallb" {
  source     = "freed-dev-llc/modules/turingpi//modules/addons/metallb"
  depends_on = [module.cluster]
  ip_range   = "10.10.88.80-10.10.88.89"
}

# Ingress controller
module "ingress" {
  source          = "freed-dev-llc/modules/turingpi//modules/addons/ingress-nginx"
  depends_on      = [module.metallb]
  loadbalancer_ip = "10.10.88.80"
}

# Distributed storage
module "longhorn" {
  source                    = "freed-dev-llc/modules/turingpi//modules/addons/longhorn"
  depends_on                = [module.cluster]
  create_nvme_storage_class = true
}

# Monitoring
module "monitoring" {
  source                 = "freed-dev-llc/modules/turingpi//modules/addons/monitoring"
  depends_on             = [module.longhorn]
  grafana_admin_password = var.grafana_password
  storage_class          = "longhorn"
}

# Cluster management
module "portainer" {
  source          = "freed-dev-llc/modules/turingpi//modules/addons/portainer"
  depends_on      = [module.metallb]
  loadbalancer_ip = "10.10.88.81"
}
```

## Examples

| Example | Description |
|---------|-------------|
| [talos-full-stack](./examples/talos-full-stack) | Complete Talos cluster with all addons |
| [k3s-full-stack](./examples/k3s-full-stack) | Complete K3s cluster with all addons |

## Documentation

| Document | Description |
|----------|-------------|
| [WORKFLOWS.md](./docs/WORKFLOWS.md) | Complete cluster lifecycle workflows with flowcharts |
| [ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Module architecture and dependency diagrams |

## Helper Scripts

Helper scripts for cluster lifecycle management are provided in the `scripts/` directory:

| Script | Description |
|--------|-------------|
| [`cluster-preflight.sh`](./scripts/cluster-preflight.sh) | Pre-deployment validation checks |
| [`talos-wipe.sh`](./scripts/talos-wipe.sh) | Wipe and shutdown Talos cluster |
| [`k3s-wipe.sh`](./scripts/k3s-wipe.sh) | Wipe and shutdown K3s cluster |
| [`find-armbian-image.sh`](./scripts/find-armbian-image.sh) | Find Armbian images, generate autoconfig for first-boot |

**Wipe scripts** (`talos-wipe.sh`, `k3s-wipe.sh`) support:

- `--dry-run` mode for safe testing
- Environment variables (`TURINGPI_ENDPOINT`, `TURINGPI_USERNAME`, `TURINGPI_PASSWORD`)
- Credential files in `~/.secrets/`
- `--force-power-off` via BMC API
- `--clean-terraform` for state file cleanup
- `--log FILE` for logging to file

Example usage:

```bash
# Pre-flight checks
./scripts/cluster-preflight.sh -t talos -n 10.10.88.73,10.10.88.74,10.10.88.75,10.10.88.76 -b 10.10.88.70

# Wipe Talos cluster with terraform cleanup
./scripts/talos-wipe.sh -n 10.10.88.73,10.10.88.74,10.10.88.75,10.10.88.76 -b 10.10.88.70 --clean-terraform --force-power-off

# Wipe K3s cluster
./scripts/k3s-wipe.sh -n 10.10.88.74,10.10.88.75,10.10.88.76 -b 10.10.88.70 --clean-terraform --force-power-off

# Find and list available Armbian images
./scripts/find-armbian-image.sh --list

# Find minimal trixie image URL for BMC flash
./scripts/find-armbian-image.sh -v minimal -r trixie

# Generate autoconfig for first-boot setup (password, SSH key, timezone)
./scripts/find-armbian-image.sh --autoconfig first_run.txt \
    --root-password "YourPassword" \
    --ssh-key ~/.ssh/id_ed25519.pub \
    --timezone "America/Chicago"

# Generate autoconfig with static IP (when DHCP reservations unavailable)
./scripts/find-armbian-image.sh --autoconfig first_run.txt \
    --root-password "YourPassword" \
    --static-ip "10.10.88.74" \
    --gateway "10.10.88.1"
```

## Talos vs K3s

| Feature | Talos | K3s (Armbian) |
|---------|-------|---------------|
| Security | Immutable, API-only | Standard Linux |
| Updates | Image-based | apt + k3s script |
| Access | talosctl | SSH |
| Customization | Limited (secure) | Full Linux |
| Best for | Production, security-focused | Development, flexibility |

### Addon Module Configuration by Platform

| Setting | Talos | K3s/Armbian |
|---------|-------|-------------|
| `privileged_namespace` | `true` (PSA enforced) | `false` (PSA not enforced) |
| `talos_extensions_installed` | `true` (after custom image) | `true` (after `apt install open-iscsi`) |
| Longhorn prerequisites | Custom Talos image with extensions | `apt install open-iscsi nfs-common` |

### Storage Considerations (32GB eMMC)

Longhorn reserves ~30% of disk space. For eMMC-constrained nodes:

```hcl
module "monitoring" {
  source = "freed-dev-llc/modules/turingpi//modules/addons/monitoring"

  grafana_admin_password  = var.grafana_password
  prometheus_storage_size = "10Gi"  # Reduced from default 20Gi
}
```

## Requirements

- Terraform >= 1.0
- [Turing Pi Provider](https://github.com/freed-dev-llc/terraform-provider-turingpi) ~> 1.5 (for flashing)
- [Talos Provider](https://github.com/siderolabs/terraform-provider-talos) >= 0.7 (for Talos clusters)

## Verified Configurations

Tested and verified on v1.6.1 (modules) / v1.5.1 (provider):

- K3s v1.31.4+k3s1 on Armbian 26.2.0-trunk.151 (trixie)
- BMC firmware v2.3.4
- MetalLB L2 mode with IP pool assignment
- Longhorn with 2-replica volumes
- Prometheus/Grafana with persistent storage
- Ingress-NGINX with LoadBalancer service

## License

Apache License 2.0
