# Guía de Uso - K8S Offline Bundle para ISOs Custom

## Resumen

Este conjunto de scripts te permite crear un bundle completo con todos los paquetes y configuraciones necesarias para preparar una ISO custom de Ubuntu Server para Kubernetes, todo en modo offline.

## Archivos Incluidos

1. **`download-apt.sh`** - Descarga paquetes APT con dependencias
2. **`download-pip.sh`** - Descarga paquetes Python con dependencias
3. **`prepare-k8s-bundle.sh`** - Script principal que crea el bundle
4. **`cubic-install-bundle.sh`** - Script para instalar el bundle en Cubic

## Flujo de Trabajo

```
┌─────────────────────────────────────────────────────────────┐
│  PASO 1: Preparación (Sistema con Internet)                │
│  ./prepare-k8s-bundle.sh                                    │
│  ↓                                                           │
│  Genera: k8s-offline-bundle-1.0.0.tar.gz                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PASO 2: Integración en Cubic                              │
│  1. Abrir Cubic                                            │
│  2. Copiar el tar.gz a la ISO base                         │
│  3. En chroot: ejecutar cubic-install-bundle.sh            │
│  4. Generar ISO final                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## PASO 1: Crear el Bundle Offline

### Requisitos Previos

- Sistema Ubuntu/Debian con acceso a internet
- Scripts `download-apt.sh` y `download-pip.sh` en el mismo directorio
- Permisos sudo para instalar dependencias si es necesario

### Ejecución

```bash
cd /home/hector/Documents/k8s-isos
./prepare-k8s-bundle.sh
```

### Salida Esperada

El script generará:

```
bundle-output/
├── k8s-offline-bundle-1.0.0.tar.gz       # Bundle principal
├── k8s-offline-bundle-1.0.0.tar.gz.sha256 # Checksum SHA256
├── k8s-offline-bundle-1.0.0.tar.gz.md5    # Checksum MD5
└── bundle-preparation.log                 # Log detallado
```

### Contenido del Bundle

```
k8s-offline-bundle/
├── install.sh                 # Script maestro de instalación
├── README.md                 # Documentación completa
├── packages/
│   ├── apt/                 # ~23 paquetes .deb con dependencias
│   └── pip/                 # Paquetes Python (jc + deps)
├── scripts/
│   ├── install-apt.sh       # Instalador de paquetes APT
│   ├── install-pip.sh       # Instalador de paquetes PIP
│   ├── load-kernel-modules.sh  # Carga módulos del kernel
│   ├── apply-sysctl.sh      # Aplica configuración sysctl
│   └── verify-apt.sh        # Verificación de paquetes
└── config/
    ├── k8s-modules.conf     # Lista de módulos del kernel
    └── k8s-sysctl.conf      # Configuración sysctl para K8S
