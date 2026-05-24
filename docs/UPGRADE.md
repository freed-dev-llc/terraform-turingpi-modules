# Upgrade Guide

This document provides guidance for upgrading Terraform Turing Pi modules and the underlying Kubernetes components.

## Table of Contents

- [Module Version Upgrades](#module-version-upgrades)
- [K3s Version Upgrades](#k3s-version-upgrades)
- [Addon Upgrades](#addon-upgrades)
- [Breaking Changes](#breaking-changes)

## Module Version Upgrades

### Upgrading Module References

When upgrading to a new module version, update the `ref` tag in your module source:

```hcl
# Before
module "k3s_cluster" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/k3s-cluster?ref=v1.4.0"
  # ...
}

# After
module "k3s_cluster" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/k3s-cluster?ref=v1.4.1"
  # ...
}
```

### Steps for Module Upgrade

1. **Review the changelog** for breaking changes
2. **Update module source** to new version
3. **Run `terraform init -upgrade`** to fetch new module version
4. **Run `terraform plan`** to preview changes
5. **Apply changes** with `terraform apply`

```bash
terraform init -upgrade
terraform plan
terraform apply
```

## K3s Version Upgrades

### Automatic K3s Upgrades

The k3s-cluster module supports automatic version upgrades via the `k3s_version` variable:

```hcl
module "k3s_cluster" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/k3s-cluster?ref=v1.4.1"

  k3s_version = "v1.31.4+k3s1"  # Update to new version
  # ...
}
```

### Manual K3s Upgrade Process

For more control over the upgrade process:

1. **Backup etcd/cluster state** (if applicable)
2. **Drain control plane nodes** (optional but recommended)
3. **Upgrade control plane first**
4. **Upgrade worker nodes one at a time**
5. **Verify cluster health**

```bash
# On control plane
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.4+k3s1 sh -s - server

# On each worker
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.4+k3s1 K3S_URL=https://<server>:6443 K3S_TOKEN=<token> sh -s - agent
```

### Version Compatibility Matrix

| K3s Version | Kubernetes Version | Notes |
|-------------|-------------------|-------|
| v1.31.x | 1.31.x | Current stable |
| v1.30.x | 1.30.x | Previous stable |
| v1.29.x | 1.29.x | Maintenance |

## Addon Upgrades

### MetalLB

```hcl
module "metallb" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/addons/metallb?ref=v1.4.1"

  chart_version = "0.14.9"  # Update chart version
  ip_range      = "10.10.88.80-10.10.88.89"
}
```

**Upgrade considerations:**

- MetalLB upgrades are generally non-disruptive
- CRD updates may be required for major versions
- Test in staging environment first

### Ingress-NGINX

```hcl
module "ingress_nginx" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/addons/ingress-nginx?ref=v1.4.1"

  chart_version = "4.11.3"  # Update chart version
}
```

**Upgrade considerations:**

- May cause brief service interruption during controller pod restart
- Review ingress class changes between versions
- Test TLS certificate handling after upgrade

### Longhorn

```hcl
module "longhorn" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/addons/longhorn?ref=v1.4.1"

  chart_version = "1.7.2"  # Update chart version
}
```

**Upgrade considerations:**

- **Always backup data before upgrading**
- Check engine compatibility matrix
- Upgrade manager first, then engines
- Allow time for volume migrations

### Monitoring (kube-prometheus-stack)

```hcl
module "monitoring" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/addons/monitoring?ref=v1.4.1"

  chart_version          = "65.8.1"  # Update chart version
  grafana_admin_password = var.grafana_password
}
```

**Upgrade considerations:**

- Prometheus data retention during upgrade
- Grafana dashboard compatibility
- Alert rule migrations

### cert-manager

```hcl
module "cert_manager" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/addons/cert-manager?ref=v1.4.1"

  chart_version = "1.16.2"  # Update chart version
}
```

**Upgrade considerations:**

- CRD updates may be required
- Certificate renewal processes continue during upgrade
- Test ACME challenges after upgrade

## Breaking Changes

### Unreleased

**Changes (no breaks; opt-in):**

- `modules/k3s-cluster` adds `local_path_default` (default `true` — no change to existing behavior). If you install another default StorageClass (e.g. Longhorn) on K3s, set `local_path_default = false` so K3s's built-in `local-path` is no longer also marked default; otherwise the cluster has **two** default StorageClasses and PVCs omitting `storageClassName` bind nondeterministically. `local-path` remains available for explicit use. Ignored when `disable_local_storage = true`.

### v1.5.0

**Changes (no module interface breaks):**

- `modules/flash-nodes` now routes the `firmware` input by scheme: an `http(s)://` value is flashed via the provider's `firmware_url` (reliable BMC-pull completion signal); any other value continues to use `firmware_file`. Existing local-path configs are unchanged.
- The `turingpi` provider requirement for `modules/flash-nodes` (and the `talos-full-stack` example) is raised from `>= 1.0` to `>= 1.5.0`, where `firmware_url` was introduced. Upgrade the provider if you pin it below 1.5.0.
- `examples/talos-full-stack` and `examples/k3s-full-stack`: added the `helm` (`~> 2.0`) and `kubectl` (`gavinbunney/kubectl`, `>= 1.14`) `required_providers` entries the addon modules need — these examples previously failed `init`. Removed a nonexistent `allow_scheduling_on_control_plane` input from the Talos example.

### v1.4.1

**Changes (no breaks):**

- `modules/talos-image` now explicitly declares `hashicorp/local` in `required_providers`. Most users won't notice — Terraform/OpenTofu auto-resolves `hashicorp/local` from the registry.
- Module READMEs (terraform-docs auto-generated) re-rendered to use `>= 1.0` constraint form for the `turingpi` provider instead of the resolved version.
- CI-only: validation matrix and docs.yml loop now cover all 10 modules (previously missed `modules/talos-image` and `modules/addons/cert-manager`).

### v1.4.0

**Changes:**

- Migrated org namespace `jfreed-dev` → `freed-dev-llc`. The Terraform Registry source path is `freed-dev-llc/modules/turingpi` (and `//modules/<name>` for sub-paths). The GitHub source path is `github.com/freed-dev-llc/terraform-turingpi-modules`. Both old paths still redirect, but pin against the canonical owner in new code.
- Fixed TFLint unused-declaration warning for longhorn `talos_extensions_installed` variable.

### v1.3.6 – v1.3.10

Incremental polish (CI hardening, doc tweaks, dependency bumps). No module input/output signature changes. Safe to skip directly to v1.4.1.

### v1.3.5

**New features:**

- Added `namespace` variable to all addon modules
- Added `controller_resources` and `speaker_resources` to MetalLB
- Added `controller_replicas` and resource configuration to ingress-nginx
- Added `manager_resources` and `ui_replicas` to Longhorn
- Added Grafana password validation (minimum 8 characters)
- New cert-manager addon module

**Migration steps:**

1. If you were using default namespaces, no changes required
2. To use custom namespaces, add the `namespace` variable:

```hcl
module "metallb" {
  source = "..."

  namespace = "custom-metallb-namespace"  # New optional parameter
  ip_range  = "10.10.88.80-10.10.88.89"
}
```

1. For monitoring module, ensure Grafana password is at least 8 characters:

```hcl
module "monitoring" {
  source = "..."

  grafana_admin_password = "secure-password-here"  # Must be >= 8 chars
}
```

### v1.3.4

**Changes:**

- Synchronized release with terraform-provider-turingpi v1.3.4
- Provider now supports BMC firmware 2.3.4 API response format

### v1.3.3

**Changes:**

- Added CODE_OF_CONDUCT.md
- Added docs/ARCHITECTURE.md
- Added security workflow with Trivy scanning
- Enhanced SECURITY.md, CODEOWNERS, CONTRIBUTING.md

## Pre-Upgrade Checklist

Before upgrading any component:

- [ ] Review changelog and breaking changes
- [ ] Backup critical data (etcd, PVs, configurations)
- [ ] Test upgrade in staging environment
- [ ] Plan maintenance window if needed
- [ ] Notify users of potential downtime
- [ ] Verify rollback procedure

## Post-Upgrade Verification

After upgrading:

```bash
# Check all nodes are ready
kubectl get nodes

# Check all pods are running
kubectl get pods -A

# Check addon-specific health
kubectl get pods -n metallb-system
kubectl get pods -n ingress-nginx
kubectl get pods -n longhorn-system
kubectl get pods -n monitoring
kubectl get pods -n cert-manager

# Verify services have external IPs
kubectl get svc -A | grep LoadBalancer

# Check certificates (if using cert-manager)
kubectl get certificates -A
kubectl get clusterissuers
```

## Rollback Procedures

### Module Rollback

Revert to previous module version:

```hcl
module "k3s_cluster" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/k3s-cluster?ref=v1.4.0"  # Previous version
}
```

```bash
terraform init -upgrade
terraform apply
```

### Helm Release Rollback

For addon rollbacks:

```bash
# List release history
helm history <release-name> -n <namespace>

# Rollback to previous revision
helm rollback <release-name> <revision> -n <namespace>
```

## Getting Help

If you encounter issues during upgrade:

1. Check the [GitHub Issues](https://github.com/freed-dev-llc/terraform-turingpi-modules/issues)
2. Review Terraform and Helm logs
3. Open a new issue with upgrade details and error messages
