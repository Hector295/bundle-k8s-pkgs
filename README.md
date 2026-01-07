# K8S Offline Bundle Creator

> **Sistema completo para crear ISOs custom de Ubuntu Server optimizadas para Kubernetes con instalación offline**

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-orange?logo=ubuntu)](https://ubuntu.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes)](https://kubernetes.io)
[![Bash](https://img.shields.io/badge/Bash-5.0+-4EAA25?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 📋 Descripción

Este proyecto proporciona un conjunto de scripts bash robustos y bien documentados para:

1. **Descargar** paquetes APT y PIP con todas sus dependencias (modo offline)
2. **Empaquetar** todo en un bundle tar.gz autocontenido
3. **Integrar** el bundle en ISOs custom usando Cubic
4. **Preparar** sistemas Ubuntu Server para Kubernetes sin internet

## 🎯 Características

- ✅ **100% Offline**: Todo funciona sin conexión a internet después de crear el bundle
- ✅ **Idempotente**: Seguro ejecutar múltiples veces
- ✅ **Verificaciones**: Checksums SHA256 y MD5 automáticos
- ✅ **Modular**: Fácil agregar/quitar paquetes
- ✅ **Logging**: Logs detallados de todas las operaciones
- ✅ **Colores**: Output colorizado para mejor legibilidad
- ✅ **Documentado**: Guías completas y comentarios en código

## 🚀 Inicio Rápido

### Prerrequisitos

```bash
# Sistema Ubuntu/Debian con internet
sudo apt update
sudo apt install -y tar gzip wget curl apt-transport-https python3-pip

# Clonar/copiar este proyecto
cd /home/hector/Documents/k8s-isos
```

### Crear Bundle (3 comandos)

```bash
# 1. Crear el bundle
make build

# 2. Verificar integridad
make verify

# 3. Ver información
make show-info
```

### Usar con Cubic

```bash
# 1. Copiar a Cubic
CUBIC_PROJECT=~/Cubic/mi-proyecto make install-cubic

# 2. En el chroot de Cubic
cd /opt
./cubic-install-bundle.sh
```

¡Listo! Tu ISO ahora incluye todo lo necesario para K8S.

## 📦 Contenido del Bundle

### Paquetes APT (23+)
- **Networking**: network-manager, iputils-ping, tcpdump, lldpd
- **Storage**: multipath-tools, open-iscsi, nfs-common
- **Security**: iptables, nftables, ebtables, ufw
- **Kubernetes**: ipvsadm (IPVS mode), ethtool, ipmitool
- **Utilities**: jq, vim, cron, rsyslog, sysstat, s3cmd, dmidecode, lsof

### Paquetes PIP
- **jc**: JSON parser para CLI output (útil para scripts de automatización)

### Configuraciones
- **Módulos Kernel**: ip_vs, nf_conntrack, nvme_tcp (8 módulos)
- **Sysctl**: IP forwarding, bridge netfilter, connection tracking
- **Sistema**: Swap deshabilitado, file watchers aumentados

## 📁 Estructura del Proyecto

```
k8s-isos/
├── README.md                      # Este archivo
├── GUIA-USO.md                   # Guía detallada en español
├── Makefile                      # Comandos simplificados
│
├── download-apt.sh               # Descargador de paquetes APT
├── download-pip.sh               # Descargador de paquetes PIP
├── prepare-k8s-bundle.sh        # Script principal (crea bundle)
├── cubic-install-bundle.sh      # Instalador para Cubic
├── verify-bundle.sh             # Verificador de bundle
│
└── bundle-output/               # Generado tras 'make build'
    ├── k8s-offline-bundle-1.0.0.tar.gz
    ├── k8s-offline-bundle-1.0.0.tar.gz.sha256
    ├── k8s-offline-bundle-1.0.0.tar.gz.md5
    └── bundle-preparation.log
```

### Dentro del Bundle

```
k8s-offline-bundle/
├── install.sh                    # Instalador maestro
├── README.md                    # Documentación del bundle
├── packages/
│   ├── apt/                     # ~100+ archivos .deb
│   └── pip/                     # Wheels de Python
├── scripts/
│   ├── install-apt.sh           # Instala paquetes APT
│   ├── install-pip.sh           # Instala paquetes PIP
│   ├── load-kernel-modules.sh  # Carga módulos
│   ├── apply-sysctl.sh         # Aplica sysctl
│   └── verify-apt.sh           # Verifica paquetes
└── config/
    ├── k8s-modules.conf         # Lista de módulos
    └── k8s-sysctl.conf          # Configuración sysctl
```

## 🛠️ Comandos Make

```bash
make help           # Mostrar todos los comandos
make build          # Crear bundle
make verify         # Verificar bundle
make clean          # Limpiar archivos generados
make all            # build + verify
make show-info      # Info del bundle
make checksums      # Verificar checksums
make test-vm        # Probar en VM (requiere multipass)
make rebuild        # clean + build + verify
make extract        # Extraer bundle para inspeccionar
```

## 📖 Documentación

- **[GUIA-USO.md](GUIA-USO.md)** - Guía completa en español (paso a paso)
- **[Scripts individuales]** - Todos tienen `--help` integrado

## 🔍 Ejemplos de Uso

### Escenario 1: Crear ISO para Datacenter Offline

```bash
# En máquina con internet
cd /home/hector/Documents/k8s-isos
make build
make verify

# Copiar bundle-output/k8s-offline-bundle-1.0.0.tar.gz a USB

# En datacenter (sin internet)
# Usar Cubic con la ISO base + el bundle
CUBIC_PROJECT=/path/to/cubic/project make install-cubic
```

### Escenario 2: Probar Bundle Antes de ISO

```bash
# Crear y probar en VM local
make build
make test-vm

# Verificar en VM
multipass shell k8s-bundle-test
lsmod | grep ip_vs
sysctl net.ipv4.ip_forward

# Limpiar
multipass delete k8s-bundle-test && multipass purge
```

### Escenario 3: Personalizar Paquetes

```bash
# Editar prepare-k8s-bundle.sh
nano prepare-k8s-bundle.sh

# Agregar en APT_PACKAGES
APT_PACKAGES=(
    ...
    "htop"           # Agregar nuevo
    "iotop"          # Agregar nuevo
)

# Reconstruir
make rebuild
```

### Escenario 4: Solo Descargar Paquetes (Sin Bundle)

```bash
# APT
./download-apt.sh vim git curl
# Resultado: offline_dpkg_packages/*.deb

# PIP
./download-pip.sh requests flask
# Resultado: offline_pip_packages/*.whl
```

## 🧪 Testing

### Test Local (Sintaxis y Scripts)
```bash
make test-local
```

### Test en VM (Funcionalidad Completa)
```bash
# Requiere multipass instalado
sudo snap install multipass
make test-vm
```

### Test Manual en Sistema Real
```bash
# Extraer bundle
make extract
cd bundle-inspect/k8s-offline-bundle

# Instalar
sudo ./install.sh

# Verificar
lsmod | grep -E 'ip_vs|nf_conntrack'
sysctl net.ipv4.ip_forward
dpkg -l | grep jq
pip3 list | grep jc
```

## 🔧 Integración con Cubic

### Método 1: Automático (Recomendado)

```bash
CUBIC_PROJECT=~/Cubic/mi-k8s-iso make install-cubic

# En Cubic chroot
cd /opt && ./cubic-install-bundle.sh
```

### Método 2: Manual

```bash
# 1. Copiar bundle a Cubic
cp bundle-output/k8s-offline-bundle-1.0.0.tar.gz \
   ~/Cubic/mi-proyecto/custom-root/opt/

# 2. En Cubic chroot
cd /opt
tar -xzf k8s-offline-bundle-1.0.0.tar.gz
cd k8s-offline-bundle
./install.sh
```

### Método 3: First Boot (Instalación en primer inicio)

Ver **GUIA-USO.md** sección "Opción C: Instalación en Primera Ejecución"

## 🐛 Troubleshooting

### Error: "download-apt.sh not found"
```bash
# Verificar archivos
ls -la *.sh
# Deben estar todos en el mismo directorio
```

### Error: "Failed to download APT packages"
```bash
# Actualizar repos
make update-cache
# O manualmente
sudo apt update
```

### Bundle muy grande
```bash
# Ver qué ocupa espacio
make extract
cd bundle-inspect/k8s-offline-bundle
du -sh packages/*

# Opción: Usar --no-deps (más riesgoso)
# Editar download-apt.sh para incluir --no-deps
```

### Módulos no cargan en chroot
**Esto es normal**. Los módulos se cargarán cuando se bootee desde la ISO final, no en el entorno chroot de Cubic.

## 📊 Tamaño Esperado

- **Bundle completo**: ~150-300 MB (depende de arquitectura y dependencias)
- **Paquetes APT**: ~100-200 MB
- **Paquetes PIP**: ~5-10 MB
- **Scripts + configs**: <1 MB

## 🔐 Seguridad

- ✅ Todos los scripts usan `set -e` (exit on error)
- ✅ Validación de input y argumentos
- ✅ Checksums SHA256 y MD5
- ✅ Verificación de integridad de paquetes
- ✅ No ejecuta código de red sin validar

## 🤝 Contribuir

Mejoras bienvenidas:

1. Fork del proyecto
2. Crear branch: `git checkout -b feature/nueva-funcionalidad`
3. Commit: `git commit -am 'Agregar nueva funcionalidad'`
4. Push: `git push origin feature/nueva-funcionalidad`
5. Pull Request

## 📝 Changelog

### v1.0.0 (2026-01-07)
- ✨ Release inicial
- ✅ Scripts de descarga APT y PIP
- ✅ Bundle creator con verificación
- ✅ Integración con Cubic
- ✅ Makefile con comandos útiles
- ✅ Documentación completa

## 🗺️ Roadmap

- [ ] Soporte para Red Hat/CentOS (yum/dnf)
- [ ] Descarga de imágenes Docker/containerd
- [ ] Bundle para containerd + kubeadm completo
- [ ] Script de post-instalación con kubeadm init
- [ ] Soporte para CNI plugins (Calico, Flannel)
- [ ] GUI para seleccionar paquetes
- [ ] Tests automatizados (CI/CD)

## 📜 Licencia

MIT License - Ver archivo LICENSE para detalles

## 👤 Autor

**Hector** - Sistema de bundles offline para Kubernetes

---

## 🎓 Recursos Adicionales

### Kubernetes
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [kubeadm Installation Guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)

### Cubic
- [Cubic GitHub](https://github.com/PJ-Singh-001/Cubic)
- [Cubic Documentation](https://github.com/PJ-Singh-001/Cubic/wiki)

### Ubuntu
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [Ubuntu Package Search](https://packages.ubuntu.com/)

---

## ⚡ Quick Reference Card

```bash
# Crear bundle
make build

# Verificar
make verify

# Ver info
make show-info

# Usar en Cubic
CUBIC_PROJECT=~/Cubic/proyecto make install-cubic

# En Cubic chroot
cd /opt && ./cubic-install-bundle.sh

# Probar en VM
make test-vm

# Limpiar
make clean

# Help
make help
```

---

**¿Preguntas?** Lee **GUIA-USO.md** para documentación detallada.

**¿Problemas?** Revisa `bundle-output/bundle-preparation.log`

**¿Mejoras?** Pull requests bienvenidas 🚀