```

### Paquetes Incluidos

**APT (23 paquetes principales + dependencias):**
- cron, dmidecode, ebtables, ethtool, ipmitool
- iputils-ping, ipvsadm, iptables, jq, lsof
- multipath-tools, network-manager, nfs-common
- nftables, open-iscsi, python3-pip, rsyslog
- s3cmd, sysstat, tcpdump, ufw, vim, lldpd

**PIP:**
- jc (JSON CLI output parser)

**Módulos del Kernel:**
- ip_vs, ip_vs_rr, ip_vs_wrr, ip_vs_sh, ip_vs_wlc, ip_vs_lc
- nf_conntrack, nvme_tcp

---

## PASO 2: Integrar en Cubic

### Opción A: Instalación Automática (Recomendada)

1. **Abrir Cubic y cargar tu ISO base:**
   ```bash
   cubic
   # Seleccionar ISO de Ubuntu Server
   # Esperar a que abra el terminal chroot
   ```

2. **Copiar archivos al proyecto Cubic:**

   En una terminal FUERA del chroot:
   ```bash
   # Copiar bundle al directorio del proyecto Cubic
   # El directorio típicamente está en ~/Cubic/<nombre-proyecto>/

   cp bundle-output/k8s-offline-bundle-1.0.0.tar.gz \
      ~/Cubic/<tu-proyecto>/custom-root/opt/

   cp cubic-install-bundle.sh \
      ~/Cubic/<tu-proyecto>/custom-root/opt/
   ```

3. **Ejecutar instalación en el chroot de Cubic:**

   Dentro del terminal chroot de Cubic:
   ```bash
   cd /opt
   chmod +x cubic-install-bundle.sh
   ./cubic-install-bundle.sh
   ```

   El script automáticamente:
   - Encuentra el bundle
   - Verifica integridad (SHA256)
   - Extrae el contenido
   - Ejecuta la instalación completa
   - Limpia archivos temporales

### Opción B: Instalación Manual

Si prefieres más control:

1. **En el chroot de Cubic:**
   ```bash
   cd /opt
   tar -xzf k8s-offline-bundle-1.0.0.tar.gz
   cd k8s-offline-bundle

   # Revisar el README
   cat README.md

   # Ejecutar instalación
   ./install.sh
   ```

2. **Limpiar (opcional):**
   ```bash
   cd /opt
   rm -rf k8s-offline-bundle
   rm k8s-offline-bundle-1.0.0.tar.gz
   ```

### Opción C: Instalación en Primera Ejecución

Para instalar el bundle en el primer boot de la ISO:

1. **Copiar bundle a la ISO:**
   ```bash
   cp k8s-offline-bundle-1.0.0.tar.gz \
      ~/Cubic/<proyecto>/custom-root/opt/
   ```

2. **Crear script de firstboot:**

   En el chroot de Cubic, crear `/usr/local/bin/k8s-firstboot.sh`:
   ```bash
   #!/bin/bash

   BUNDLE="/opt/k8s-offline-bundle-1.0.0.tar.gz"
   MARKER="/var/lib/k8s-bundle-installed"

   if [[ -f "$BUNDLE" ]] && [[ ! -f "$MARKER" ]]; then
       cd /opt
       tar -xzf "$BUNDLE"
       cd k8s-offline-bundle
       ./install.sh
       touch "$MARKER"
       rm -rf /opt/k8s-offline-bundle "$BUNDLE"
   fi
   ```

3. **Crear servicio systemd:**

   Crear `/etc/systemd/system/k8s-firstboot.service`:
   ```ini
   [Unit]
   Description=K8S Bundle First Boot Installation
   After=network.target
   Before=kubelet.service
   ConditionPathExists=!/var/lib/k8s-bundle-installed

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/k8s-firstboot.sh
   RemainAfterExit=yes

   [Install]
   WantedBy=multi-user.target
   ```

4. **Habilitar servicio:**
   ```bash
   chmod +x /usr/local/bin/k8s-firstboot.sh
   systemctl enable k8s-firstboot.service
   ```

---

## Verificación Post-Instalación

### Dentro del Chroot de Cubic

```bash
# 1. Verificar paquetes APT instalados
dpkg -l | grep -E 'jq|ipvsadm|iptables|vim'

# 2. Verificar paquetes PIP
pip3 list | grep jc

# 3. Verificar módulos del kernel configurados
cat /etc/modules-load.d/k8s-modules.conf

# 4. Verificar configuración sysctl
cat /etc/sysctl.d/99-k8s.conf

# 5. Verificar swap deshabilitado
cat /etc/fstab | grep swap  # Debe estar comentado
```

### En el Sistema Booteado desde la ISO

```bash
# 1. Módulos del kernel cargados
lsmod | grep -E 'ip_vs|nf_conntrack|nvme_tcp'

# 2. Configuración sysctl aplicada
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables

# 3. Swap deshabilitado
swapon --show  # No debe mostrar nada
free -h        # Swap debe ser 0

# 4. Servicios activos
systemctl status systemd-modules-load
systemctl status cron
systemctl status rsyslog
```

---

## Personalización

### Agregar más paquetes APT

Editar `prepare-k8s-bundle.sh`:

```bash
APT_PACKAGES=(
    "cron"
    "dmidecode"
    # ... paquetes existentes ...
    "tu-paquete-adicional"  # Agregar aquí
)
```

### Agregar más paquetes PIP

```bash
PIP_PACKAGES=(
    "jc"
    "tu-paquete-python"  # Agregar aquí
)
```

### Agregar más módulos del kernel

```bash
KERNEL_MODULES=(
    "ip_vs"
    # ... módulos existentes ...
    "tu_modulo"  # Agregar aquí
)
```

### Modificar configuración sysctl

Editar la función `create_sysctl_config()` en `prepare-k8s-bundle.sh`:

```bash
cat > "$sysctl_conf" << 'EOF'
# ... configuración existente ...

