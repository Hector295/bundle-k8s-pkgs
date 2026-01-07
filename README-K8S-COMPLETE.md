# Kubernetes Complete Offline Bundle

> **Sistema completo para crear bundles offline de Kubernetes con TODAS las dependencias y versiones específicas**

## 🎯 Objetivo

Crear un **tar.gz autocontenido** con TODO lo necesario para instalar una versión específica de Kubernetes en modo offline, incluyendo:

✅ **Binarios de Kubernetes** (kubeadm, kubelet, kubectl)
✅ **Container Runtime** (containerd + runc)
✅ **CNI Plugins** (con manifests de Calico/Flannel)
✅ **System Packages** (iptables, ipvsadm, jq, etc.)
✅ **Configuraciones** (kernel modules, sysctl, systemd services)
✅ **Instalador automático** (script de instalación completa)

## 📋 Matriz de Versiones

El sistema usa una **matriz de versiones** (`k8s-versions.yaml`) que define TODAS las dependencias para cada versión de Kubernetes:

### Versiones Disponibles

| K8s Version | Release Date | Containerd | Runc | CNI Plugins | Estado |
|-------------|--------------|------------|------|-------------|--------|
| **1.30.2** | 2024-06-11 | 1.7.18 | 1.1.13 | 1.5.0 | ✅ Latest |
| **1.29.6** | 2024-06-11 | 1.7.17 | 1.1.12 | 1.4.1 | ✅ LTS |
| **1.28.11** | 2024-06-11 | 1.7.16 | 1.1.12 | 1.4.0 | ✅ Stable |

### Compatibilidad Ubuntu

| Ubuntu | Codename | K8s 1.28 | K8s 1.29 | K8s 1.30 |
|--------|----------|----------|----------|----------|
| 20.04 | focal | ✅ | ✅ | ✅ |
| 22.04 | jammy | ✅ | ✅ | ✅ |
| 24.04 | noble | ❌ | ✅ | ✅ |

### Arquitecturas Soportadas

- ✅ **amd64** (x86_64)
- ✅ **arm64** (aarch64)

## 🚀 Uso Rápido

### Crear Bundle para K8s 1.30.2 (Latest)

```bash
# Opción 1: Script directo
./create-k8s-bundle.sh

# Opción 2: Con Makefile
make build

# Opción 3: Con version específica
./create-k8s-bundle.sh 1.30.2 22.04 amd64
```

### Crear Bundle para Otras Versiones

```bash
# K8s 1.29.6
make build-1.29

# K8s 1.28.11
make build-1.28

# Version específica
./create-k8s-bundle.sh 1.29.6 22.04 amd64

# ARM64
./create-k8s-bundle.sh 1.30.2 22.04 arm64
```

### Con CNI Específico

```bash
# Usar Flannel en lugar de Calico
CNI_PROVIDER=flannel ./create-k8s-bundle.sh

# Sin CNI (solo plugins base)
CNI_PROVIDER=none ./create-k8s-bundle.sh
```

## 📦 Contenido del Bundle

### Estructura Completa

```
k8s-complete-1.30.2-ubuntu22.04-amd64/
│
├── install-k8s.sh           # ⭐ Instalador maestro (un solo comando)
├── README.md                # Documentación completa
│
├── binaries/                # Todos los binarios necesarios
│   ├── kubernetes/
│   │   ├── kubeadm         # v1.30.2
│   │   ├── kubelet         # v1.30.2
│   │   ├── kubectl         # v1.30.2
│   │   ├── kubelet.service # Systemd service
│   │   └── 10-kubeadm.conf # Kubelet config
│   │
│   ├── containerd/
│   │   ├── containerd-1.7.18-linux-amd64.tar.gz
│   │   ├── runc            # v1.1.13
│   │   └── containerd.service
│   │
│   └── cni/
│       ├── cni-plugins-linux-amd64-v1.5.0.tgz
│       ├── calico.yaml     # Calico v3.28.0 manifest
│       └── flannel.yaml    # Flannel v0.25.4 manifest (opcional)
│
├── packages/
│   ├── apt/                # ~100+ archivos .deb
│   │   ├── ipvsadm_*.deb
│   │   ├── iptables_*.deb
│   │   ├── conntrack_*.deb
│   │   ├── socat_*.deb
│   │   └── ...             # Todas las dependencias
│   │
│   └── pip/                # Python packages
│       └── jc-*.whl
│
├── images/
│   └── images.txt          # Lista de imágenes de contenedores
│       # pause:3.9
│       # coredns:v1.11.1
│       # etcd:3.5.12-0
│       # kube-apiserver:v1.30.2
│       # kube-controller-manager:v1.30.2
│       # kube-scheduler:v1.30.2
│       # kube-proxy:v1.30.2
│
├── config/
│   ├── k8s-modules.conf          # Kernel modules
│   ├── k8s-sysctl.conf           # Sysctl settings
│   ├── containerd-config.toml    # Containerd config
│   └── crictl.yaml               # Crictl config
│
└── scripts/
    └── install-apt.sh            # APT packages installer
```

### Dependencias del Sistema Incluidas

