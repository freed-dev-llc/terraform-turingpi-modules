variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
}

variable "k3s_version" {
  description = "K3s version to install (e.g., v1.31.4+k3s1). Leave empty for latest stable."
  type        = string
  default     = ""
}

variable "cluster_token" {
  description = "Cluster token for node authentication. Auto-generated if not specified."
  type        = string
  sensitive   = true
  default     = ""
}

variable "control_plane" {
  description = "Control plane node configuration"
  type = object({
    host         = string
    ssh_user     = string
    ssh_key      = optional(string)
    ssh_password = optional(string)
    ssh_port     = optional(number, 22)
    hostname     = optional(string)
  })

  validation {
    condition     = var.control_plane.ssh_key != null || var.control_plane.ssh_password != null
    error_message = "Either ssh_key or ssh_password must be provided for the control plane."
  }
}

variable "workers" {
  description = "Worker node configurations"
  type = list(object({
    host         = string
    ssh_user     = string
    ssh_key      = optional(string)
    ssh_password = optional(string)
    ssh_port     = optional(number, 22)
    hostname     = optional(string)
  }))
  default = []
}

variable "kubeconfig_path" {
  description = "Path to write kubeconfig file (optional)"
  type        = string
  default     = null
}

# K3s Configuration Options
variable "disable_traefik" {
  description = "Disable the built-in Traefik ingress controller"
  type        = bool
  default     = true
}

variable "disable_servicelb" {
  description = "Disable the built-in ServiceLB (Klipper)"
  type        = bool
  default     = true
}

variable "disable_local_storage" {
  description = "Disable the built-in local-path storage provisioner"
  type        = bool
  default     = false
}

variable "local_path_default" {
  description = "Keep K3s's built-in local-path as the default StorageClass. Set false when another default (e.g. Longhorn) will be installed, to avoid two default StorageClasses (#51); the module then marks the bundled local-storage manifest with a .skip and clears the default annotation so it survives k3s restarts (local-path stays usable but is no longer k3s-managed / auto-upgraded). Ignored when disable_local_storage = true."
  type        = bool
  default     = true
}

variable "flannel_backend" {
  description = "Flannel backend (vxlan, host-gw, wireguard-native, none)"
  type        = string
  default     = "vxlan"
}

variable "cluster_cidr" {
  description = "CIDR for pod networking"
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for service networking"
  type        = string
  default     = "10.43.0.0/16"
}

variable "cluster_dns" {
  description = "Cluster DNS service IP"
  type        = string
  default     = "10.43.0.10"
}

variable "extra_server_args" {
  description = "Extra arguments for K3s server"
  type        = list(string)
  default     = []
}

variable "extra_agent_args" {
  description = "Extra arguments for K3s agent"
  type        = list(string)
  default     = []
}

# NVMe Storage Configuration
variable "nvme_storage_enabled" {
  description = "Enable NVMe storage configuration for Longhorn"
  type        = bool
  default     = false
}

variable "nvme_device" {
  description = "NVMe device path"
  type        = string
  default     = "/dev/nvme0n1"
}

variable "nvme_mountpoint" {
  description = "Mount point for NVMe storage"
  type        = string
  default     = "/var/lib/longhorn"
}

variable "nvme_filesystem" {
  description = "Filesystem type for NVMe partition (ext4, xfs)"
  type        = string
  default     = "ext4"
}

variable "nvme_control_plane" {
  description = "Configure NVMe on control plane node (in addition to workers)"
  type        = bool
  default     = true
}

# Node preparation
variable "install_open_iscsi" {
  description = "Install open-iscsi for Longhorn (required for Longhorn)"
  type        = bool
  default     = true
}

variable "install_nfs_common" {
  description = "Install nfs-common for NFS storage support"
  type        = bool
  default     = true
}
