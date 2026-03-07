# Architecture

This document describes the architecture and module composition of the Terraform Turing Pi Modules.

## Module Dependency Diagram

```mermaid
graph TD
    subgraph "Cluster Provisioning"
        FN[flash-nodes] --> TC[talos-cluster]
        FN --> KC[k3s-cluster]
    end

    subgraph "Kubernetes Addons"
        TC --> MLB[metallb]
        KC --> MLB
        MLB --> ING[ingress-nginx]
        TC --> LH[longhorn]
        KC --> LH
        LH --> MON[monitoring]
        MLB --> MON
        MLB --> PORT[portainer]
    end

    subgraph "External Dependencies"
        TP[turingpi provider] -.-> FN
        TALOS[talos provider] -.-> TC
        HELM[helm provider] -.-> MLB
        HELM -.-> ING
        HELM -.-> LH
        HELM -.-> MON
        HELM -.-> PORT
        K8S[kubernetes provider] -.-> MLB
    end
```

## Deployment Flow

```mermaid
sequenceDiagram
    participant User
    participant Terraform
    participant BMC
    participant Nodes
    participant K8s

    User->>Terraform: terraform apply
    Terraform->>BMC: Flash firmware (optional)
    BMC->>Nodes: Install OS image
    Nodes-->>BMC: Boot complete

    alt Talos Cluster
        Terraform->>Nodes: Apply Talos config
        Nodes->>Nodes: Bootstrap etcd
        Nodes-->>Terraform: Cluster ready
    else K3s Cluster
        Terraform->>Nodes: SSH install k3s
        Nodes->>Nodes: Join cluster
        Nodes-->>Terraform: Cluster ready
    end

    Terraform->>K8s: Deploy MetalLB
    K8s-->>Terraform: LoadBalancer ready
    Terraform->>K8s: Deploy Ingress
    K8s-->>Terraform: Ingress ready
    Terraform->>K8s: Deploy Longhorn
    K8s-->>Terraform: Storage ready
    Terraform->>K8s: Deploy Monitoring
    K8s-->>Terraform: Grafana ready
    Terraform->>K8s: Deploy Portainer
    K8s-->>Terraform: Agent connected
```

## Addon Composition

```mermaid
graph LR
    subgraph "Layer 1: Network Foundation"
        MLB[MetalLB<br/>LoadBalancer IPs]
    end

    subgraph "Layer 2: Ingress"
        ING[Ingress-NGINX<br/>HTTP/HTTPS routing]
    end

    subgraph "Layer 3: Storage"
        LH[Longhorn<br/>Distributed storage]
    end

    subgraph "Layer 4: Observability"
        PROM[Prometheus<br/>Metrics]
        GRAF[Grafana<br/>Dashboards]
        ALERT[Alertmanager<br/>Alerts]
    end

    subgraph "Layer 5: Management"
        PORT[Portainer<br/>Cluster UI]
    end

    MLB --> ING
    MLB --> LH
    LH --> PROM
    PROM --> GRAF
    PROM --> ALERT
    MLB --> PORT
```

## Module Structure

```
terraform-turingpi-modules/
├── modules/
│   ├── flash-nodes/        # Firmware flashing via BMC API
│   ├── talos-cluster/      # Talos Linux Kubernetes
│   ├── k3s-cluster/        # K3s on Armbian
│   └── addons/
│       ├── metallb/        # Layer 2/BGP load balancer
│       ├── ingress-nginx/  # Ingress controller
│       ├── longhorn/       # Distributed block storage
│       ├── monitoring/     # Prometheus/Grafana stack
│       └── portainer/      # Cluster management UI
├── examples/
│   ├── talos-full-stack/   # Complete Talos deployment
│   └── k3s-full-stack/     # Complete K3s deployment
└── test/
    └── provider-test/      # Provider data source tests
```

## Provider Dependencies

| Module | Required Providers |
|--------|-------------------|
| flash-nodes | `freed-dev-llc/turingpi` |
| talos-cluster | `siderolabs/talos`, `hashicorp/kubernetes` |
| k3s-cluster | `hashicorp/null` (SSH provisioner) |
| metallb | `hashicorp/helm`, `hashicorp/kubernetes` |
| ingress-nginx | `hashicorp/helm` |
| longhorn | `hashicorp/helm` |
| monitoring | `hashicorp/helm` |
| portainer | `hashicorp/helm` |

## Recommended Deployment Order

1. **flash-nodes** (optional) - Flash firmware to compute modules
2. **talos-cluster** or **k3s-cluster** - Bootstrap Kubernetes
3. **metallb** - Enable LoadBalancer service type
4. **ingress-nginx** - HTTP/HTTPS ingress (requires MetalLB)
5. **longhorn** - Persistent storage (can deploy in parallel with ingress)
6. **monitoring** - Observability stack (requires storage)
7. **portainer** - Management UI (requires MetalLB)

## Design Principles

- **Modularity**: Each addon is independently deployable
- **Composability**: Modules declare explicit dependencies via `depends_on`
- **Flexibility**: All modules support customization via variables
- **Idempotency**: Safe to re-apply without side effects
- **Documentation**: Auto-generated docs via terraform-docs
