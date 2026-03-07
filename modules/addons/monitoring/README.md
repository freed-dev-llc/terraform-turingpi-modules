# Kubernetes Monitoring Module (kube-prometheus-stack)

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest/submodules/addons-monitoring)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to deploy the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) for comprehensive Kubernetes monitoring.

Includes:

- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and management
- **Node Exporter** - Host-level metrics
- **kube-state-metrics** - Kubernetes state metrics

## Prerequisites

### Storage Class

By default, this module requires a storage class for Prometheus, Grafana, and Alertmanager persistent volumes. The default storage class is `longhorn`.

**Storage Requirements:**

| Component | Default Size | Recommended Minimum |
|-----------|--------------|---------------------|
| Prometheus | 20Gi | 10Gi (eMMC), 20Gi+ (NVMe) |
| Grafana | 5Gi | 5Gi |
| Alertmanager | 2Gi | 2Gi |

For nodes with limited storage (e.g., 32GB eMMC), reduce storage sizes:

```hcl
module "monitoring" {
  source = "freed-dev-llc/modules/turingpi//modules/addons/monitoring"

  grafana_admin_password  = "your-secure-password"
  prometheus_storage_size = "10Gi"  # Reduced for eMMC
}
```

For clusters **without storage** (e.g., Talos without Longhorn), set `persistence_enabled = false` to run in ephemeral mode:

```hcl
module "monitoring" {
  source = "freed-dev-llc/modules/turingpi//modules/addons/monitoring"

  grafana_admin_password = "your-secure-password"
  persistence_enabled    = false  # Ephemeral mode - data lost on restart
}
```

### Talos Linux

On Talos Linux, Longhorn requires system extensions (`iscsi-tools`, `util-linux-tools`). See the [Longhorn module](../longhorn) for details on building Talos images with these extensions.

### Namespace Security (PSA)

The node-exporter component requires privileged access (hostNetwork, hostPID, hostPath). On clusters with Pod Security Admission enabled, this module automatically creates the namespace with privileged labels (default: `privileged_namespace = true`).

**Platform defaults:**

- **Talos Linux**: Requires `privileged_namespace = true` (PSA enforced)
- **K3s/K8s**: Can use `privileged_namespace = false` (PSA not enforced by default)

If you need to disable this behavior:

```hcl
module "monitoring" {
  source = "freed-dev-llc/modules/turingpi//modules/addons/monitoring"

  grafana_admin_password = "your-secure-password"
  privileged_namespace   = false  # Don't create namespace with PSA labels
}
```

## Usage

