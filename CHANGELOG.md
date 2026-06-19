# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **`modules/talos-cluster`**: the per-node hostname patch added in v1.6.0 guarded only on `hostname != null`, so an explicit empty or whitespace-only string (e.g. from an unset template variable) slipped through and pushed `machine.network.hostname: ""` to the node. The guard now uses `trimspace(...) != ""` (with `try()` covering the null case), and the patch value is trimmed, so blank hostnames are treated the same as null (no-op, Talos keeps its auto-generated name).

### Documentation

- **`modules/talos-cluster`**: documented the per-node `hostname` input — added a "Node Hostnames" section to the module README and expanded the `control_plane`/`workers` variable descriptions to note that hostnames are applied at first boot only; Talos cannot rename an already-running node (`static hostname already set`), so a live cluster must be wiped and re-provisioned to change a hostname.

## [1.6.0] - 2026-05-24

### Added

- **`modules/k3s-cluster`**: new `local_path_default` variable (default `true`, preserving current behavior). When set to `false` (and `disable_local_storage` is not set), the module makes K3s's built-in `local-path` non-default **durably**, so a separately-installed default (e.g. Longhorn) is the **sole** default — fixing the "two default StorageClasses" ambiguity where PVCs that omit `storageClassName` bind nondeterministically. A bare annotation isn't sufficient (K3s re-applies its bundled `local-storage` manifest on every restart, re-asserting `is-default-class=true`), so the module marks that manifest with a `.skip` — which per the K3s docs does *not* remove the already-created resources, so the local-path provisioner keeps running — and then clears the default annotation, which now survives k3s restarts/reboots. `local-path` stays usable for explicit `storageClassName` but is no longer k3s-managed (won't auto-upgrade). `examples/k3s-full-stack` sets `local_path_default = false`. Verified on hardware: survives `systemctl restart k3s`. (Closes #51)

### Fixed

- **`modules/talos-cluster`**: the per-node `hostname` input on `control_plane`/`workers` was silently ignored — nodes came up with Talos auto-generated names (`talos-<random>`). The module generates one shared machine config per role and applied it identically to every node, never referencing `each.value.hostname`. Now sets `machine.network.hostname` via a per-node `config_patches` on each `talos_machine_configuration_apply` (no-op when `hostname` is null). Fixes #56.

- **`scripts/k3s-wipe.sh` & `scripts/talos-wipe.sh`**: BMC power-off verification always reported nodes as "still ON" (status `unknown`), even when they had powered off. `check_power_status` matched an *unquoted* digit (`"node1":0`), but the BMC returns *quoted* values (`"node1":"0"`), so the pattern never matched and `wait_for_power_off` always timed out — triggering spurious force-power-off warnings at the end of an otherwise-successful wipe. Now parses the value tolerating quotes/whitespace (verified live against the BMC). Fixes #52.

- **`scripts/find-armbian-image.sh`**: image search always returned "no image found". It captured the GitHub releases JSON into a shell variable and piped it back through `echo` to `jq`; control characters in release bodies corrupted the round-trip so `jq` failed to parse — and the error was hidden by `2>/dev/null`. Now reads the API response from a temp file (and no longer suppresses `jq` errors). Also fixed an invalid-regex-escape (the match pattern is passed via `jq --arg` instead of being interpolated into the program), added a `--kernel` flag (`vendor`/`current`/`edge`/`any`, default `vendor`) so the vendor RK1 image is selected deterministically, widened the search to `per_page=30`, and hardened the no-match path (`.[0] // empty`).

### Documentation

- **`modules/flash-nodes`**: regenerated the terraform-docs block so the rendered inputs table reflects `firmware_url` (added in v1.5.0). Docs only — no behavior change (#49).
- **Example IPs standardized to `10.10.88.x`**: the root `README.md`, root `main.tf` comments, all module READMEs (`k3s-cluster`, `talos-cluster`, addons), `docs/MANUAL_TEST_PLAN.md`, the `metallb` variable description, and `examples/k3s-full-stack` used a mix of `192.168.1.x` placeholders. Aligned them on the `10.10.88.x` scheme already used in the provider repo and the rest of these docs — control plane `.73`, workers `.74`/`.75`/`.76`, MetalLB pool `.80`–`.89`. Docs only — no module behavior change.

## [1.5.0] - 2026-05-24

### Changed

- **`modules/flash-nodes`**: `firmware` sources are now routed by scheme — an `http(s)://` value is flashed via the provider's `firmware_url` (BMC pulls directly; its `Done` signal covers download + decompress + eMMC write end-to-end), and any other value continues to use `firmware_file` (local path). Previously every value was sent to `firmware_file`, so a URL — as passed by the `talos-full-stack` example — went down the streaming-upload path that reports `Done` before the eMMC write completes (provider v1.5.0 flags this as unreliable). Backward compatible: existing local-path configs are unchanged. The provider constraint is bumped to `>= 1.5.0` (where `firmware_url` was introduced); the `examples/talos-full-stack` pin matches.

### Fixed

- **`examples/talos-full-stack` & `examples/k3s-full-stack`**: these examples configured `provider "helm"` / `provider "kubectl"` but never declared them in `required_providers`, so `tofu/terraform init` inferred `hashicorp/kubectl` and failed (`registry does not have a provider named hashicorp/kubectl`) — the addon modules require `gavinbunney/kubectl`. Added the missing `helm` (`hashicorp/helm`, `~> 2.0`) and `kubectl` (`gavinbunney/kubectl`, `>= 1.14`) entries. helm is pinned to 2.x because the examples use the v2 nested `kubernetes {}` provider block, which helm v3 replaced with an attribute. Both examples now pass `validate`.
- **`examples/talos-full-stack`**: removed `allow_scheduling_on_control_plane = true` from the `talos-cluster` module call — that variable does not exist on the module (control-plane scheduling is done via `controlplane_patches`), so the example failed `validate` with "Unsupported argument".
- **Helper scripts** (`scripts/cluster-preflight.sh`, `scripts/talos-wipe.sh`, `scripts/k3s-wipe.sh`): fixed credential auto-load, which referenced misspelled secrets filenames `~/.secrets/turning-pi-cluster-bmc` and `~/.secrets/turningpi-cluster` (double-n "turning") that never matched the real single-n files (`turing-pi-cluster-bmc`, `turingpi-cluster`). The lookups silently failed, so the scripts fell back to the hardcoded BMC defaults (`root` / `turing`) and the wrong SSH key. Corrected all references; the script headers now also document the combined `turing-pi-cluster-bmc` format the code checks first.
- **`modules/addons/ingress-nginx`**: corrected the module source in the README Usage example from the non-existent `freed-dev-llc/ingress-nginx/kubernetes` to the canonical `freed-dev-llc/modules/turingpi//modules/addons/ingress-nginx` (matches the other addon READMEs and the module's own Registry badge). The old value failed `terraform init` for anyone who copy-pasted it. The line sits above the `BEGIN_TF_DOCS` marker, so terraform-docs never regenerated it. Docs only — no behavior change (#48).

### Documentation

- Release stamps bumped to v1.5.0: `README.md` "Verified Configurations" header (modules) and the `docs/MANUAL_TEST_PLAN.md` "Module Version" footer; `docs/UPGRADE.md` gained a v1.5.0 section. Also corrected a `turning-`→`turing-` secrets-filename typo in an earlier changelog entry.
- `docs/MANUAL_TEST_PLAN.md`: bumped the "Module Version" footer stamp from v1.4.1 to v1.4.2 to track the current release (#48).

## [1.4.2] - 2026-05-22

### Changed

- **Version pins refreshed across docs**: `README.md` Quick Start examples bumped from `~> 1.3.9` to `~> 1.4`; the requirements line for the sister provider bumped to `~> 1.5`. `docs/MANUAL_TEST_PLAN.md` provider examples bumped from `>= 1.3.0` to `>= 1.5.0`. `docs/UPGRADE.md` `?ref=v1.3.5` references throughout the file bumped to `?ref=v1.4.1` (plus the rollback example to `v1.4.0`). `modules/talos-cluster/README.md` schematic-download example bumped to Talos v1.9.2 to match the verified baseline. Submodule Usage examples standardized at `version = ">= 1.4.0"` (`cert-manager` switched from git-source `?ref=` form to Registry shortform; `talos-image` got an explicit version pin) (#42, #43, #46, #47).
- **Module count coverage**: `CONTRIBUTING.md` ("all 8 modules" → "all 10 modules"), `.github/PULL_REQUEST_TEMPLATE.md` (added `talos-image` and `cert-manager`, re-prefixed addons as `addons/<name>`), and `docs/ARCHITECTURE.md` (added `talos-image` and `addons/cert-manager` to the Module Structure tree + Provider Dependencies table) — all out of sync since v1.4.1's CI matrix expansion (#42).
- **`docs/UPGRADE.md`**: added v1.4.0 and v1.4.1 sections at the top of "Breaking Changes" (which previously stopped at v1.3.5); one-line "v1.3.6 – v1.3.10" rollup for the incremental polish releases (#42).

### Documentation

- `.editorconfig` added (#45) — LF / UTF-8 / trailing-whitespace trim across Markdown, Makefile, YAML, and other text files.
- README.md "Verified Configurations" header bumped from v1.3.9 to v1.4.1 (modules) / v1.5.0 (provider).
- `docs/MANUAL_TEST_PLAN.md`: Talos image example bumped from v1.9.1 to v1.9.2 (verified per CHANGELOG); "Module Version" footer bumped from v1.2.2 to v1.4.1.
- `docs/WORKFLOWS.md`: Version History table extended past 2026-01-19 with the self-hosted runner migration (v1.4.1) and the mermaid neutral-theme convention (#41) (#43).
- CHANGELOG footer: added `[1.4.1]` compare-link entry; `[Unreleased]` advanced from `v1.4.0...HEAD` to `v1.4.1...HEAD` (#42).

## [1.4.1] - 2026-05-17

### Changed

- **`modules/talos-image`**: declare `hashicorp/local` in `required_providers`. The module uses `data "local_file"` but the provider was previously inferred; explicit declaration is required by tflint and makes the contract clearer for consumers. Most users won't notice — Terraform/OpenTofu auto-resolve `hashicorp/local` from the registry.
- Modules' READMEs (terraform-docs auto-generated) re-rendered to use the constraint form (`>= 1.0`) instead of the resolved version (`1.3.10`) for the `turingpi` provider — matches what CI emits.

### CI / docs hygiene (no module behavior changes)

- All 10 modules now covered by `validate.yml` matrix and `docs.yml` loop (was 8; `modules/talos-image` and `modules/addons/cert-manager` were missing).
- `docs.yml` auto-commit step now has `permissions: contents: write` (was hitting 403 on push).
- `validate.yml` defensively purges `~/.terraformrc` before each matrix entry to avoid cross-job state leakage from the sister provider repo's `cli-smoketest` workflow.
- `terraform-docs/gh-actions` Docker action replaced with `go install terraform-docs@v0.20.0` + shell loop (Docker actions fail on the containerized self-hosted runner).
- `aquasecurity/trivy-action` bumped 0.34.0 → 0.35.0 (older version failed with permission errors on the new runner).
- `actions/dependency-review-action` 4.8.2 → 4.9.0 (Dependabot, PR #12).
- Root `README.md` Addon Modules table now includes `cert-manager` and is alphabetized.
- Root `main.tf` comment refreshed from 4 modules to 10 (grouped Cluster / Addon).
- Self-hosted runner migration (commits `5ef13ae`, `7e89d2c`) — workflows now use `runs-on: [self-hosted, linux]`.

### Compatibility

No breaking changes. Module input/output signatures unchanged. The `talos-image` `required_providers` declaration is additive only.

## [1.4.0] - 2026-03-07

### Changed

- Migrated organization from `jfreed-dev` to `freed-dev-llc`
- Updated all GitHub URLs, Terraform Registry sources, and documentation references
- Fixed TFLint unused declaration warning for longhorn `talos_extensions_installed` variable

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
- Scripts now auto-load credentials from `~/.secrets/turing-pi-cluster-bmc` file format
- Scripts auto-detect SSH key from `~/.secrets/turingpi-cluster`

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

[Unreleased]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.4.2...v1.5.0
[1.4.2]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/freed-dev-llc/terraform-turingpi-modules/compare/v1.3.10...v1.4.0
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
