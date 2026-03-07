# Manual Test Plan - Turing Pi Cluster Deployment

This document provides step-by-step instructions for testing the terraform-turingpi-modules on a physical Turing Pi 2.5 cluster.

## Prerequisites

- Turing Pi 2.5 board with 4 compute modules (RK1 or CM4)
- Network connectivity to all nodes
- Terraform >= 1.0 installed
- `talosctl` installed (for Talos deployments)
- SSH key configured (for K3s deployments)
- Firmware images available:
  - Talos: `talos-rk1-v1.9.1.raw.xz` (or latest)
  - Armbian: `armbian-rk1.img` (for K3s)

## Environment Variables

```bash
# BMC credentials
export TURINGPI_USERNAME=root
export TURINGPI_PASSWORD=turing
export TURINGPI_ENDPOINT=https://turingpi.local

# Node IPs (adjust for your network)
export CP_IP=192.168.1.101
export WORKER1_IP=192.168.1.102
export WORKER2_IP=192.168.1.103
export WORKER3_IP=192.168.1.104

# MetalLB IP range
export METALLB_RANGE="192.168.1.200-192.168.1.220"
export INGRESS_IP=192.168.1.200
export PORTAINER_IP=192.168.1.201
```

---

## Phase 1: Cluster Wipe

### 1.1 Power Off All Nodes

```bash
cd ~/Code/terraform-turingpi-modules/test/wipe

cat > main.tf << 'EOF'
terraform {
  required_providers {
    turingpi = {
      source  = "freed-dev-llc/turingpi"
      version = ">= 1.3.0"
    }
  }
}

provider "turingpi" {}

resource "turingpi_power" "node1" {
  node  = 1
  state = "off"
}

resource "turingpi_power" "node2" {
  node  = 2
  state = "off"
}

resource "turingpi_power" "node3" {
  node  = 3
  state = "off"
}

resource "turingpi_power" "node4" {
  node  = 4
  state = "off"
}
EOF

terraform init
terraform apply -auto-approve
```

### 1.2 Verify Power State

```bash
# Check BMC shows all nodes off
curl -sk -u "$TURINGPI_USERNAME:$TURINGPI_PASSWORD" \
  "$TURINGPI_ENDPOINT/api/bmc?opt=get&type=power" | jq
```

**Expected**: All nodes show `power: 0`

### 1.3 Cleanup Previous State

```bash
# Remove any existing kubeconfig/talosconfig
rm -f ~/Code/terraform-turingpi-modules/test/*/kubeconfig
rm -f ~/Code/terraform-turingpi-modules/test/*/talosconfig
rm -f ~/.kube/config.turingpi
```

---

## Phase 2A: Talos Cluster Deployment

### 2A.1 Flash Talos Firmware

```bash
cd ~/Code/terraform-turingpi-modules/test/talos-deploy

cat > main.tf << 'EOF'
terraform {
  required_providers {
    turingpi = {
      source  = "freed-dev-llc/turingpi"
      version = ">= 1.3.0"
    }
  }
}

provider "turingpi" {}

variable "talos_firmware" {
  default = "/path/to/talos-rk1-v1.9.1.raw.xz"
}

resource "turingpi_flash" "nodes" {
  for_each = toset(["1", "2", "3", "4"])

  node          = tonumber(each.key)
  firmware_file = var.talos_firmware
}

resource "turingpi_power" "nodes" {
  for_each   = toset(["1", "2", "3", "4"])
  depends_on = [turingpi_flash.nodes]

  node  = tonumber(each.key)
  state = "on"
}
EOF

terraform init
terraform apply -auto-approve
```

### 2A.2 Wait for Nodes to Boot

```bash
# Wait 2-3 minutes for Talos to boot
sleep 180

# Verify nodes are responding
for ip in $CP_IP $WORKER1_IP $WORKER2_IP $WORKER3_IP; do
  echo "Checking $ip..."
  talosctl -n $ip version --insecure 2>/dev/null && echo "OK" || echo "FAIL"
done
```

**Expected**: All nodes respond with Talos version

### 2A.3 Deploy Talos Cluster