# Tu configuración personalizada
net.ipv4.tcp_keepalive_time = 600
EOF
```

---

## Solución de Problemas

### Error: "download-apt.sh not found"

**Solución:** Asegúrate de que todos los scripts estén en el mismo directorio:
```bash
ls -la /home/hector/Documents/k8s-isos/
# Debe mostrar: download-apt.sh, download-pip.sh, prepare-k8s-bundle.sh
```

### Error: "Failed to download APT packages"

**Causas posibles:**
1. Sin conexión a internet
2. Repositorios no actualizados
3. Versiones específicas no disponibles

**Solución:**
```bash
# Actualizar repositorios
sudo apt update

# Verificar disponibilidad de paquete
apt-cache policy ipvsadm

# Probar descarga manual
./download-apt.sh ipvsadm
```

### Error: "Module not found" al cargar módulos

**Causa:** El kernel en el chroot puede no tener todos los módulos

**Solución:** Los módulos se cargarán cuando se bootee desde la ISO final, no en el chroot

### Bundle muy grande

**Solución:** Remover paquetes innecesarios o usar `--no-deps` en download scripts

```bash
# Ver tamaño del bundle
du -sh bundle-output/k8s-offline-bundle-1.0.0.tar.gz

# Analizar contenido
tar -tzf k8s-offline-bundle-1.0.0.tar.gz | head -20
```

---

## Flujo Completo de Ejemplo

```bash
# ===== EN SISTEMA CON INTERNET =====

# 1. Preparar bundle
cd /home/hector/Documents/k8s-isos
./prepare-k8s-bundle.sh

# 2. Verificar salida
ls -lh bundle-output/
sha256sum -c bundle-output/k8s-offline-bundle-1.0.0.tar.gz.sha256

# ===== EN CUBIC =====

# 3. Iniciar Cubic con tu ISO base
cubic

# 4. En otra terminal, copiar archivos
cp bundle-output/k8s-offline-bundle-1.0.0.tar.gz \
   ~/Cubic/mi-k8s-iso/custom-root/opt/

cp cubic-install-bundle.sh \
   ~/Cubic/mi-k8s-iso/custom-root/opt/

# 5. En el terminal chroot de Cubic
cd /opt
./cubic-install-bundle.sh

# 6. Verificar instalación
dpkg -l | grep jq
cat /etc/modules-load.d/k8s-modules.conf

# 7. En Cubic: Generar ISO final
# (Usar la interfaz gráfica de Cubic)

# ===== BOOTEAR Y PROBAR =====

# 8. Bootear desde la ISO generada
# 9. Verificar configuración
lsmod | grep ip_vs
sysctl net.ipv4.ip_forward
pip3 list | grep jc
```

---

## Mejores Prácticas

1. **Siempre verificar checksums:**
   ```bash
   sha256sum -c k8s-offline-bundle-1.0.0.tar.gz.sha256
   ```

2. **Mantener logs:**
   ```bash
   cp bundle-output/bundle-preparation.log ./bundle-logs-$(date +%Y%m%d).log
   ```

3. **Versionar bundles:**
   ```bash
   # Modificar BUNDLE_VERSION en prepare-k8s-bundle.sh
   BUNDLE_VERSION="1.1.0"
   ```

4. **Probar en VM antes de ISO final:**
   - Crear VM con Ubuntu Server
   - Instalar bundle manualmente
   - Verificar todo funciona
   - Luego integrar en ISO

5. **Documentar personalizaciones:**
   - Mantener lista de paquetes agregados
   - Documentar cambios en sysctl
   - Versionar cambios en Git

---

## Siguientes Pasos Después de la ISO

Una vez que tengas tu ISO con el bundle instalado:

1. **Instalar Container Runtime:**
   ```bash
   # containerd
   apt install containerd

   # O crear otro bundle para containerd
   ```

2. **Instalar Kubernetes:**
   ```bash
   # kubeadm, kubelet, kubectl
   # Idealmente en otro bundle offline
   ```

3. **Inicializar Cluster:**
   ```bash
   kubeadm init --pod-network-cidr=10.244.0.0/16
   ```

4. **Instalar CNI:**
   ```bash
   kubectl apply -f calico.yaml
   # O Flannel, Cilium, etc.
   ```

---

## Soporte y Contribuciones

- **Logs:** Revisar `bundle-output/bundle-preparation.log`
- **Issues:** Documentar errores con logs completos
- **Mejoras:** Modificar scripts según necesidades

---

## Compatibilidad Probada

- ✅ Ubuntu Server 20.04 LTS
- ✅ Ubuntu Server 22.04 LTS
- ✅ Ubuntu Server 24.04 LTS
- ✅ Kubernetes 1.28+
- ✅ Arquitectura: amd64

---

**Última actualización:** 2026-01-07
**Versión de la guía:** 1.0.0
