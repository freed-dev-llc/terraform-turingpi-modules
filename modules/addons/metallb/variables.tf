variable "ip_range" {
  description = "IP range for LoadBalancer services (e.g., 10.10.88.80-10.10.88.89)"
  type        = string
}

variable "pool_name" {
  description = "Name of the IP address pool"
  type        = string
  default     = "default-pool"
}

variable "namespace" {
  description = "Kubernetes namespace for MetalLB"
  type        = string
  default     = "metallb-system"
}

variable "chart_version" {
  description = "MetalLB Helm chart version"
  type        = string
  default     = "0.14.9"
}

variable "timeout" {
  description = "Helm install timeout in seconds"
  type        = number
  default     = 300
}

variable "controller_resources" {
  description = "Resource requests/limits for MetalLB controller"
  type = object({
    requests = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "128Mi")
    }), {})
    limits = optional(object({
      cpu    = optional(string, "200m")
      memory = optional(string, "256Mi")
    }), {})
  })
  default = {}
}

variable "speaker_resources" {
  description = "Resource requests/limits for MetalLB speaker"
  type = object({
    requests = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "128Mi")
    }), {})
    limits = optional(object({
      cpu    = optional(string, "200m")
      memory = optional(string, "256Mi")
    }), {})
  })
  default = {}
}

variable "privileged_namespace" {
  description = "Apply privileged PodSecurity labels to namespace (required for Talos Linux)"
  type        = bool
  default     = true
}
