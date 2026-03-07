# This is a module collection - use the submodules directly:
#
# - modules/flash-nodes      - Flash firmware to Turing Pi nodes
# - modules/talos-cluster    - Deploy Talos Kubernetes cluster
# - modules/addons/metallb   - MetalLB load balancer
# - modules/addons/ingress-nginx - NGINX Ingress controller
#
# Example:
#   module "cluster" {
#     source = "freed-dev-llc/modules/turingpi//modules/talos-cluster"
#     ...
#   }

variable "submodule_info" {
  description = "This root module is a collection. Use the submodules directly."
  type        = string
  default     = "See README.md for available submodules"
}
