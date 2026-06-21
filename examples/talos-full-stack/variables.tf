# Turing Pi BMC connection
variable "turingpi_endpoint" {
  description = "Turing Pi BMC endpoint"
  type        = string
  default     = "https://turingpi.local"
}

variable "turingpi_username" {
  description = "Turing Pi BMC username"
  type        = string
  default     = "root"
}

variable "turingpi_password" {
  description = "Turing Pi BMC password"
  type        = string
  sensitive   = true
}

# Talos configuration
variable "talos_version" {
  description = "Talos version to deploy (e.g., 'v1.9.2')"
  type        = string
  default     = "v1.9.2"
}

variable "talos_architecture" {
  description = "Target architecture for Talos image"
  type        = string
  default     = "arm64"
}

variable "talos_firmware" {
  description = "Path to Talos firmware image (optional - if not set, uses talos-image module to generate URL)"
  type        = string
  default     = null
}

# Cluster configuration
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "turing-cluster"
}

variable "control_plane_ip" {
  description = "IP address of the control plane node"
  type        = string
}

variable "worker_ips" {
  description = "IP addresses of worker nodes"
  type        = list(string)
}

# Network configuration
variable "metallb_ip_range" {
  description = "IP range for MetalLB LoadBalancer services"
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
  description = "Grafana admin password (required; minimum 8 characters, enforced by the monitoring module)"
  type        = string
  sensitive   = true
}
