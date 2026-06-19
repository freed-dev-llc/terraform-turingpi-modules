variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint (https://IP:6443)"
  type        = string
}

variable "control_plane" {
  description = "Control plane node configurations. Optional per-node `hostname` is applied at first boot via a Talos config patch; null/empty/whitespace leaves the Talos auto-generated name. Talos cannot rename an already-running node ('static hostname already set'), so set hostnames on a fresh build — changing them on a live cluster is rejected."
  type = list(object({
    host     = string
    hostname = optional(string)
  }))
  validation {
    condition     = length(var.control_plane) >= 1
    error_message = "At least one control plane node is required."
  }
}

variable "workers" {
  description = "Worker node configurations. Optional per-node `hostname` behaves as on `control_plane`: applied at first boot, null/empty/whitespace keeps the Talos default, and a live node cannot be renamed."
  type = list(object({
    host     = string
    hostname = optional(string)
  }))
  default = []
}

variable "controlplane_patches" {
  description = "Config patches for control plane nodes (YAML strings)"
  type        = list(string)
  default     = []
}

variable "worker_patches" {
  description = "Config patches for worker nodes (YAML strings)"
  type        = list(string)
  default     = []
}

variable "kubeconfig_path" {
  description = "Path to write kubeconfig file (optional)"
  type        = string
  default     = null
}

variable "talosconfig_path" {
  description = "Path to write talosconfig file (optional)"
  type        = string
  default     = null
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
  default     = "/var/mnt/longhorn"
}

variable "nvme_control_plane" {
  description = "Configure NVMe on control plane nodes (in addition to workers)"
  type        = bool
  default     = true
}

variable "talos_version" {
  description = "Talos version for config generation (e.g., 'v1.11.6'). Must match the Talos image on nodes."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g., 'v1.32.1'). Must be compatible with the Talos version."
  type        = string
  default     = null
}
