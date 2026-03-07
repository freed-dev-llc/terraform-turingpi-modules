# Talos Image Factory Module

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to generate custom Talos Linux images with system extensions using the [Talos Image Factory](https://factory.talos.dev).

## Usage

### Basic - Longhorn Support (ARM64)

```hcl
module "talos_image" {
  source = "freed-dev-llc/modules/turingpi//modules/talos-image"

  talos_version = "v1.9.2"
  architecture  = "arm64"
  preset        = "longhorn"  # Includes iscsi-tools + util-linux-tools
}

output "download_command" {
  value = module.talos_image.download_command
}

output "image_url" {
  value = module.talos_image.image_url
}
```

### Custom Extensions

```hcl
module "talos_image" {
  source = "freed-dev-llc/modules/turingpi//modules/talos-image"

  talos_version = "v1.9.2"
  architecture  = "arm64"

  extensions = [
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools",
    "siderolabs/nfs-utils",
    "siderolabs/qemu-guest-agent",
  ]
}
```

### With Extra Kernel Arguments

```hcl
module "talos_image" {
  source = "freed-dev-llc/modules/turingpi//modules/talos-image"

  talos_version = "v1.9.2"
  preset        = "longhorn"

  extra_kernel_args = [
    "console=ttyS0",
    "net.ifnames=0",
  ]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos version (e.g., 'v1.9.2') | `string` | n/a | yes |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Target architecture | `string` | `"arm64"` | no |
| <a name="input_extensions"></a> [extensions](#input\_extensions) | List of official Talos extensions to include | `list(string)` | `[]` | no |
| <a name="input_extra_kernel_args"></a> [extra\_kernel\_args](#input\_extra\_kernel\_args) | Extra kernel arguments to include | `list(string)` | `[]` | no |
| <a name="input_image_factory_url"></a> [image\_factory\_url](#input\_image\_factory\_url) | Talos Image Factory base URL | `string` | `"https://factory.talos.dev"` | no |
| <a name="input_platform"></a> [platform](#input\_platform) | Target platform (metal, aws, gcp, azure, etc.) | `string` | `"metal"` | no |
| <a name="input_preset"></a> [preset](#input\_preset) | Preset extension bundle: 'longhorn' (iscsi-tools, util-linux-tools), 'longhorn-nfs' (adds nfs-utils), 'qemu' (qemu-guest-agent), or 'none' | `string` | `"none"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_download_command"></a> [download\_command](#output\_download\_command) | curl command to download the image |
| <a name="output_extensions"></a> [extensions](#output\_extensions) | List of extensions included in the image |
| <a name="output_image_base_url"></a> [image\_base\_url](#output\_image\_base\_url) | Base URL for all image formats |
| <a name="output_image_url"></a> [image\_url](#output\_image\_url) | URL to download the Talos image (raw format) |
| <a name="output_image_url_iso"></a> [image\_url\_iso](#output\_image\_url\_iso) | URL to download the Talos ISO image |
| <a name="output_installer_url"></a> [installer\_url](#output\_installer\_url) | Talos installer image URL for upgrades |
| <a name="output_schematic_id"></a> [schematic\_id](#output\_schematic\_id) | Talos Image Factory schematic ID |
| <a name="output_schematic_yaml"></a> [schematic\_yaml](#output\_schematic\_yaml) | Schematic YAML sent to Image Factory |
<!-- END_TF_DOCS -->

## Pre-built Schematic IDs

For common configurations, the module uses cached schematic IDs to avoid API calls:

| Configuration | Schematic ID |
|---------------|--------------|
| Longhorn (iscsi-tools + util-linux-tools) | `613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245` |

## Workflow

1. **Generate image URL**: Use this module to get the download URL
2. **Download image**: Use the `download_command` output or `image_url`
3. **Flash nodes**: Use the flash-nodes module or manual process
4. **Deploy cluster**: Use the talos-cluster module

```hcl
# Step 1: Get the image URL
module "talos_image" {
  source        = "freed-dev-llc/modules/turingpi//modules/talos-image"
  talos_version = "v1.9.2"
  preset        = "longhorn"
}

# Step 2: Flash nodes with the custom image
module "flash_nodes" {
  source = "freed-dev-llc/modules/turingpi//modules/flash-nodes"

  nodes = {
    node2 = { slot = 2 }
    node3 = { slot = 3 }
    node4 = { slot = 4 }
  }

  image_path = "/mnt/sdcard/images/talos-longhorn.raw"
  # Download image first: curl -L ${module.talos_image.image_url} | xz -d > /mnt/sdcard/images/talos-longhorn.raw
}

# Step 3: Deploy cluster
module "cluster" {
  source     = "freed-dev-llc/modules/turingpi//modules/talos-cluster"
  depends_on = [module.flash_nodes]
  # ...
}

# Step 4: Deploy Longhorn (now works!)
module "longhorn" {
  source     = "freed-dev-llc/modules/turingpi//modules/addons/longhorn"
  depends_on = [module.cluster]

  talos_extensions_installed = true
}
```

## License

Apache 2.0 - See [LICENSE](../../LICENSE) for details.
