# Kubernetes Offline Bundle Creator

Create complete, self-contained installation bundles for Kubernetes worker nodes. Perfect for air-gapped environments.

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28%20|%201.29%20|%201.30-326CE5?logo=kubernetes)](https://kubernetes.io)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-orange?logo=ubuntu)](https://ubuntu.com)

## Overview

Automated tool to create offline installation bundles containing everything needed to install Kubernetes worker nodes without internet access

### What's Included

Each bundle contains:

- **Kubernetes Binaries** (kubeadm, kubelet, kubectl, crictl)
- **Container Runtime** (containerd, ctr, runc)
- **CNI Plugins** (bridge, host-local, loopback, etc.)
- **System Packages** (APT packages with dependencies)
- **Configuration Files** (kernel modules, sysctl settings, systemd services)
- **Installation Scripts** (automated installer)

### Supported Versions

| Kubernetes | containerd | runc | crictl | CNI Plugins | Ubuntu |
|------------|------------|------|--------|-------------|--------|
| 1.30.2 | 1.7.18 | 1.1.13 | 1.30.0 | 1.5.0 | 20.04, 22.04, 24.04 |
| 1.29.6 | 1.7.17 | 1.1.12 | 1.29.0 | 1.4.1 | 20.04, 22.04, 24.04 |
| 1.28.11 | 1.7.16 | 1.1.12 | 1.28.0 | 1.4.0 | 20.04, 22.04 |

## Prerequisites

**Build machine requirements:**
- Ubuntu/Debian system with internet connection
- Required packages:
  ```bash
  sudo apt update
  sudo apt install -y curl wget tar gzip python3 python3-yaml python3-jinja2 apt-transport-https
  ```

**Target machine requirements:**
- Ubuntu 20.04, 22.04, or 24.04
- No internet connection required
- Root access for installation

## Quick Start

### Build a Bundle

```bash
# 1. Build the bundle (default: K8s 1.30.2)
make build

# 2. Verify integrity
make verify

# 3. Show bundle info
make show-info
```

The bundle will be created at: `k8s-bundle-output/k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz`

### Install on Target System

Copy the bundle to your target system (without internet) and run:

```bash
# Extract
tar -xzf k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz
cd k8s-complete-1.30.2-ubuntu22.04-amd64

# Install everything
sudo ./install-k8s.sh

# Join the cluster
sudo kubeadm join <master-ip>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

## Build Options

### Build Specific Versions

```bash
# Quick build for common versions
make build-1.30      # Kubernetes 1.30.2
make build-1.29      # Kubernetes 1.29.6
make build-1.28      # Kubernetes 1.28.11

# Build specific version
make build K8S_VERSION=1.30.2

# Build for ARM64
make build ARCH=arm64

# Build for different Ubuntu version
make build UBUNTU_VERSION=24.04

# Build with Flannel instead of Calico
CNI_PROVIDER=flannel make build
```

### Advanced Options

```bash
# Build all versions at once
make build-all

# Quick build + verify + info
make quick

# Extract bundle for inspection
make extract

# List available K8s versions
make list-versions

# Clean generated files
make clean
```

### Environment Variables

You can customize the build with environment variables:

```bash
# Skip downloading packages (reuse cached)
SKIP_APT_DOWNLOAD=yes make build
SKIP_PIP_DOWNLOAD=yes make build

# Skip components
DOWNLOAD_IMAGES=no make build    # Don't create images list
DOWNLOAD_CNI=no make build       # Skip CNI manifests

# Keep workspace after build
SKIP_CLEANUP=yes make build
```

## Project Structure

```
k8s-isos/
├── README.md                    # This file
├── Makefile                     # Build automation
├── k8s-versions.yaml           # Kubernetes versions matrix
│
├── config/                      # System configuration (CUSTOMIZABLE)
│   ├── apt-packages.yaml       # APT packages list
│   ├── pip-packages.yaml       # PIP packages list
│   ├── kernel-modules.yaml     # Kernel modules
│   ├── sysctl-settings.yaml    # Sysctl parameters
│   └── README.md
│
├── scripts/                     # Main scripts
│   ├── create-k8s-bundle.sh    # Main bundle creator
│   ├── download-apt.sh         # APT package downloader
│   ├── download-pip.sh         # PIP package downloader
│   ├── verify-bundle.sh        # Bundle verifier
│   └── list-k8s-versions.py    # Version lister
│
├── templates/                   # Jinja2 templates (CUSTOMIZABLE)
│   ├── config/                  # Configuration templates
│   │   ├── containerd-config.toml.j2
│   │   ├── crictl.yaml.j2
│   │   └── README.md
│   ├── scripts/                 # Script templates
│   │   ├── load-kernel-modules.sh.j2
│   │   ├── apply-sysctl.sh.j2
│   │   └── README.md
│   └── install/                 # Installation script template
│       ├── install-k8s.sh.j2
│       └── README.md
│
├── docs/                        # Documentation
│   ├── TEMPLATE-CUSTOMIZATION.md
│   ├── ANSIBLE-PLAYBOOK-COMPATIBILITY.md
│   └── CNI-HELM-CHART-GUIDE.md
│
└── k8s-bundle-output/          # Generated bundles (after build)
    ├── k8s-complete-*.tar.gz
    ├── k8s-complete-*.tar.gz.sha256
    └── k8s-complete-*.tar.gz.md5
```

## What Gets Installed

### Binaries

| Component | Path | Purpose |
|-----------|------|---------|
| kubelet | /usr/bin/kubelet | Node agent |
| kubeadm | /usr/bin/kubeadm | Cluster join tool |
| kubectl | /usr/bin/kubectl | CLI tool |
| crictl | /usr/local/bin/crictl | CRI debugging |
| containerd | /usr/local/bin/containerd | Container runtime |
| ctr | /usr/local/bin/ctr | containerd CLI |
| runc | /usr/local/sbin/runc | OCI runtime |
| CNI plugins | /opt/cni/bin/* | Network plugins |

### System Packages

- **Networking**: ipvsadm, ipset, iptables, ebtables, nftables, conntrack, socat
- **Storage**: nfs-common, open-iscsi, multipath-tools
- **Utilities**: jq, vim, curl, wget, tcpdump, sysstat, lsof, net-tools

### System Configuration

- **Kernel modules**: overlay, br_netfilter, ip_vs, nf_conntrack, nvme_tcp
- **Sysctl**: IP forwarding, bridge netfilter enabled
- **Swap**: Automatically disabled
- **Systemd**: kubelet and containerd services configured

## Bundle Contents

After extraction, the bundle directory contains:

```
k8s-complete-1.30.2-ubuntu22.04-amd64/
├── binaries/
│   ├── kubernetes/          # kubeadm, kubelet, kubectl, crictl
│   ├── containerd/          # containerd, ctr, runc
│   └── cni/                 # CNI plugins + manifests
├── packages/
│   ├── apt/                 # .deb packages
│   └── pip/                 # Python wheels
├── config/
│   ├── k8s-modules.conf     # Kernel modules
│   ├── k8s-sysctl.conf      # Sysctl settings
│   ├── containerd-config.toml
│   └── crictl.yaml
├── scripts/
│   ├── install-apt.sh       # APT installer
│   └── install-pip.sh       # PIP installer
├── images/
│   └── images.txt           # Container images list
├── install-k8s.sh           # Main installer
└── README.md                # Bundle documentation
```

## Usage Examples

### Example 1: Basic Worker Node

```bash
# Build bundle
make build

# On target machine (offline)
tar -xzf k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz
cd k8s-complete-1.30.2-ubuntu22.04-amd64
sudo ./install-k8s.sh

# Join cluster
sudo kubeadm join 192.168.1.10:6443 --token abc123.xyz \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### Example 2: ARM64 Worker

```bash
# Build for ARM64
make build ARCH=arm64

# Transfer to ARM64 machine and install
tar -xzf k8s-complete-1.30.2-ubuntu22.04-arm64.tar.gz
cd k8s-complete-1.30.2-ubuntu22.04-arm64
sudo ./install-k8s.sh
```

### Example 3: Multiple Versions

```bash
# Build all versions
make build-all

# Result:
# k8s-bundle-output/k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz
# k8s-bundle-output/k8s-complete-1.29.6-ubuntu22.04-amd64.tar.gz
# k8s-bundle-output/k8s-complete-1.28.11-ubuntu22.04-amd64.tar.gz
```

### Example 4: Custom Build

```bash
# Build with Flannel, skip cached packages
CNI_PROVIDER=flannel \
SKIP_APT_DOWNLOAD=yes \
SKIP_PIP_DOWNLOAD=yes \
make build K8S_VERSION=1.30.2
```

## Verification

### Verify Bundle Integrity

```bash
# Check checksums
make verify

# Manual verification
cd k8s-bundle-output
sha256sum -c k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz.sha256
```

### Verify Installation

After installing on the target system:

```bash
# Check versions
kubeadm version
kubelet --version
kubectl version --client
crictl --version

# Check services
systemctl status containerd
systemctl status kubelet

# Check modules
lsmod | grep -E 'overlay|br_netfilter|ip_vs'

# Check sysctl
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

## Troubleshooting

### Bundle Creation Issues

**Problem**: Missing python3-yaml
```bash
sudo apt install -y python3-yaml
```

**Problem**: Download fails
```bash
# Check internet connection
curl -I https://dl.k8s.io

# Try with clean cache
make clean && make build
```

### Installation Issues

**Problem**: Kubelet fails to start
```bash
# Check logs
journalctl -u kubelet -n 50

# Verify binary path
which kubelet  # Should be /usr/bin/kubelet

# Check service file
cat /etc/systemd/system/kubelet.service
```

**Problem**: Containerd not running
```bash
# Check status
systemctl status containerd

# Check logs
journalctl -u containerd -n 50

# Restart
sudo systemctl restart containerd
```

## Customization

Two levels of customization available:

### 1. System Configuration (Simple)

Edit YAML files in `config/` directory to customize packages and settings.

**Add APT package** - Edit `config/apt-packages.yaml`:
```yaml
- name: "htop"
  version: ""  # Empty for latest, or "1.0.3*" for specific version
```

**Add Python package** - Edit `config/pip-packages.yaml`:
```yaml
- name: "ansible"
  version: "latest"
```

**Add kernel module** - Edit `config/kernel-modules.yaml`:
```yaml
- iscsi_tcp
```

**Add sysctl parameter** - Edit `config/sysctl-settings.yaml`:
```yaml
net.ipv4.tcp_tw_reuse: 1
```

After editing config files, rebuild:
```bash
make clean
make build
```

See [config/README.md](config/README.md) for detailed format information.

### 2. Template Customization (Advanced)

Edit Jinja2 templates in `templates/` directory for advanced configurations.

**Add private registry mirror** - Edit `templates/config/containerd-config.toml.j2`:
```toml
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."myregistry.local"]
  endpoint = ["https://myregistry.local:5000"]