```hcl
module "monitoring" {
  source  = "freed-dev-llc/modules/turingpi//modules/addons/monitoring"
  version = ">= 1.3.0"

  # Change default password!
  grafana_admin_password = "your-secure-password"

  # Storage class (requires Longhorn or similar)
  storage_class = "longhorn"
  # persistence_enabled = true  # Default: requires storage class

  # Optional: Enable Ingress for web access
  # grafana_ingress_enabled     = true
  # grafana_ingress_host        = "grafana.local"
  # prometheus_ingress_enabled  = true
  # prometheus_ingress_host     = "prometheus.local"
  # alertmanager_ingress_enabled = true
  # alertmanager_ingress_host    = "alertmanager.local"

  # Optional: Talos control plane endpoint for component scraping
  # control_plane_endpoint = "10.10.88.73"

  # Optional: External monitoring targets
  # external_targets = ["192.168.1.100", "192.168.1.101"]
  # docker_hosts     = ["192.168.1.100"]
  # cadvisor_hosts   = ["192.168.1.100"]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.14 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 1.14 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_grafana_admin_password"></a> [grafana\_admin\_password](#input\_grafana\_admin\_password) | Grafana admin password (minimum 8 characters recommended) | `string` | n/a | yes |
| <a name="input_alertmanager_enabled"></a> [alertmanager\_enabled](#input\_alertmanager\_enabled) | Enable Alertmanager deployment | `bool` | `true` | no |
| <a name="input_alertmanager_ingress_enabled"></a> [alertmanager\_ingress\_enabled](#input\_alertmanager\_ingress\_enabled) | Enable Ingress for Alertmanager | `bool` | `false` | no |
| <a name="input_alertmanager_ingress_host"></a> [alertmanager\_ingress\_host](#input\_alertmanager\_ingress\_host) | Hostname for Alertmanager Ingress | `string` | `"alertmanager.local"` | no |
| <a name="input_alertmanager_storage_size"></a> [alertmanager\_storage\_size](#input\_alertmanager\_storage\_size) | Alertmanager persistent volume size | `string` | `"2Gi"` | no |
| <a name="input_cadvisor_hosts"></a> [cadvisor\_hosts](#input\_cadvisor\_hosts) | List of hosts running cAdvisor to monitor (port 8080) | `list(string)` | `[]` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | kube-prometheus-stack Helm chart version | `string` | `"65.8.1"` | no |
| <a name="input_control_plane_endpoint"></a> [control\_plane\_endpoint](#input\_control\_plane\_endpoint) | Control plane IP for scraping kube-controller-manager, kube-scheduler, etcd | `string` | `null` | no |
| <a name="input_docker_hosts"></a> [docker\_hosts](#input\_docker\_hosts) | List of Docker host IPs to monitor (port 9323) | `list(string)` | `[]` | no |
| <a name="input_external_targets"></a> [external\_targets](#input\_external\_targets) | List of external host IPs to monitor with node\_exporter (port 9100) | `list(string)` | `[]` | no |
| <a name="input_grafana_enabled"></a> [grafana\_enabled](#input\_grafana\_enabled) | Enable Grafana deployment | `bool` | `true` | no |
| <a name="input_grafana_ingress_enabled"></a> [grafana\_ingress\_enabled](#input\_grafana\_ingress\_enabled) | Enable Ingress for Grafana | `bool` | `false` | no |
| <a name="input_grafana_ingress_host"></a> [grafana\_ingress\_host](#input\_grafana\_ingress\_host) | Hostname for Grafana Ingress | `string` | `"grafana.local"` | no |
| <a name="input_grafana_persistence_enabled"></a> [grafana\_persistence\_enabled](#input\_grafana\_persistence\_enabled) | Enable persistent storage for Grafana | `bool` | `true` | no |
| <a name="input_grafana_storage_size"></a> [grafana\_storage\_size](#input\_grafana\_storage\_size) | Grafana persistent volume size | `string` | `"5Gi"` | no |
| <a name="input_kube_state_metrics_enabled"></a> [kube\_state\_metrics\_enabled](#input\_kube\_state\_metrics\_enabled) | Enable kube-state-metrics | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for monitoring stack | `string` | `"monitoring"` | no |
| <a name="input_node_exporter_enabled"></a> [node\_exporter\_enabled](#input\_node\_exporter\_enabled) | Enable Node Exporter for host metrics | `bool` | `true` | no |
| <a name="input_persistence_enabled"></a> [persistence\_enabled](#input\_persistence\_enabled) | Enable persistent storage for Prometheus, Grafana, and Alertmanager. Set to false for ephemeral deployments (testing, Talos without storage) | `bool` | `true` | no |
| <a name="input_privileged_namespace"></a> [privileged\_namespace](#input\_privileged\_namespace) | Apply privileged PodSecurity labels to namespace (required for node-exporter on Talos/PSA-enabled clusters) | `bool` | `true` | no |
| <a name="input_prometheus_cpu_limit"></a> [prometheus\_cpu\_limit](#input\_prometheus\_cpu\_limit) | Prometheus CPU limit | `string` | `"1000m"` | no |
| <a name="input_prometheus_cpu_request"></a> [prometheus\_cpu\_request](#input\_prometheus\_cpu\_request) | Prometheus CPU request | `string` | `"250m"` | no |
| <a name="input_prometheus_enabled"></a> [prometheus\_enabled](#input\_prometheus\_enabled) | Enable Prometheus deployment | `bool` | `true` | no |
| <a name="input_prometheus_ingress_enabled"></a> [prometheus\_ingress\_enabled](#input\_prometheus\_ingress\_enabled) | Enable Ingress for Prometheus | `bool` | `false` | no |
| <a name="input_prometheus_ingress_host"></a> [prometheus\_ingress\_host](#input\_prometheus\_ingress\_host) | Hostname for Prometheus Ingress | `string` | `"prometheus.local"` | no |
| <a name="input_prometheus_memory_limit"></a> [prometheus\_memory\_limit](#input\_prometheus\_memory\_limit) | Prometheus memory limit | `string` | `"2Gi"` | no |
| <a name="input_prometheus_memory_request"></a> [prometheus\_memory\_request](#input\_prometheus\_memory\_request) | Prometheus memory request | `string` | `"512Mi"` | no |
| <a name="input_prometheus_retention"></a> [prometheus\_retention](#input\_prometheus\_retention) | Prometheus data retention period | `string` | `"15d"` | no |
| <a name="input_prometheus_retention_size"></a> [prometheus\_retention\_size](#input\_prometheus\_retention\_size) | Prometheus data retention size | `string` | `"18GB"` | no |
| <a name="input_prometheus_storage_size"></a> [prometheus\_storage\_size](#input\_prometheus\_storage\_size) | Prometheus persistent volume size | `string` | `"20Gi"` | no |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | Storage class for persistent volumes | `string` | `"longhorn"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Helm install timeout in seconds | `number` | `600` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alertmanager_url"></a> [alertmanager\_url](#output\_alertmanager\_url) | Alertmanager URL (if ingress enabled) |
| <a name="output_chart_version"></a> [chart\_version](#output\_chart\_version) | Deployed chart version |
| <a name="output_grafana_service"></a> [grafana\_service](#output\_grafana\_service) | Grafana service name for port-forwarding |
| <a name="output_grafana_url"></a> [grafana\_url](#output\_grafana\_url) | Grafana URL (if ingress enabled) |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Monitoring namespace |
| <a name="output_prometheus_service"></a> [prometheus\_service](#output\_prometheus\_service) | Prometheus service name for port-forwarding |
| <a name="output_prometheus_url"></a> [prometheus\_url](#output\_prometheus\_url) | Prometheus URL (if ingress enabled) |
<!-- END_TF_DOCS -->

## Accessing Without Ingress

Use kubectl port-forward:

```bash
# Grafana (default: admin/admin)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

## License

Apache 2.0 - See [LICENSE](../../../LICENSE) for details.
