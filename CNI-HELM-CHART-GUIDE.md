# CNI Configuration for Helm Chart Deployments

## 🎯 TL;DR - Para tu caso con Calico via Helm Chart

Si instalas Calico como Helm chart, usa esto:

```bash
# Crear bundle SIN manifests de CNI (pero CON CNI plugins base)
CNI_PROVIDER=none make build
```

Esto te dará:
- ✅ CNI plugins base (bridge, loopback, etc.) - NECESARIOS
- ❌ calico.yaml manifest - NO NECESARIO (tienes Helm chart)

## 📚 Entendiendo CNI: Plugins vs Network Solutions

### 1️⃣ CNI Plugins Base (SIEMPRE Necesarios)

**¿Qué son?**
- Binarios básicos de red: `bridge`, `host-local`, `loopback`, `portmap`, etc.
- Requeridos por containerd para operaciones básicas de red
- Ubicación: `/opt/cni/bin/`

**¿Por qué son necesarios?**
```yaml
# containerd config requiere estos plugins
[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/opt/cni/bin"    # <- Busca los CNI plugins aquí
  conf_dir = "/etc/cni/net.d"
```

**Archivo descargado:**
- `cni-plugins-linux-amd64-v1.5.0.tgz` (~39 MB)
- Contiene: bridge, dhcp, host-device, host-local, ipvlan, loopback, macvlan, portmap, etc.

**Estado en el bundle:**
- ✅ SIEMPRE incluido (no se puede omitir)
- Instalado por `install-k8s.sh` a `/opt/cni/bin/`

### 2️⃣ CNI Network Solutions (Calico, Flannel, etc.)

**¿Qué son?**
- Soluciones de red completas para Kubernetes
- Proveen: networking pod-to-pod, network policies, IP management, etc.
- Ejemplos: Calico, Flannel, Cilium, Weave

**Métodos de instalación:**

#### Opción A: Manifest YAML (lo que hace el bundle por defecto)
```bash
# Bundle descarga calico.yaml
CNI_PROVIDER=calico make build

# En el cluster
kubectl apply -f calico.yaml
```

#### Opción B: Helm Chart (TU CASO)
```bash
# Bundle NO descarga manifest
CNI_PROVIDER=none make build

# En el cluster (después de join)
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm install calico projectcalico/tigera-operator
```

## 🔧 Opciones de Build para CNI

### Opción 1: Sin Manifests de CNI (Recomendado para Helm)

```bash
CNI_PROVIDER=none make build
```

**Resultado:**
```
k8s-complete-1.30.2-ubuntu22.04-amd64/
├── binaries/
│   ├── cni/
│   │   └── cni-plugins-linux-amd64-v1.5.0.tgz  ✅ CNI plugins base
│   │   # NO incluye calico.yaml ❌
```

**Usar cuando:**
- ✅ Instalas CNI via Helm (Calico, Cilium, etc.)
- ✅ Instalas CNI via Operator
- ✅ El cluster master ya tiene CNI configurado
- ✅ Usas registry privado para imágenes de CNI

### Opción 2: Con Manifest de Calico (Default)

```bash
CNI_PROVIDER=calico make build
# O simplemente
make build
```

**Resultado:**
```
k8s-complete-1.30.2-ubuntu22.04-amd64/
├── binaries/
│   ├── cni/
│   │   ├── cni-plugins-linux-amd64-v1.5.0.tgz  ✅
│   │   └── calico.yaml                         ✅ Manifest
```

**Usar cuando:**
- Instalas Calico con `kubectl apply -f calico.yaml`
- Necesitas instalación offline completa sin Helm
- Es un cluster nuevo sin CNI configurado

### Opción 3: Con Manifest de Flannel

```bash
CNI_PROVIDER=flannel make build
```

**Resultado:**
```
├── binaries/
│   ├── cni/
│   │   ├── cni-plugins-linux-amd64-v1.5.0.tgz  ✅
│   │   └── flannel.yaml                        ✅ Manifest
```

## 🚀 Flujo Completo: Worker + Calico Helm Chart

### 1. Crear Bundle (Máquina con Internet)

```bash
# Sin manifest de Calico (porque usarás Helm)
CNI_PROVIDER=none make build
```

### 2. Transferir a Máquina Offline

```bash
scp k8s-bundle-output/k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz \
    user@worker-node:/tmp/
```

### 3. Instalar en Worker (Sin Internet)

```bash
# En el worker node
cd /tmp
tar -xzf k8s-complete-1.30.2-ubuntu22.04-amd64.tar.gz
cd k8s-complete-1.30.2-ubuntu22.04-amd64
sudo ./install-k8s.sh
```

**Esto instala:**
- ✅ kubeadm, kubelet, kubectl, crictl
- ✅ containerd + runc + ctr
- ✅ CNI plugins base en `/opt/cni/bin/`
- ✅ Kernel modules, sysctl settings
- ✅ Systemd services

### 4. Unir al Cluster (Con Ansible)

```bash
# Ejecutar tu playbook
ansible-playbook -i inventory worker-join-playbook.yml
```