```bash
cat >> main.tf << 'EOF'

module "talos_cluster" {
  source = "../../modules/talos-cluster"

  cluster_name     = "test-talos"
  cluster_endpoint = "https://${var.cp_ip}:6443"

  control_plane = [{ host = var.cp_ip }]
  workers = [
    { host = var.worker1_ip },
    { host = var.worker2_ip },
    { host = var.worker3_ip }
  ]

  nvme_storage_enabled = true
  nvme_device          = "/dev/nvme0n1"
  nvme_mountpoint      = "/var/mnt/longhorn"
  nvme_control_plane   = true

  kubeconfig_path  = "${path.module}/kubeconfig"
  talosconfig_path = "${path.module}/talosconfig"
}

variable "cp_ip" {
  default = "192.168.1.101"
}

variable "worker1_ip" {
  default = "192.168.1.102"
}

variable "worker2_ip" {
  default = "192.168.1.103"
}

variable "worker3_ip" {
  default = "192.168.1.104"
}

output "kubeconfig_path" {
  value = module.talos_cluster.kubeconfig_path
}
EOF

terraform apply -auto-approve
```

### 2A.4 Verify Cluster Health

```bash
export KUBECONFIG=$(pwd)/kubeconfig

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Check talosctl
export TALOSCONFIG=$(pwd)/talosconfig
talosctl -n $CP_IP health
```

**Expected**:

- 4 nodes Ready (1 control-plane, 3 workers)
- All kube-system pods Running
- talosctl health shows all checks passing

---

## Phase 2B: K3s Cluster Deployment (Alternative)

### 2B.1 Flash Armbian Firmware

```bash
cd ~/Code/terraform-turingpi-modules/test/k3s-deploy

cat > main.tf << 'EOF'
terraform {
  required_providers {
    turingpi = {
      source  = "freed-dev-llc/turingpi"
      version = ">= 1.3.0"
    }
  }
}

provider "turingpi" {}

variable "armbian_firmware" {
  default = "/path/to/armbian-rk1.img"
}

resource "turingpi_flash" "nodes" {
  for_each = toset(["1", "2", "3", "4"])

  node          = tonumber(each.key)
  firmware_file = var.armbian_firmware
}

resource "turingpi_power" "nodes" {
  for_each   = toset(["1", "2", "3", "4"])
  depends_on = [turingpi_flash.nodes]

  node  = tonumber(each.key)
  state = "on"
}
EOF

terraform init
terraform apply -auto-approve
```

### 2B.2 Wait for Nodes and Configure SSH

```bash
# Wait 3-4 minutes for Armbian to boot
sleep 240

# Verify SSH access (may need to accept host keys)
for ip in $CP_IP $WORKER1_IP $WORKER2_IP $WORKER3_IP; do
  echo "Checking $ip..."
  ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$ip "hostname" || echo "FAIL"
done
```

**Expected**: All nodes respond with hostname

### 2B.3 Deploy K3s Cluster

```bash
cat >> main.tf << 'EOF'

module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name = "test-k3s"
  k3s_version  = "v1.31.4+k3s1"

  control_plane = {
    host     = var.cp_ip
    ssh_user = "root"
    ssh_key  = file("~/.ssh/id_rsa")
  }

  workers = [
    { host = var.worker1_ip, ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") },
    { host = var.worker2_ip, ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") },
    { host = var.worker3_ip, ssh_user = "root", ssh_key = file("~/.ssh/id_rsa") }
  ]

  nvme_storage_enabled = true
  nvme_device          = "/dev/nvme0n1"
  nvme_mountpoint      = "/var/lib/longhorn"
  nvme_filesystem      = "ext4"
  nvme_control_plane   = true

  disable_traefik   = true
  disable_servicelb = true

  kubeconfig_path = "${path.module}/kubeconfig"
}

variable "cp_ip" {
  default = "192.168.1.101"
}

variable "worker1_ip" {
  default = "192.168.1.102"
}

variable "worker2_ip" {
  default = "192.168.1.103"
}

variable "worker3_ip" {
  default = "192.168.1.104"
}

output "kubeconfig_path" {
  value = module.k3s_cluster.kubeconfig_path
}
EOF

terraform apply -auto-approve
```

### 2B.4 Verify Cluster Health

```bash
export KUBECONFIG=$(pwd)/kubeconfig

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Verify NVMe mounted
ssh root@$CP_IP "df -h /var/lib/longhorn"
```

**Expected**:

