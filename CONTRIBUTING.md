# Contributing

Thank you for your interest in contributing to the Terraform Turing Pi Modules!

## Development Setup

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [TFLint](https://github.com/terraform-linters/tflint#installation)
- [Trivy](https://aquasecurity.github.io/trivy/latest/getting-started/installation/)
- [terraform-docs](https://terraform-docs.io/user-guide/installation/)
- [pre-commit](https://pre-commit.com/#install)

### Quick Install (Linux/macOS)

```bash
# TFLint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

# terraform-docs
curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.19.0/terraform-docs-v0.19.0-$(uname)-amd64.tar.gz
tar -xzf terraform-docs.tar.gz
chmod +x terraform-docs
sudo mv terraform-docs /usr/local/bin/

# pre-commit
pip install pre-commit
```

### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/freed-dev-llc/terraform-turingpi-modules.git
   cd terraform-turingpi-modules
   ```

2. Install pre-commit hooks:

   ```bash
   pre-commit install
   ```

3. Initialize TFLint plugins:

   ```bash
   tflint --init --config .tflint.hcl
   ```

## Development Workflow

### Before Committing

Pre-commit hooks run automatically on `git commit`. To run manually:

```bash
pre-commit run --all-files
```

### Running Checks Individually

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate a specific module
cd modules/talos-cluster
terraform init -backend=false
terraform validate

# Run TFLint on a module
tflint --config "$PWD/.tflint.hcl" --chdir modules/talos-cluster

# Run security scan
trivy config --config trivy.yaml .

# Generate documentation
terraform-docs --config .terraform-docs.yml modules/talos-cluster
```

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Ensure all checks pass:
   - `terraform fmt` - Code formatting
   - `terraform validate` - Syntax validation
   - `tflint` - Linting rules
   - `trivy` - Security scanning
   - `terraform-docs` - Documentation is up-to-date
4. Update documentation if adding/changing variables or outputs
5. Submit a pull request

### Required Status Checks

All PRs must pass:

- Terraform validation for all 8 modules
- Security scan (Trivy)
- Code owner review (@freed-dev-llc)

## Module Structure

Each module should contain:

```
modules/<name>/
├── main.tf           # Main resources
├── variables.tf      # Input variables (with descriptions)
├── outputs.tf        # Output values (with descriptions)
├── versions.tf       # Provider requirements
└── README.md         # Documentation with <!-- BEGIN_TF_DOCS --> markers
```

### Documentation

Module READMEs use terraform-docs for auto-generated sections. Add these markers where you want the generated content:

```markdown
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
```

The sections above the markers (Usage examples, etc.) are manually maintained.

## Code Style

- Use `snake_case` for resource names, variables, and outputs
- Include descriptions for all variables and outputs
- Use `optional()` for optional object attributes with defaults
- Keep provider version constraints in `versions.tf`
- Avoid hardcoded values; use variables with sensible defaults

## Secrets in Test Configurations

The `test/` directory is gitignored, but test configs must still follow secure patterns:

- **Never hardcode passwords** in `.tf` files — use
  `variable` blocks with `sensitive = true`
- **Supply values via `terraform.tfvars`** (also gitignored)
  or environment variables (`TF_VAR_*`)
- **No default values** on sensitive variables — require explicit input

Example pattern:

```hcl
variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

module "monitoring" {
  source             = "../../modules/addons/monitoring"
  grafana_admin_password = var.grafana_password
}
```

With a corresponding `terraform.tfvars`:

```hcl
grafana_password = "your-password-here"
```

## Commit Messages

Follow conventional commit style:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `chore:` Maintenance tasks
- `refactor:` Code refactoring

## Release Process (Maintainers)

Releases are created by tagging the main branch. All releases are GPG-signed.

### Creating a Release

1. Update `CHANGELOG.md` with the new version
2. Commit the changelog update:

   ```bash
   git add CHANGELOG.md
   git commit -S -m "docs: update changelog for v1.x.x"
   ```

3. Create a signed tag:

   ```bash
   git tag -s v1.x.x -m "Release v1.x.x"
   ```

4. Push to origin:

   ```bash
   git push origin main --tags
   ```

### Post-Release

After pushing the tag:

1. Verify the release appears on [GitHub Releases](https://github.com/freed-dev-llc/terraform-turingpi-modules/releases)
2. Confirm it syncs to [Terraform Registry](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi)

### Requirements

- GPG key configured for commit/tag signing (`git config commit.gpgsign true`)
- GPG key registered on GitHub for verified badges
- Push access to the repository

## Branch Protection (Maintainers)

The `main` branch has protection rules configured in GitHub. Recommended settings:

### Required Status Checks

Enable "Require status checks to pass before merging" with these checks:

- `validate` (Terraform validation)
- `trivy` (Security scanning)
- `dependency-review` (For PRs)

### Additional Protections

- **Require pull request reviews**: At least 1 approving review
- **Dismiss stale reviews**: When new commits are pushed
- **Require review from Code Owners**: Enabled (see CODEOWNERS)
- **Require signed commits**: Recommended for verified releases
- **Require linear history**: Optional, keeps history clean
- **Do not allow bypassing**: Even admins should follow the rules

## Questions?

Open an issue for questions or suggestions.
