# Terraform Turing Pi Modules Collection
#
# This is a collection of reusable modules for Turing Pi cluster management.
# Use the submodules directly rather than this root module.
#
# Available submodules:
#   Cluster modules:
#     - modules/flash-nodes      - Flash firmware to Turing Pi nodes
#     - modules/k3s-cluster      - Deploy K3s Kubernetes cluster (Armbian)
#     - modules/talos-cluster    - Deploy Talos Kubernetes cluster
#     - modules/talos-image      - Build Talos Image Factory schematic / image URLs
#   Addon modules:
#     - modules/addons/cert-manager  - TLS certs via Let's Encrypt + Cloudflare DNS01
#     - modules/addons/ingress-nginx - NGINX Ingress controller
#     - modules/addons/longhorn      - Distributed block storage with NVMe support
#     - modules/addons/metallb       - MetalLB load balancer
#     - modules/addons/monitoring    - Prometheus / Grafana / Alertmanager
#     - modules/addons/portainer     - Cluster management agent (CE/BE)
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
