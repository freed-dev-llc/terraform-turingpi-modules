# Turing Pi Flash Nodes Module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest/submodules/flash-nodes)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to flash firmware to Turing Pi 2.5 nodes.

## Usage

```hcl
module "flash" {
  source  = "freed-dev-llc/modules/turingpi//modules/flash-nodes"
  version = ">= 1.4.0"

  nodes = {
    1 = { firmware = "/path/to/talos-arm64.raw" }
    2 = { firmware = "/path/to/talos-arm64.raw" }
    3 = { firmware = "/path/to/talos-arm64.raw" }
    4 = { firmware = "/path/to/talos-arm64.raw" }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_turingpi"></a> [turingpi](#requirement\_turingpi) | >= 1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_turingpi"></a> [turingpi](#provider\_turingpi) | >= 1.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Map of node number → firmware configuration. Keys must be "1", "2", "3", or "4" (Turing Pi 2 has 4 node slots). | <pre>map(object({<br/>    firmware = string<br/>  }))</pre> | n/a | yes |
| <a name="input_power_on_after_flash"></a> [power\_on\_after\_flash](#input\_power\_on\_after\_flash) | Power on nodes after flashing | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flashed_nodes"></a> [flashed\_nodes](#output\_flashed\_nodes) | Map of node number → firmware file path that was flashed |
| <a name="output_powered_nodes"></a> [powered\_nodes](#output\_powered\_nodes) | Map of node number → power state for nodes that were powered on |
<!-- END_TF_DOCS -->

## License

Apache 2.0 - See [LICENSE](../../LICENSE) for details.
