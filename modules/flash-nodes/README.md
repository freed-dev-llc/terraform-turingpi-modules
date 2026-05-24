# Turing Pi Flash Nodes Module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest/submodules/flash-nodes)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to flash firmware to Turing Pi 2.5 nodes.

## Usage

The `firmware` value is routed by scheme: an `http(s)://` URL is flashed via the
provider's `firmware_url` (the BMC pulls the image directly, which is the only
path that reliably reports completion); any other value is treated as a local
file path. URLs are recommended.

```hcl
module "flash" {
  source  = "freed-dev-llc/modules/turingpi//modules/flash-nodes"
  version = ">= 1.5.0"

  nodes = {
    # Recommended: BMC pulls directly (reliable completion signal)
    1 = { firmware = "https://factory.talos.dev/image/<schematic>/v1.9.2/metal-arm64.raw.xz" }
    2 = { firmware = "https://factory.talos.dev/image/<schematic>/v1.9.2/metal-arm64.raw.xz" }
    # Local path also supported (streaming upload; less reliable completion signal)
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
| <a name="requirement_turingpi"></a> [turingpi](#requirement\_turingpi) | >= 1.5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_turingpi"></a> [turingpi](#provider\_turingpi) | >= 1.5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Map of node number → firmware configuration. Keys must be "1", "2", "3", or "4" (Turing Pi 2 has 4 node slots). | <pre>map(object({<br/>    firmware = string<br/>  }))</pre> | n/a | yes |
| <a name="input_power_on_after_flash"></a> [power\_on\_after\_flash](#input\_power\_on\_after\_flash) | Power on nodes after flashing | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flashed_nodes"></a> [flashed\_nodes](#output\_flashed\_nodes) | Map of node number → firmware source that was flashed (URL or local file path) |
| <a name="output_powered_nodes"></a> [powered\_nodes](#output\_powered\_nodes) | Map of node number → power state for nodes that were powered on |
<!-- END_TF_DOCS -->

## License

Apache 2.0 - See [LICENSE](../../LICENSE) for details.