**El playbook ejecuta:**
```bash
kubeadm join <master>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

### 5. Instalar Calico via Helm (Desde Master o Bastion)

```bash
# Desde una máquina con acceso al cluster
# Opción A: Helm chart público
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm install calico projectcalico/tigera-operator \
  --namespace tigera-operator \
  --create-namespace

# Opción B: Desde registry privado
helm install calico oci://your-registry/tigera-operator \
  --namespace tigera-operator \
  --create-namespace
```

### 6. Verificar

```bash
# Verificar que el worker tiene CNI funcionando
kubectl get nodes
# Debería mostrar Ready

kubectl get pods -n calico-system
# Debería mostrar calico pods running

# En el worker, verificar CNI plugins
ls /opt/cni/bin/
# bridge  dhcp  host-device  host-local  ipvlan  loopback  ...

# Verificar configuración CNI de Calico
ls /etc/cni/net.d/
# 10-calico.conflist (creado por Calico Helm chart)
```

## 📊 Comparación: Manifest vs Helm Chart

| Característica | Manifest (calico.yaml) | Helm Chart |
|----------------|------------------------|------------|
| **Método** | `kubectl apply -f` | `helm install` |
| **Upgrades** | Manual con nuevos YAML | `helm upgrade` |
| **Configuración** | Editar YAML | values.yaml |
| **Rollback** | Manual | `helm rollback` |
| **Bundle needs** | Incluir calico.yaml | NO incluir manifest |
| **Complejidad** | Baja | Media |
| **Flexibilidad** | Baja | Alta |
| **Uso típico** | Clusters simples | Producción |

## ⚠️ Puntos Importantes

### 1. CNI Plugins Base SIEMPRE Necesarios

```bash
# ❌ INCORRECTO - No intentes omitir CNI plugins base
DOWNLOAD_CNI=no make build  # ¡Esto causa errores!

# ✅ CORRECTO - CNI plugins base siempre incluidos, omitir manifest
CNI_PROVIDER=none make build
```

### 2. Orden de Instalación

```
1. ✅ Instalar bundle en worker (incluye CNI plugins base)
2. ✅ kubeadm join (el nodo se une pero pods no networking)
3. ✅ Instalar Calico via Helm (desde master)
4. ✅ Pods en el worker obtienen IPs y networking funciona
```

### 3. El Worker NO Necesita Helm

- Helm se ejecuta desde el master o bastion
- El worker solo necesita:
  - kubelet running
  - containerd running
  - CNI plugins base en `/opt/cni/bin/`

### 4. Calico via Helm Crea su Config

Calico Helm chart automáticamente:
- ✅ Crea `/etc/cni/net.d/10-calico.conflist`
- ✅ Descarga imágenes de Calico
- ✅ Despliega calico-node DaemonSet
- ✅ Configura networking en todos los workers

## 🔍 Troubleshooting

### Problema: Pods stuck en ContainerCreating

```bash
kubectl describe pod <pod-name>
# Error: failed to find plugin "calico" in path [/opt/cni/bin]
```

**Causa:** CNI plugins base no instalados o Calico no desplegado

**Solución:**
```bash
# En el worker, verificar CNI plugins
ls /opt/cni/bin/

# En el master, verificar Calico
kubectl get pods -n calico-system
helm list -n tigera-operator
```

### Problema: Worker NotReady

```bash
kubectl get nodes
# worker-1   NotReady   <none>   5m
```

**Causa:** CNI no configurado

**Solución:**
```bash
# Verificar logs de kubelet en el worker
journalctl -u kubelet -f

# Instalar Calico via Helm desde master
helm install calico projectcalico/tigera-operator
```

### Problema: Network policies no funcionan

**Causa:** Calico no instalado o mal configurado

**Solución:**
```bash
# Verificar Felix (Calico policy engine)
kubectl get pods -n calico-system | grep calico-node

# Verificar que calico-node está en tu worker
kubectl get pods -n calico-system -o wide | grep worker-1
```

## 📝 Resumen para tu Caso

### Lo que NECESITAS:

```bash
# Build
CNI_PROVIDER=none make build

# Resultado
✅ CNI plugins base (bridge, loopback, etc.)
✅ kubeadm, kubelet, kubectl, crictl
✅ containerd + runc
❌ NO incluye calico.yaml (porque usas Helm)
```

### Lo que NO NECESITAS en el Bundle:

- ❌ calico.yaml manifest
- ❌ flannel.yaml manifest
- ❌ Imágenes pre-descargadas de Calico

### Tu Flujo:

1. Build bundle: `CNI_PROVIDER=none make build`
2. Deploy bundle en workers
3. Run Ansible playbook → `kubeadm join`
4. Install Calico via Helm (desde master)
5. Workers ready con networking funcional ✅

---

**Conclusión:** Para tu caso con Calico via Helm chart, usa `CNI_PROVIDER=none` al crear el bundle. Los CNI plugins base SIEMPRE se incluyen automáticamente porque son requeridos por containerd.