- 4 nodes Ready
- All kube-system pods Running
- NVMe mounted at /var/lib/longhorn

---

## Phase 3: Deploy K8s Applications (Addons)

### 3.1 Configure Providers

```bash
# Continue in same directory (talos-deploy or k3s-deploy)

cat >> main.tf << 'EOF'

provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig"
  }
}

provider "kubectl" {
  config_path = "${path.module}/kubeconfig"
}
EOF
```

### 3.2 Deploy MetalLB

```bash
cat >> main.tf << 'EOF'

module "metallb" {
  source     = "../../modules/addons/metallb"
  depends_on = [module.talos_cluster]  # or module.k3s_cluster

  ip_range  = var.metallb_range
  pool_name = "default-pool"
}

variable "metallb_range" {
  default = "192.168.1.200-192.168.1.220"
}

output "metallb_pool" {
  value = module.metallb.pool_name
}
EOF

terraform init -upgrade
terraform apply -auto-approve
```

### 3.3 Verify MetalLB

```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
```

**Expected**:

- controller and speaker pods Running
- IPAddressPool "default-pool" exists
- L2Advertisement configured

### 3.4 Deploy Ingress-NGINX

```bash
cat >> main.tf << 'EOF'

module "ingress" {
  source     = "../../modules/addons/ingress-nginx"
  depends_on = [module.metallb]

  loadbalancer_ip = var.ingress_ip
}

variable "ingress_ip" {
  default = "192.168.1.200"
}

output "ingress_ip" {
  value = var.ingress_ip
}
EOF

terraform apply -auto-approve
```

### 3.5 Verify Ingress-NGINX

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Test ingress responds
curl -sk https://$INGRESS_IP 2>&1 | head -5
```

**Expected**:

- ingress-nginx-controller pod Running
- Service has EXTERNAL-IP = $INGRESS_IP
- curl returns nginx default backend (404)

### 3.6 Deploy Longhorn

```bash
cat >> main.tf << 'EOF'

module "longhorn" {
  source     = "../../modules/addons/longhorn"
  depends_on = [module.metallb]

  default_data_path         = "/var/mnt/longhorn"  # Talos
  # default_data_path       = "/var/lib/longhorn"  # K3s
  default_replica_count     = 2
  set_default_storage_class = true

  create_nvme_storage_class = true
  nvme_replica_count        = 2
}

output "longhorn_storage_class" {
  value = module.longhorn.default_storage_class
}
EOF

terraform apply -auto-approve
```

### 3.7 Verify Longhorn

```bash
kubectl get pods -n longhorn-system
kubectl get storageclass

# Check Longhorn UI (port-forward)
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80 &
echo "Longhorn UI: http://localhost:8080"
```

**Expected**:

- All longhorn pods Running
- StorageClass "longhorn" is default
- StorageClass "longhorn-nvme" exists
- UI shows all nodes with NVMe disks

### 3.8 Deploy Monitoring Stack

```bash
cat >> main.tf << 'EOF'

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

module "monitoring" {
  source     = "../../modules/addons/monitoring"
  depends_on = [module.longhorn]

  grafana_admin_password      = var.grafana_password
  grafana_persistence_enabled = true
  storage_class               = "longhorn"

  prometheus_retention    = "7d"
  prometheus_storage_size = "10Gi"

  grafana_ingress_enabled = true
  grafana_ingress_host    = "grafana.local"
}

output "grafana_url" {
  value = "http://grafana.local (add to /etc/hosts: ${var.ingress_ip} grafana.local)"
}
EOF

terraform apply -auto-approve
```

### 3.9 Verify Monitoring

```bash
kubectl get pods -n monitoring
kubectl get pvc -n monitoring

# Check Grafana via ingress
echo "$INGRESS_IP grafana.local" | sudo tee -a /etc/hosts
curl -s http://grafana.local/api/health | jq
```

**Expected**:

- Prometheus, Grafana, Alertmanager pods Running
- PVCs bound to Longhorn volumes
- Grafana health check returns OK

### 3.10 Deploy Portainer

```bash
cat >> main.tf << 'EOF'

module "portainer" {
  source     = "../../modules/addons/portainer"
  depends_on = [module.metallb]

  service_type    = "LoadBalancer"
  loadbalancer_ip = var.portainer_ip
}

