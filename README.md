# Kubernetes Offline Bundle Creator

> **Create complete offline installation bundles for Kubernetes worker nodes**

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28%20|%201.29%20|%201.30-326CE5?logo=kubernetes)](https://kubernetes.io)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-orange?logo=ubuntu)](https://ubuntu.com)

## 📋 Overview

This project provides automated scripts to create complete offline installation bundles for Kubernetes worker nodes. Each bundle contains everything needed to install and configure a Kubernetes worker node without internet access.

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

## 🚀 Quick Start

### Prerequisites

```bash
# Ubuntu/Debian system with internet connection
sudo apt update
sudo apt install -y curl wget tar gzip python3 python3-yaml apt-transport-https
```

### Create Bundle (3 Steps)

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

## 📦 Build Options

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

## 📁 Project Structure

```
k8s-isos/
├── README.md                    # This file
├── Makefile                     # Build automation
├── k8s-versions.yaml           # Version matrix
│
├── create-k8s-bundle.sh        # Main bundle creator
├── download-apt.sh             # APT package downloader
├── download-pip.sh             # PIP package downloader
├── verify-bundle.sh            # Bundle verifier
├── list-k8s-versions.py        # Version lister
│
└── k8s-bundle-output/          # Generated bundles (after build)
    ├── k8s-complete-*.tar.gz
    ├── k8s-complete-*.tar.gz.sha256
    └── k8s-complete-*.tar.gz.md5
```

## 📋 What Gets Installed

### Binaries

| Binary | Path | Version | Purpose |
|--------|------|---------|---------|
| kubelet | /usr/bin/kubelet | 1.30.2 | Node agent |
| kubeadm | /usr/bin/kubeadm | 1.30.2 | Cluster join tool |
| kubectl | /usr/bin/kubectl | 1.30.2 | CLI tool |
| crictl | /usr/local/bin/crictl | 1.30.0 | CRI debugging |
| containerd | /usr/local/bin/containerd | 1.7.18 | Container runtime |
| ctr | /usr/local/bin/ctr | 1.7.18 | containerd CLI |
| runc | /usr/local/sbin/runc | 1.1.13 | OCI runtime |
| CNI plugins | /opt/cni/bin/* | 1.5.0 | Network plugins |

### System Packages (APT)

- **Networking**: ipvsadm, ipset, iptables, ebtables, nftables, conntrack, socat
- **Storage**: nfs-common, open-iscsi, multipath-tools
- **Utilities**: jq, vim, curl, wget, tcpdump, sysstat, lsof, net-tools

### Kernel Modules

- overlay, br_netfilter
- ip_vs, ip_vs_rr, ip_vs_wrr, ip_vs_sh
- nf_conntrack, nvme_tcp

### System Configuration

- Sysctl: IP forwarding, bridge netfilter, connection tracking
- Swap: Automatically disabled
- Systemd: kubelet and containerd services configured

## 🔧 Bundle Contents

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

## 📖 Usage Examples

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

## 🔍 Verification

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

## 🛠️ Troubleshooting

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

## 📚 Documentation

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

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

MIT License - See LICENSE file for details

## ⚠️ Important Notes

1. **Paths Matter**: Kubernetes binaries MUST be in `/usr/bin/` because the systemd service expects them there
2. **crictl is Required**: Essential for CRI debugging and recommended by Kubernetes
3. **ctr Included**: Automatically included with containerd, no separate download needed
4. **kube-proxy**: Deployed automatically as DaemonSet when joining cluster with `kubeadm join`
5. **Swap**: Must be disabled for Kubernetes (done automatically by installer)
6. **Version Matching**: Use matching versions of crictl and Kubernetes for best compatibility

## 🎯 What This Project Does

✅ **Downloads** all required binaries with checksums
✅ **Packages** APT and PIP packages with dependencies
✅ **Creates** ready-to-use offline bundles
✅ **Generates** installation scripts
✅ **Configures** kernel modules and sysctl settings
✅ **Verifies** checksums and integrity

## 🚫 What This Project Doesn't Do

❌ Install master/control-plane nodes (use `kubeadm init` separately)
❌ Configure networking/CNI (apply CNI manifest after cluster init)
❌ Manage cluster lifecycle (use kubectl/kubeadm for that)
❌ Create custom ISOs (use tools like Cubic separately if needed)

---

**Made for Kubernetes 1.30.2 worker nodes**

## 🔌 CNI Configuration (Important!)

### If You Use Calico via Helm Chart

**Use this command:**
```bash
CNI_PROVIDER=none make build
```

This creates a bundle with:
- ✅ **CNI plugins base** (bridge, loopback, etc.) - **REQUIRED by containerd**
- ❌ **NO calico.yaml manifest** (you'll install via Helm instead)

### Understanding CNI

There are **TWO different things**:

1. **CNI Plugins Base** (cni-plugins-linux-amd64-v1.5.0.tgz)
   - Basic network binaries: bridge, loopback, host-local, portmap, etc.
   - Location: `/opt/cni/bin/`
   - Required by: containerd (ALWAYS needed)
   - **Always included in bundle** (cannot be omitted)

2. **CNI Network Solution** (Calico, Flannel, etc.)
   - Full network solution for Kubernetes
   - Install via:
     - **Option A**: Manifest → `kubectl apply -f calico.yaml`
     - **Option B**: Helm → `helm install calico projectcalico/tigera-operator`

### Build Options

| Use Case | Command | Includes |
|----------|---------|----------|
| **Calico via Helm** | `CNI_PROVIDER=none make build` | CNI plugins base only |
| Calico via Manifest | `make build` (default) | CNI plugins + calico.yaml |
| Flannel via Manifest | `CNI_PROVIDER=flannel make build` | CNI plugins + flannel.yaml |

### Complete Flow with Calico Helm Chart

```bash
# 1. Build bundle (machine with internet)
CNI_PROVIDER=none make build

# 2. Install on worker (offline)
sudo ./install-k8s.sh

# 3. Join cluster (via Ansible)
ansible-playbook worker-join-playbook.yml

# 4. Install Calico via Helm (from master/bastion)
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm install calico projectcalico/tigera-operator \
  --namespace tigera-operator \
  --create-namespace

# 5. Verify
kubectl get nodes  # Worker should be Ready
```

**See [CNI-HELM-CHART-GUIDE.md](CNI-HELM-CHART-GUIDE.md) for detailed information.**