```yaml
# Networking
- ipvsadm (IPVS mode para kube-proxy)
- ipset (IP sets para firewall)
- iptables (Firewall rules)
- ebtables (Bridge filtering)
- conntrack (Connection tracking)
- socat (Port forwarding)
- bridge-utils (Bridge management)

# Storage
- nfs-common (NFS client)
- open-iscsi (iSCSI initiator)
- multipath-tools (Multipath storage)

# Tools
- jq (JSON parser)
- curl, wget (Downloads)
- vim (Editor)
- tcpdump (Network analysis)
- net-tools, iproute2 (Network tools)
- dnsutils (DNS tools)

# System
- cron, rsyslog, sysstat (System services)
- ca-certificates, apt-transport-https (Security)
```

## 🔧 Instalación

### Instalación Completa (Un Solo Comando)

```bash
# 1. Copiar bundle al sistema objetivo
scp k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz user@target:/tmp/

# 2. En el sistema objetivo
cd /tmp
tar -xzf k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz
cd k8s-complete-1.30.2-ubuntu22.04-amd64

# 3. Instalar TODO
sudo ./install-k8s.sh
```

El script `install-k8s.sh` hace:

1. ✅ Instala paquetes del sistema (APT + PIP)
2. ✅ Configura kernel modules (overlay, br_netfilter, ip_vs, etc.)
3. ✅ Aplica configuración sysctl
4. ✅ Deshabilita swap
5. ✅ Instala containerd + runc
6. ✅ Instala CNI plugins
7. ✅ Instala Kubernetes (kubeadm, kubelet, kubectl)
8. ✅ Configura systemd services
9. ✅ Verifica instalación

### Verificación Post-Instalación

```bash
# Verificar versiones
kubeadm version
kubelet --version
kubectl version --client

# Verificar containerd
sudo systemctl status containerd

# Verificar módulos del kernel
lsmod | grep -E 'overlay|br_netfilter|ip_vs'

# Verificar swap
swapon --show  # Debe estar vacío

# Verificar sysctl
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

## ⚙️ Inicializar Cluster

### Nodo Master

```bash
# 1. Inicializar cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 2. Configurar kubectl
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 3. Aplicar CNI (Calico)
kubectl apply -f binaries/cni/calico.yaml

# O Flannel
# kubectl apply -f binaries/cni/flannel.yaml

# 4. Verificar
kubectl get nodes
kubectl get pods -A
```

### Nodos Worker

```bash
# En cada nodo worker:
# 1. Instalar el bundle (mismo proceso)
sudo ./install-k8s.sh

# 2. Join al cluster (usar el comando que dio kubeadm init)
sudo kubeadm join <master-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>

# 3. Verificar desde master
kubectl get nodes
```

## 📊 Matriz de Versiones Completa

### K8s 1.30.2 (Latest)

```yaml
kubernetes: 1.30.2
containerd: 1.7.18
runc: 1.1.13
cni_plugins: 1.5.0
calico: 3.28.0
flannel: 0.25.4

images:
  - pause: 3.9
  - coredns: v1.11.1
  - etcd: 3.5.12-0
  - kube-*: v1.30.2

kernel_modules:
  - overlay
  - br_netfilter
  - ip_vs, ip_vs_rr, ip_vs_wrr, ip_vs_sh
  - nf_conntrack
  - nvme_tcp
```

### K8s 1.29.6 (LTS)

```yaml
kubernetes: 1.29.6
containerd: 1.7.17
runc: 1.1.12
cni_plugins: 1.4.1
calico: 3.27.3
flannel: 0.25.2

images:
  - pause: 3.9
  - coredns: v1.11.1
  - etcd: 3.5.12-0
  - kube-*: v1.29.6
```

### K8s 1.28.11 (Stable)

```yaml
kubernetes: 1.28.11
containerd: 1.7.16
runc: 1.1.12
cni_plugins: 1.4.0
calico: 3.27.0
flannel: 0.24.4

images:
  - pause: 3.9
  - coredns: v1.11.1
  - etcd: 3.5.12-0
  - kube-*: v1.28.11
```

## 🎛️ Personalización

### Agregar Nueva Versión de K8s

Editar `k8s-versions.yaml`:

```yaml
versions:
  "1.31.0":  # Nueva versión
    release_date: "2024-08-15"
    kubernetes:
      version: "1.31.0"
      components:
        kubeadm: "1.31.0-1.1"
        kubelet: "1.31.0-1.1"
        kubectl: "1.31.0-1.1"
    container_runtime:
      containerd:
        version: "1.7.19"
      runc:
        version: "1.1.14"
    # ... resto de configuración
```

### Cambiar Paquetes del Sistema

Editar `k8s-versions.yaml`:

```yaml
    system_packages:
      apt:
        - name: "mi-paquete-custom"
          version: "1.2.3*"
        # ... resto de paquetes
```

### Variables de Entorno

```bash
# Descargar imágenes de contenedores
DOWNLOAD_IMAGES=yes ./create-k8s-bundle.sh

# Omitir descarga de CNI
DOWNLOAD_CNI=no ./create-k8s-bundle.sh