variable "portainer_ip" {
  default = "192.168.1.201"
}

output "portainer_url" {
  value = module.portainer.connection_url
}
EOF

terraform apply -auto-approve
```

### 3.11 Verify Portainer

```bash
kubectl get pods -n portainer
kubectl get svc -n portainer

# Check agent is accessible
nc -zv $PORTAINER_IP 9001
```

**Expected**:

- portainer-agent pod Running
- Service has EXTERNAL-IP = $PORTAINER_IP
- Port 9001 is open

---

## Phase 4: Validation Checklist

### Cluster Health

| Check | Command | Expected |
|-------|---------|----------|
| Nodes Ready | `kubectl get nodes` | 4 nodes Ready |
| System Pods | `kubectl get pods -A \| grep -v Running` | Empty (all Running) |
| PVCs Bound | `kubectl get pvc -A` | All Bound |
| Services | `kubectl get svc -A --field-selector type=LoadBalancer` | IPs assigned |

### Addon Functionality

| Addon | Test | Expected |
|-------|------|----------|
| MetalLB | Create LoadBalancer svc | Gets IP from pool |
| Ingress | curl https://$INGRESS_IP | Returns response |
| Longhorn | Create PVC with storageClass=longhorn | PVC Bound |
| Grafana | Login to <http://grafana.local> | Dashboard loads |
| Portainer | Connect agent from Portainer CE | Cluster visible |

### Storage Test

```bash
# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-nvme
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc -w
# Wait for Bound status

# Cleanup
kubectl delete pvc test-pvc
```

### Load Balancer Test

```bash
# Create test service
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Wait for IP
kubectl get svc nginx -w

# Test
curl http://$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Cleanup
kubectl delete svc nginx
kubectl delete deployment nginx
```

---

## Phase 5: Cleanup

### 5.1 Destroy Addons

```bash
terraform destroy -target=module.portainer -auto-approve
terraform destroy -target=module.monitoring -auto-approve
terraform destroy -target=module.longhorn -auto-approve
terraform destroy -target=module.ingress -auto-approve
terraform destroy -target=module.metallb -auto-approve
```

### 5.2 Destroy Cluster

```bash
# For Talos
terraform destroy -target=module.talos_cluster -auto-approve

# For K3s
terraform destroy -target=module.k3s_cluster -auto-approve
```

### 5.3 Power Off Nodes

```bash
terraform destroy -auto-approve
```

---

## Troubleshooting

### Talos Issues

```bash
# Check Talos logs
talosctl -n $CP_IP logs controller-runtime

# Reset node (if stuck)
talosctl -n $NODE_IP reset --graceful=false

# Check etcd
talosctl -n $CP_IP etcd members
```

### K3s Issues

```bash
# Check K3s logs
ssh root@$CP_IP "journalctl -u k3s -f"

# Check agent logs
ssh root@$WORKER1_IP "journalctl -u k3s-agent -f"

# Uninstall K3s
ssh root@$CP_IP "/usr/local/bin/k3s-uninstall.sh"
ssh root@$WORKER1_IP "/usr/local/bin/k3s-agent-uninstall.sh"
```

### Longhorn Issues

```bash
# Check manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100

# Check disk status
kubectl get nodes.longhorn.io -n longhorn-system -o yaml
```

### MetalLB Issues

```bash
# Check speaker logs
kubectl logs -n metallb-system -l component=speaker --tail=100

# Verify L2 mode
kubectl get l2advertisement -n metallb-system -o yaml
```

---

## Test Results Template

| Phase | Status | Notes |
|-------|--------|-------|
| 1. Cluster Wipe | ⬜ | |
| 2A. Talos Flash | ⬜ | |
| 2A. Talos Cluster | ⬜ | |
| 2B. K3s Flash | ⬜ | |
| 2B. K3s Cluster | ⬜ | |
| 3.1 MetalLB | ⬜ | |
| 3.2 Ingress-NGINX | ⬜ | |
| 3.3 Longhorn | ⬜ | |
| 3.4 Monitoring | ⬜ | |
| 3.5 Portainer | ⬜ | |
| 4. Validation | ⬜ | |
| 5. Cleanup | ⬜ | |

**Tester**: _______________
**Date**: _______________
**Cluster Type**: ⬜ Talos / ⬜ K3s
**Module Version**: v1.2.2
