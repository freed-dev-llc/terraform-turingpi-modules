# =============================================================================
# K3s Full Stack Example
# =============================================================================
# This example deploys a complete K3s cluster on Armbian with:
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
    # Required by the addon modules below. kubectl must use the gavinbunney
    # source — without this entry the root infers hashicorp/kubectl and
    # init fails ("does not have a provider named hashicorp/kubectl").
    helm = {
      source = "hashicorp/helm"
      # Pinned to 2.x: the provider "helm" block below uses the v2 nested
      # `kubernetes {}` block, which helm v3 replaced with an attribute.
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "control_plane_ip" {
  description = "IP address of control plane node"
  type        = string
}

variable "worker_ips" {
  description = "IP addresses of worker nodes"
  type        = list(string)
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB (e.g., 10.10.88.80-10.10.88.89)"
  type        = string
}

variable "ingress_ip" {
  description = "IP address for ingress controller"
  type        = string
}

variable "portainer_ip" {
  description = "IP address for Portainer agent"
  type        = string
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}

# =============================================================================
# K3s Cluster
# =============================================================================

module "k3s" {
  source = "../../modules/k3s-cluster"

  cluster_name = "homelab-k3s"
  k3s_version  = "v1.31.4+k3s1"

  control_plane = {
    host     = var.control_plane_ip
    ssh_user = "root"
    ssh_key  = file(var.ssh_key_path)
  }

  workers = [
    for ip in var.worker_ips : {
      host     = ip
      ssh_user = "root"
      ssh_key  = file(var.ssh_key_path)
    }
  ]

  # Enable NVMe storage for Longhorn
  nvme_storage_enabled = true
  nvme_device          = "/dev/nvme0n1"
  nvme_mountpoint      = "/var/lib/longhorn"
  nvme_filesystem      = "ext4"
  nvme_control_plane   = true

  # Disable built-ins (use addons instead)
  disable_traefik   = true
  disable_servicelb = true

  # Longhorn (installed below) is the default StorageClass; drop local-path's
  # default so there is a single default StorageClass (#51). local-path stays
  # available for explicit use.
  local_path_default = false

  kubeconfig_path = "${path.module}/kubeconfig"
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "helm" {
  kubernetes {
    config_path = module.k3s.kubeconfig_path
  }
}

provider "kubectl" {
  config_path = module.k3s.kubeconfig_path
}

# =============================================================================
# Addons
# =============================================================================

# MetalLB for LoadBalancer services
module "metallb" {
  source     = "../../modules/addons/metallb"
  depends_on = [module.k3s]

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
  depends_on = [module.k3s]

  default_data_path         = "/var/lib/longhorn"
  default_replica_count     = 2
  set_default_storage_class = true

  # Optional: NVMe-optimized storage class
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

  # Enable ingress for Grafana
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

# =============================================================================
# Outputs
# =============================================================================

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = module.k3s.kubeconfig_path
}

output "api_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.k3s.api_endpoint
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://grafana.local (add to /etc/hosts: ${var.ingress_ip} grafana.local)"
}

output "portainer_url" {
  description = "Portainer agent URL (connect from Portainer CE/BE)"
  value       = module.portainer.connection_url
}

output "longhorn_ui" {
  description = "Longhorn UI (port-forward required)"
  value       = "kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
}
