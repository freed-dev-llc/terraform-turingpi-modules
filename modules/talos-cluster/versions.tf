terraform {
  # >= 1.2 for resource lifecycle preconditions (cross-variable hostname
  # uniqueness check, #68).
  required_version = ">= 1.2"
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}
