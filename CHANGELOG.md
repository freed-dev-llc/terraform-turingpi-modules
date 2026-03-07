# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.10] - 2026-01-25

### Changed

- Synchronized release with terraform-provider-turingpi v1.3.10
- Provider fix: BMC firmware 2.0.5+ flash status response format now supported

## [1.3.9] - 2026-01-19

### Added

- **talos-image module**: SBC overlay support for single-board computers
  - New `sbc_overlay` variable for board-specific overlays (turingrk1, rpi_generic, rock5b, etc.)
  - Auto-detection of overlay images from overlay name
  - Supports 16+ SBC boards across Rockchip, Raspberry Pi, Jetson, and Allwinner families
- **talos-cluster module**: Added `talosconfig_path` output
- **talos-wipe.sh**: Added `--yes` / `-y` flag for non-interactive automation
- **scripts/find-armbian-image.sh** - Find and download Armbian images for Turing RK1 from GitHub releases
- **test/addon-test/** - Comprehensive addon module test configuration
- **test/provider-test/** - Provider data source test configuration

### Fixed

- **talos-cluster module**: Fixed talosconfig output format - now generates proper YAML with context, endpoints, nodes (previously output unusable JSON)
- **talos-wipe.sh**: Removed eMMC wipe attempt - eMMC is system disk and cannot be wiped via talosctl reset
- Shellcheck SC2002 warnings in helper scripts

### Changed

- Enhanced docs/WORKFLOWS.md with comprehensive K3s and Talos deployment steps
- Updated README version references to ~> 1.3.9

### Verified

- All addon modules tested on Talos v1.9.2 (Turing RK1 with turingrk1 overlay)
  - metallb: L2 mode with IP pool 10.10.88.80-89
  - ingress-nginx: LoadBalancer service on 10.10.88.80
  - cert-manager: Self-signed CA and ClusterIssuers ready
  - longhorn: StorageClass created with NVMe storage class
  - monitoring: Prometheus + Grafana with persistent storage
  - portainer: Agent accessible on 10.10.88.81:9001
- Talos Image Factory integration with SBC overlays verified

## [1.3.8] - 2026-01-19

### Changed

- Wipe scripts now wipe both NVMe and eMMC drives by default
- Added prominent warning box showing all data to be destroyed
- Changed confirmation from 'yes' to 'DESTROY' for safety
- Added `--no-emmc` flag to skip eMMC wipe if needed

## [1.3.7] - 2026-01-19

### Fixed

- Helper scripts bash `set -e` compatibility (STEP increment, log_output function)
- Scripts now auto-load credentials from `~/.secrets/turning-pi-cluster-bmc` file format
- Scripts auto-detect SSH key from `~/.secrets/turningpi-cluster`

## [1.3.6] - 2026-01-19

### Added

- **talos-image module** - Generate Talos images with extensions (iscsi-tools, util-linux-tools) for Longhorn support
- **docs/WORKFLOWS.md** - Complete cluster lifecycle documentation with Mermaid flowcharts for Talos and K3s
- **scripts/cluster-preflight.sh** - Pre-deployment validation script checking tools, BMC connectivity, node status
- **scripts/talos-wipe.sh** - Enhanced Talos cluster wipe with env vars, credential files, terraform cleanup, force power-off
- **scripts/k3s-wipe.sh** - Enhanced K3s cluster wipe with node draining, container cleanup, iptables cleanup

### Changed

- Updated talos-full-stack example to use talos-image module for automatic image generation
- Enhanced README with documentation links and helper script examples
- Added platform-specific configurations to addon modules (Talos vs K3s/Armbian)
- Added storage capacity planning guidance for eMMC-constrained nodes

## [1.3.5] - 2026-01-18

### Added

- **cert-manager addon module** - TLS certificate management with Let's Encrypt and self-signed CA support
- docs/UPGRADE.md with comprehensive upgrade guidance
- `namespace` variable to all addon modules (metallb, ingress-nginx, longhorn, monitoring, portainer)
- `controller_resources` and `speaker_resources` to MetalLB module
- `controller_replicas`, `controller_resources`, `enable_metrics` to ingress-nginx module
- `manager_resources`, `ui_replicas` to Longhorn module
- `replicas` variable to Portainer module
- Grafana password validation (minimum 8 characters) in monitoring module

### Changed

- All addon modules now use configurable namespaces instead of hardcoded values
- Improved resource configuration flexibility across all addon modules

### Fixed

- MetalLB and cert-manager modules now use `values` block instead of `set` blocks for Helm provider v3.x compatibility

## [1.3.4] - 2026-01-18

### Changed

- Synchronized release with terraform-provider-turingpi v1.3.4
- Provider now supports BMC firmware 2.3.4 API response format

## [1.3.3] - 2026-01-18

### Added

- CODE_OF_CONDUCT.md (Contributor Covenant v2.0)
- docs/ARCHITECTURE.md with module dependency diagrams
- Security workflow with Trivy scanning and dependency review

### Changed

- Enhanced SECURITY.md with supply chain security section
- Enhanced CODEOWNERS with per-path ownership
- Enhanced CONTRIBUTING.md with release process
- Enhanced pre-commit hooks with additional checks
- README badges updated

## [1.3.2] - 2025-12-30

### Changed

- Bump actions/checkout from v4 to v6
- Bump terraform-linters/setup-tflint from v4 to v6

## [1.3.1] - 2025-12-30

### Added

- README badges (CI status, Terraform Registry, License) to root and all submodule READMEs

## [1.3.0] - 2025-12-30

### Added

#### CI/CD & Automation

- GitHub Actions workflow for Terraform validation (fmt, init, validate) on PRs
- TFLint integration with recommended ruleset (`.tflint.hcl`)
- Trivy security scanning for misconfigurations (`trivy.yaml`)
- terraform-docs integration for auto-generated documentation (`.terraform-docs.yml`)
- Dependabot for Terraform provider and GitHub Actions updates
- Pre-commit hooks for local validation (`.pre-commit-config.yaml`)
- CODEOWNERS file for automatic PR review requests

#### Repository Configuration

- Branch protection with required status checks and code owner reviews
- Issue templates (bug report, feature request)
- Pull request template with validation checklist
- CONTRIBUTING guide with development setup instructions

### Removed

- Unused `install_timeout` variable from k3s-cluster module
- Unused `allow_scheduling_on_control_plane` variable from talos-cluster module

## [1.2.4] - 2025-12-30

### Added

- `talos_version` variable to talos-cluster module for explicit Talos version in config generation
- `kubernetes_version` variable to talos-cluster module for explicit Kubernetes version

## [1.2.3] - 2025-12-30

### Changed

- Updated provider requirement to `>= 1.3.0` (includes BMC API compatibility and flash implementation)
- Updated all documentation examples to reference v1.3.0

## [1.2.2] - 2025-12-29

### Changed

- Updated all module version references to `>= 1.2.0`
- Updated provider requirement to `>= 1.2.0`
- Added k3s-cluster, longhorn, monitoring, portainer to available_submodules list
- Synchronized documentation with terraform-provider-turingpi repo

## [1.2.1] - 2025-12-29

### Fixed

- Applied terraform fmt formatting fixes across all modules

## [1.2.0] - 2025-12-29

### Added

- **k3s-cluster module** - Deploy K3s Kubernetes cluster on Armbian
  - SSH-based deployment (key or password authentication)
  - NVMe storage configuration for Longhorn
  - Automatic package installation (open-iscsi, nfs-common)
  - Configurable K3s options (disable traefik, servicelb, etc.)

- **k3s-full-stack example** - Complete K3s deployment with all addons

### Changed

- Updated talos-full-stack example with all addon modules
- Updated root README with K3s quick start and Talos vs K3s comparison

## [1.1.0] - 2025-12-29

### Added

- **Addon modules**
  - `longhorn` - Distributed block storage with NVMe-optimized storage class
  - `monitoring` - Prometheus, Grafana, Alertmanager (kube-prometheus-stack)
  - `portainer` - Cluster management agent for CE/BE

- **NVMe storage support** for talos-cluster module
  - `nvme_storage_enabled` - Enable NVMe configuration
  - `nvme_device` - Device path configuration
  - `nvme_mountpoint` - Mount point for Longhorn
  - `nvme_control_plane` - Configure NVMe on control plane nodes

- **talos-full-stack example** - Complete Talos deployment with all addons

### Changed

- Updated talos-cluster module with NVMe configuration options
- Enhanced README with full stack examples

## [1.0.4] - 2025-12-29

### Fixed

- Version constraint updates in examples

## [1.0.3] - 2025-12-29

### Fixed

- Duplicate terraform block in flash-nodes module

## [1.0.2] - 2025-12-29

### Added

- Root module configuration for Terraform Registry compatibility

## [1.0.1] - 2025-12-29

### Added

- Module README files for all submodules
- versions.tf files for Terraform Registry compatibility

## [1.0.0] - 2025-12-29

### Added

- Initial release
- **flash-nodes module** - Flash firmware to Turing Pi nodes
- **talos-cluster module** - Deploy Talos Kubernetes cluster
- **metallb addon** - MetalLB load balancer
- **ingress-nginx addon** - NGINX Ingress controller

[Unreleased]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.10...HEAD
[1.3.10]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.9...v1.3.10
[1.3.9]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.8...v1.3.9
[1.3.8]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.7...v1.3.8
[1.3.7]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.6...v1.3.7
[1.3.6]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.5...v1.3.6
[1.3.5]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.4...v1.3.5
[1.3.4]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.3...v1.3.4
[1.3.3]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.2.4...v1.3.0
[1.2.4]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/freed-dev-llc/terraform-turingpi-modules/releases/tag/v1.0.0
