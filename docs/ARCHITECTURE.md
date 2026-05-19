# Architecture

This document describes the architecture and module composition of the Terraform Turing Pi Modules.

## Module Dependency Diagram

```mermaid
%%{init: {'theme': 'neutral'}}%%
graph TD
    subgraph "Image Build"
        TI[talos-image]
    end

    subgraph "Cluster Provisioning"
        TI --> FN[flash-nodes]
        FN --> TC[talos-cluster]
        FN --> KC[k3s-cluster]
    end

    subgraph "Kubernetes Addons"
        TC --> MLB[addons/metallb]
        KC --> MLB
        TC --> CM[addons/cert-manager]
        KC --> CM
        MLB --> ING[addons/ingress-nginx]
        CM --> ING
        TC --> LH[addons/longhorn]
        KC --> LH
        LH --> MON[addons/monitoring]
        MLB --> MON
        MLB --> PORT[addons/portainer]
    end

    subgraph "External Dependencies"
        HTTP[http provider] -.-> TI
        LOCAL[local provider] -.-> TI
        TP[turingpi provider] -.-> FN
        TALOS[talos provider] -.-> TC
        HELM[helm provider] -.-> MLB
        HELM -.-> ING
        HELM -.-> LH
        HELM -.-> MON
        HELM -.-> PORT
        HELM -.-> CM
        KCTL[kubectl provider] -.-> CM
        K8S[kubernetes provider] -.-> MLB
    end
```

## Deployment Flow

```mermaid
%%{init: {'theme': 'neutral'}}%%
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
%%{init: {'theme': 'neutral'}}%%
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
│   ├── talos-image/        # Talos Image Factory client (build/cache schematics)
│   ├── k3s-cluster/        # K3s on Armbian
│   └── addons/
│       ├── cert-manager/   # TLS certificate management
│       ├── metallb/        # Layer 2/BGP load balancer
│       ├── ingress-nginx/  # Ingress controller
│       ├── longhorn/       # Distributed block storage
│       ├── monitoring/     # Prometheus/Grafana stack
│       └── portainer/      # Cluster management UI
├── examples/
│   ├── talos-full-stack/   # Complete Talos deployment
│   └── k3s-full-stack/     # Complete K3s deployment
└── test/                   # addon-test, cluster-install, k3s-test,
                            # provider-test, talos-cluster-test, talos-test
```

## Provider Dependencies

| Module | Required Providers |
|--------|-------------------|
| flash-nodes | `freed-dev-llc/turingpi` |
| talos-cluster | `siderolabs/talos`, `hashicorp/kubernetes` |
| talos-image | `hashicorp/http`, `hashicorp/local` |
| k3s-cluster | `hashicorp/null` (SSH provisioner) |
| cert-manager | `hashicorp/helm`, `gavinbunney/kubectl` |
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
