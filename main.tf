# Terraform Turing Pi Modules Collection
#
# This is a collection of reusable modules for Turing Pi cluster management.
# Use the submodules directly rather than this root module.
#
# Available submodules:
#   - modules/flash-nodes        - Flash firmware to Turing Pi nodes
#   - modules/talos-cluster      - Deploy Talos Kubernetes cluster
#   - modules/addons/metallb     - MetalLB load balancer
#   - modules/addons/ingress-nginx - NGINX Ingress controller
#
# Usage:
#   module "flash" {
#     source  = "freed-dev-llc/modules/turingpi//modules/flash-nodes"
#     version = ">= 1.0.0"
#     nodes = { 1 = { firmware = "talos.raw" } }
#   }
#
#   module "cluster" {
#     source  = "freed-dev-llc/modules/turingpi//modules/talos-cluster"
#     version = ">= 1.0.0"
#     cluster_name     = "my-cluster"
#     cluster_endpoint = "https://192.168.1.101:6443"
#     control_plane    = [{ host = "192.168.1.101" }]
#   }
#
# See README.md and examples/ for complete documentation.