# Usar Flannel en lugar de Calico
CNI_PROVIDER=flannel ./create-k8s-bundle.sh

# Sin CNI
CNI_PROVIDER=none ./create-k8s-bundle.sh
```

## 📏 Tamaños Esperados

### Bundle Completo

| Versión K8s | Ubuntu | Arch | Tamaño Aproximado |
|-------------|--------|------|-------------------|
| 1.30.2 | 22.04 | amd64 | ~500-700 MB |
| 1.29.6 | 22.04 | amd64 | ~480-650 MB |
| 1.28.11 | 22.04 | amd64 | ~470-640 MB |
| 1.30.2 | 22.04 | arm64 | ~520-720 MB |

### Desglose de Tamaño

- **Binarios K8s**: ~180 MB (kubeadm, kubelet, kubectl)
- **Containerd**: ~40 MB (runtime)
- **CNI Plugins**: ~50 MB (plugins + manifests)
- **System Packages**: ~200-300 MB (APT .deb con dependencias)
- **Configs**: ~1 MB (configuraciones y scripts)

## 🧪 Testing

### Verificar Bundle

```bash
# Verificar checksums
make verify

# Ver información
make show-info

# Extraer y revisar
make extract
cd bundle-inspect/k8s-complete-*
ls -la
```

### Test en Docker

```bash
# Test de extracción
make test-install

# Test completo (requiere privilegios)
docker run --rm --privileged \
  -v $PWD/k8s-bundle-output:/bundle:ro \
  ubuntu:22.04 bash -c "
    cd /tmp &&
    tar -xzf /bundle/k8s-complete-*.tar.gz &&
    cd k8s-complete-* &&
    ./install-k8s.sh
"
```

### Test en VM

```bash
# Crear VM de prueba
multipass launch --name k8s-test --cpus 2 --memory 4G --disk 20G 22.04

# Copiar bundle
multipass transfer k8s-bundle-output/k8s-complete-*.tar.gz k8s-test:/tmp/

# Instalar
multipass exec k8s-test -- bash -c "
  cd /tmp &&
  tar -xzf k8s-complete-*.tar.gz &&
  cd k8s-complete-* &&
  sudo ./install-k8s.sh
"

# Verificar
multipass exec k8s-test -- kubectl version --client
multipass exec k8s-test -- lsmod | grep ip_vs

# Limpiar
multipass delete k8s-test && multipass purge
```

## 📋 Comandos Make

```bash
make help              # Ver todos los comandos
make build             # Build con version por defecto (1.30.2)
make build-1.30        # Build K8s 1.30.2
make build-1.29        # Build K8s 1.29.6
make build-1.28        # Build K8s 1.28.11
make build-all         # Build todas las versiones
make verify            # Verificar bundle
make show-info         # Mostrar información
make list-versions     # Listar versiones disponibles
make show-matrix       # Mostrar matriz de versiones
make extract           # Extraer bundle
make test-install      # Test en Docker
make clean             # Limpiar archivos generados
make check-prereqs     # Verificar prerequisitos
```

## 🗺️ Roadmap

- [ ] Soporte para K8s 1.31+
- [ ] Pre-download de imágenes de contenedores
- [ ] Soporte para etcd externo
- [ ] Helm charts incluidos
- [ ] Monitoring stack (Prometheus/Grafana)
- [ ] Logging stack (ELK/Loki)
- [ ] Storage classes (Rook/Ceph)
- [ ] Ingress controllers (nginx/traefik)
- [ ] Service mesh (Istio/Linkerd)

## 🆘 Troubleshooting

### Error: "Version X.Y.Z not found"

La versión solicitada no está en `k8s-versions.yaml`. Versiones disponibles:

```bash
make list-versions
```

### Error: "Failed to download packages"

```bash
# Actualizar repositorios
sudo apt update

# Verificar conexión
ping -c 3 dl.k8s.io
```

### Bundle muy grande

El tamaño es normal (~500-700 MB) porque incluye:
- Binarios de K8s (~180 MB)
- Containerd (~40 MB)
- CNI (~50 MB)
- System packages con dependencias (~200-300 MB)

Para reducir:
```bash
# Sin CNI
CNI_PROVIDER=none ./create-k8s-bundle.sh

# Sin imágenes
DOWNLOAD_IMAGES=no ./create-k8s-bundle.sh
```

### Instalación falla en kernel modules

Algunos módulos pueden no estar disponibles en el kernel actual. Esto es normal, los módulos críticos (overlay, br_netfilter) deben cargarse.

```bash
# Verificar módulos críticos
lsmod | grep -E 'overlay|br_netfilter'

# Si faltan, cargar manualmente
sudo modprobe overlay
sudo modprobe br_netfilter
```

## 📚 Referencias

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubeadm Installation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Containerd](https://github.com/containerd/containerd)
- [CNI Plugins](https://github.com/containernetworking/plugins)
- [Calico](https://docs.tigera.io/calico/latest/about)
- [Flannel](https://github.com/flannel-io/flannel)

---

**¡Todo listo para instalar Kubernetes offline!** 🚀

Para empezar:
```bash
./create-k8s-bundle.sh
```
