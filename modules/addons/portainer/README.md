# Portainer Agent Module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest/submodules/addons-portainer)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to deploy the [Portainer](https://www.portainer.io/) agent for remote cluster management.

The agent allows you to connect this Kubernetes cluster to a Portainer CE (Community Edition) or Business Edition instance for visual management.

## Usage

```hcl
module "portainer" {
  source  = "freed-dev-llc/modules/turingpi//modules/addons/portainer"
  version = ">= 1.3.0"

  # Use LoadBalancer with MetalLB
  service_type    = "LoadBalancer"
  loadbalancer_ip = "192.168.1.81"

  # Or use NodePort
  # service_type = "NodePort"
  # node_port    = 30778
}
```

Then connect from your Portainer instance using the agent URL.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.14 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 1.14 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_version"></a> [agent\_version](#input\_agent\_version) | Portainer agent version | `string` | `"2.24.1"` | no |
| <a name="input_cpu_limit"></a> [cpu\_limit](#input\_cpu\_limit) | CPU limit | `string` | `"500m"` | no |
| <a name="input_cpu_request"></a> [cpu\_request](#input\_cpu\_request) | CPU request | `string` | `"50m"` | no |
| <a name="input_loadbalancer_ip"></a> [loadbalancer\_ip](#input\_loadbalancer\_ip) | LoadBalancer IP (for MetalLB, optional) | `string` | `null` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Agent log level (DEBUG, INFO, WARN, ERROR) | `string` | `"INFO"` | no |
| <a name="input_memory_limit"></a> [memory\_limit](#input\_memory\_limit) | Memory limit | `string` | `"256Mi"` | no |
| <a name="input_memory_request"></a> [memory\_request](#input\_memory\_request) | Memory request | `string` | `"64Mi"` | no |
| <a name="input_node_port"></a> [node\_port](#input\_node\_port) | NodePort port number (when service\_type is NodePort) | `number` | `30778` | no |
| <a name="input_service_type"></a> [service\_type](#input\_service\_type) | Service type: NodePort or LoadBalancer | `string` | `"LoadBalancer"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_port"></a> [agent\_port](#output\_agent\_port) | Agent port |
| <a name="output_agent_version"></a> [agent\_version](#output\_agent\_version) | Deployed agent version |
| <a name="output_connection_url"></a> [connection\_url](#output\_connection\_url) | URL to connect from Portainer CE/BE |
| <a name="output_loadbalancer_ip"></a> [loadbalancer\_ip](#output\_loadbalancer\_ip) | LoadBalancer IP (if specified) |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Portainer namespace |
| <a name="output_node_port"></a> [node\_port](#output\_node\_port) | NodePort (if service type is NodePort) |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Portainer agent service name |
| <a name="output_service_type"></a> [service\_type](#output\_service\_type) | Service type |
<!-- END_TF_DOCS -->

## Connecting to Portainer

### Portainer Community Edition (CE)

Portainer CE is free and open-source. You can run it anywhere:

1. **Self-hosted Portainer CE:**

   ```bash
   docker run -d -p 9443:9443 --name portainer \
     --restart=always \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v portainer_data:/data \
     portainer/portainer-ce:latest
   ```

2. **Connect your cluster:**
   - Go to **Environments** > **Add environment**
   - Select **Agent**
   - Enter the connection URL:
     - LoadBalancer: `<loadbalancer_ip>:9001`
     - NodePort: `<any_node_ip>:30778`
   - Give the environment a name
   - Click **Connect**

### Portainer Business Edition

Portainer Business Edition includes additional features like RBAC, registry management, and GitOps. It requires a license.

1. **Get a license:**
   - Free for up to 5 nodes: [portainer.io/take-5](https://www.portainer.io/take-5)
   - Purchase: [portainer.io/pricing](https://www.portainer.io/pricing)

2. **Deploy Portainer BE:**

   ```bash
   docker run -d -p 9443:9443 --name portainer \
     --restart=always \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v portainer_data:/data \
     portainer/portainer-ee:latest
   ```

3. **Connect your cluster:**
   - Enter your license key on first login
   - Go to **Environments** > **Add environment**
   - Select **Agent**
   - Enter the connection URL:
     - LoadBalancer: `<loadbalancer_ip>:9001`
     - NodePort: `<any_node_ip>:30778`
   - Give the environment a name
   - Click **Connect**

### Business Edition Features

If you have a Business Edition license, you can take advantage of:

- **Role-Based Access Control (RBAC)** - Fine-grained permissions
- **Registry Management** - Manage multiple container registries
- **GitOps Deployments** - Deploy from Git repositories
- **Edge Compute** - Manage edge environments
- **Activity Logs** - Audit trail of all actions
- **External Authentication** - LDAP, OAuth, Azure AD

## Example with MetalLB

```hcl
module "metallb" {
  source   = "freed-dev-llc/modules/turingpi//modules/addons/metallb"
  ip_range = "192.168.1.80-192.168.1.89"
}

module "portainer" {
  source          = "freed-dev-llc/modules/turingpi//modules/addons/portainer"
  depends_on      = [module.metallb]
  loadbalancer_ip = "192.168.1.81"
}

output "portainer_url" {
  value = module.portainer.connection_url
}
```

## Full Stack Example

```hcl
# Deploy Talos cluster
module "cluster" {
  source  = "freed-dev-llc/modules/turingpi//modules/talos-cluster"
  version = ">= 1.3.0"

  cluster_name     = "homelab"
  cluster_endpoint = "https://192.168.1.101:6443"
  control_plane    = [{ host = "192.168.1.101" }]
  workers = [
    { host = "192.168.1.102" },
    { host = "192.168.1.103" },
    { host = "192.168.1.104" }
  ]
  kubeconfig_path = "./kubeconfig"
}

# Deploy MetalLB for LoadBalancer support
module "metallb" {
  source     = "freed-dev-llc/modules/turingpi//modules/addons/metallb"
  depends_on = [module.cluster]
  ip_range   = "192.168.1.200-192.168.1.220"
}

# Deploy Portainer agent
module "portainer" {
  source          = "freed-dev-llc/modules/turingpi//modules/addons/portainer"
  depends_on      = [module.metallb]
  loadbalancer_ip = "192.168.1.201"
}

output "portainer_connection" {
  description = "Connect Portainer to this URL"
  value       = module.portainer.connection_url
}
```

## License

Apache 2.0 - See [LICENSE](../../../LICENSE) for details.
