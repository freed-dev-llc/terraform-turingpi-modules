# This is a module collection - use the submodules directly.
# See README.md for available submodules and usage examples.

output "available_submodules" {
  description = "List of available submodules in this collection"
  value = [
    "modules/flash-nodes",
    "modules/talos-cluster",
    "modules/k3s-cluster",
    "modules/addons/metallb",
    "modules/addons/ingress-nginx",
    "modules/addons/longhorn",
    "modules/addons/monitoring",
    "modules/addons/portainer",
  ]
}

output "usage_example" {
  description = "Example usage of submodules"
  value       = <<-EOT
    module "cluster" {
      source  = "freed-dev-llc/modules/turingpi//modules/talos-cluster"
      version = ">= 1.2.0"
      # ... configuration
    }
  EOT
}
