# =============================================================================
# Talos Full Stack Example
# =============================================================================
# This example deploys a complete Talos Linux cluster with:
# - 1 control plane + 3 workers
# - NVMe storage configured for Longhorn
# - MetalLB for LoadBalancer services
# - Ingress NGINX for ingress
# - Longhorn for distributed storage
# - Prometheus/Grafana for monitoring
# - Portainer for cluster management

terraform {
  required_version = ">= 1.0"

  required_providers {
    turingpi = {
      source  = "freed-dev-llc/turingpi"
      version = ">= 1.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}

# =============================================================================
# Turing Pi Provider (for flashing)
# =============================================================================

provider "turingpi" {
  endpoint = var.turingpi_endpoint
  username = var.turingpi_username
  password = var.turingpi_password
}

# =============================================================================
# Talos Image with Extensions (Longhorn support)
# =============================================================================
# Generates a custom Talos image URL with iscsi-tools and util-linux-tools
# extensions required for Longhorn distributed storage.

module "talos_image" {
  source = "../../modules/talos-image"

  talos_version = var.talos_version
  architecture  = var.talos_architecture
  preset        = "longhorn" # Includes iscsi-tools + util-linux-tools
}

# =============================================================================
# Flash Talos to Nodes
# =============================================================================

locals {
  # Use provided firmware path or the generated image URL
  firmware_url = coalesce(var.talos_firmware, module.talos_image.image_url)
}

module "flash" {
  source = "../../modules/flash-nodes"

  nodes = {
    1 = { firmware = local.firmware_url }
    2 = { firmware = local.firmware_url }
    3 = { firmware = local.firmware_url }
    4 = { firmware = local.firmware_url }
  }
}

resource "time_sleep" "wait_for_boot" {
  depends_on      = [module.flash]
  create_duration = "120s"
}

# =============================================================================
# Talos Cluster
# =============================================================================

module "cluster" {
  source     = "../../modules/talos-cluster"
  depends_on = [time_sleep.wait_for_boot]

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.control_plane_ip}:6443"

  control_plane = [{ host = var.control_plane_ip }]
  workers = [
    for ip in var.worker_ips : { host = ip }
  ]

  # Enable NVMe storage for Longhorn
  nvme_storage_enabled = true
  nvme_device          = "/dev/nvme0n1"
  nvme_mountpoint      = "/var/mnt/longhorn"
  nvme_control_plane   = true

  kubeconfig_path  = "${path.module}/kubeconfig"
  talosconfig_path = "${path.module}/talosconfig"

  allow_scheduling_on_control_plane = true
}

# =============================================================================
# Provider Configuration for Addons
# =============================================================================

provider "helm" {
  kubernetes {
    config_path = module.cluster.kubeconfig_path
  }
}

provider "kubectl" {
  config_path = module.cluster.kubeconfig_path
}

# =============================================================================
# Addons
# =============================================================================

# MetalLB for LoadBalancer services
module "metallb" {
  source     = "../../modules/addons/metallb"
  depends_on = [module.cluster]

  ip_range = var.metallb_ip_range
}

# Ingress NGINX
module "ingress" {
  source     = "../../modules/addons/ingress-nginx"
  depends_on = [module.metallb]

  loadbalancer_ip = var.ingress_ip
}

# Longhorn distributed storage
module "longhorn" {
  source     = "../../modules/addons/longhorn"
  depends_on = [module.cluster]

  default_data_path         = "/var/mnt/longhorn"
  default_replica_count     = 2
  set_default_storage_class = true

  # NVMe-optimized storage class
  create_nvme_storage_class = true
  nvme_replica_count        = 2
}

# Monitoring stack (Prometheus, Grafana, Alertmanager)
module "monitoring" {
  source     = "../../modules/addons/monitoring"
  depends_on = [module.longhorn]

  grafana_admin_password      = var.grafana_password
  grafana_persistence_enabled = true
  storage_class               = "longhorn"

  prometheus_retention    = "15d"
  prometheus_storage_size = "20Gi"

  grafana_ingress_enabled = true
  grafana_ingress_host    = "grafana.local"
}

# Portainer agent for cluster management
module "portainer" {
  source     = "../../modules/addons/portainer"
  depends_on = [module.metallb]

  service_type    = "LoadBalancer"
  loadbalancer_ip = var.portainer_ip
}