```

**Increase crictl timeout** - Edit `templates/config/crictl.yaml.j2`:
```yaml
timeout: 60  # Default is 30
```

**Add HTTP proxy** - Edit `templates/install/install-k8s.sh.j2` in the containerd section:
```bash
mkdir -p /etc/systemd/system/containerd.service.d
cat > /etc/systemd/system/containerd.service.d/http-proxy.conf << 'EOF'
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080"
Environment="HTTPS_PROXY=http://proxy.example.com:8080"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF
```

After editing templates, rebuild:
```bash
make validate-templates  # Optional: check syntax
make build
```

See [docs/TEMPLATE-CUSTOMIZATION.md](docs/TEMPLATE-CUSTOMIZATION.md) for complete guide

## Documentation

### Project Documentation

- [Template Customization Guide](docs/TEMPLATE-CUSTOMIZATION.md) - Complete guide to customizing templates
- [CNI Helm Chart Guide](docs/CNI-HELM-CHART-GUIDE.md) - Using Calico via Helm
- [Ansible Playbook Integration](docs/ANSIBLE-PLAYBOOK-COMPATIBILITY.md) - Integration with Ansible

### Official Kubernetes Documentation

- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [Adding Linux worker nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/adding-linux-nodes/)
- [Debugging with crictl](https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/)

### Version Information

All version compatibility information is defined in `k8s-versions.yaml`. To see available versions:

```bash
make list-versions
```

## Contributing

Contributions are welcome! Please submit issues or pull requests on GitHub.

## License

MIT License - See LICENSE file for details

## Important Notes

1. **Paths Matter**: Kubernetes binaries MUST be in `/usr/bin/` because the systemd service expects them there
2. **crictl is Required**: Essential for CRI debugging and recommended by Kubernetes
3. **ctr Included**: Automatically included with containerd, no separate download needed
4. **kube-proxy**: Deployed automatically as DaemonSet when joining cluster with `kubeadm join`
5. **Swap**: Must be disabled for Kubernetes (done automatically by installer)
6. **Version Matching**: Use matching versions of crictl and Kubernetes for best compatibility

## What This Project Does

- Downloads all required binaries with checksum verification
- Packages APT and PIP packages with all dependencies
- Creates ready-to-use offline bundles
- Generates installation scripts
- Configures kernel modules and sysctl settings
- Verifies bundle integrity

## What This Project Doesn't Do

- Install master/control-plane nodes (use `kubeadm init` separately)
- Configure networking/CNI (apply CNI manifest after cluster init)
- Manage cluster lifecycle (use kubectl/kubeadm for that)
- Create custom ISOs (use tools like Cubic separately if needed)

---

**Made for Kubernetes 1.30.2 worker nodes**

## CNI Configuration

### Understanding CNI Components

This bundle includes two separate CNI components:

1. **CNI Plugins** (always included)
   - Basic network binaries: bridge, loopback, host-local, portmap, etc.
   - Required by containerd
   - Installed to `/opt/cni/bin/`

2. **CNI Network Provider** (optional)
   - Full network solution: Calico, Flannel, etc.
   - Can be installed via manifest or Helm

### Build Options

| Use Case | Command | Includes CNI Manifest |
|----------|---------|----------------------|
| Calico via Helm | `CNI_PROVIDER=none make build` | No (install via Helm later) |
| Calico via Manifest | `make build` (default) | Yes (calico.yaml included) |
| Flannel via Manifest | `CNI_PROVIDER=flannel make build` | Yes (flannel.yaml included) |

### Example: Using Calico via Helm

```bash
# 1. Build bundle without CNI manifest
CNI_PROVIDER=none make build

# 2. Transfer and install on worker node
tar -xzf k8s-complete-*.tar.gz
cd k8s-complete-*
sudo ./install-k8s.sh

# 3. Join cluster
sudo kubeadm join <master-ip>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>

# 4. Install Calico via Helm (from machine with kubectl access)
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm install calico projectcalico/tigera-operator \
  --namespace tigera-operator --create-namespace

# 5. Verify node is ready
kubectl get nodes
```

See [docs/CNI-HELM-CHART-GUIDE.md](docs/CNI-HELM-CHART-GUIDE.md) for more details.

