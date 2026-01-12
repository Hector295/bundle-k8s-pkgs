# Installation Script Template

Este directorio contiene el template Jinja2 para el script de instalación principal.

## Template Disponible

### install-k8s.sh.j2
Script principal de instalación que se ejecuta en el nodo worker para instalar todos los componentes de Kubernetes.

**Variables disponibles:**
- `k8s_version` - Versión de Kubernetes
- `containerd_version` - Versión de containerd
- `arch` - Arquitectura (amd64/arm64)
- `cni_provider` - Proveedor CNI (calico/flannel/none)
- `version_data` - Acceso completo a k8s-versions.yaml

**Lógica condicional Jinja2:**

El template usa condicionales para adaptar el comportamiento según el CNI provider:

```jinja2
{% if cni_provider != 'none' %}
  # Incluye instrucciones para aplicar manifest CNI
{% else %}
  # Instruye instalar CNI vía Helm
{% endif %}
```

## Fases de Instalación

El script ejecuta 9 pasos:

1. **Installing System Packages** - Paquetes APT del sistema
2. **Installing Python Packages** - Paquetes PIP
3. **Configuring Kernel Modules** - Módulos de kernel (overlay, br_netfilter, etc.)
4. **Applying Sysctl Settings** - Configuraciones de sysctl
5. **Disabling Swap** - Deshabilita swap (requerido por K8s)
6. **Installing Containerd** - Runtime de contenedores + runc
7. **Installing CNI Plugins** - Plugins CNI base + provider (calico/flannel)
8. **Installing Kubernetes Binaries** - kubeadm, kubelet, kubectl, crictl
9. **Loading Container Images** - Información sobre imágenes

Luego ejecuta verificación de la instalación.

## Personalización Común

### 1. Agregar Pasos de Instalación Adicionales

```jinja2
# Después del paso 9, antes de verificación
section "Step 10/10: Installing Custom Tools"

# Tu código de instalación aquí
log "Custom tools installed"
```

### 2. Modificar Pod Network CIDR

```jinja2
echo "     kubeadm init --pod-network-cidr=10.100.0.0/16"  # Custom CIDR
```

### 3. Agregar Validaciones Adicionales

```jinja2
# En la sección de Verification
if command -v helm &>/dev/null; then
    echo "  ✓ helm: installed"
else
    echo "  ✗ helm: not found"
fi
```

### 4. Configurar Proxy para Containerd

```jinja2
# En la sección CONTAINERD, después de mkdir -p /etc/systemd/system
mkdir -p /etc/systemd/system/containerd.service.d
cat > /etc/systemd/system/containerd.service.d/http-proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080"
Environment="HTTPS_PROXY=http://proxy.example.com:8080"
Environment="NO_PROXY=localhost,127.0.0.1,10.0.0.0/8"
EOF
```

### 5. Personalizar según CNI Provider

El template ya incluye lógica para diferentes CNI providers. Para agregar otro:

```jinja2
{% if cni_provider == 'calico' %}
  # Instrucciones específicas de Calico
{% elif cni_provider == 'flannel' %}
  # Instrucciones específicas de Flannel
{% elif cni_provider == 'cilium' %}
  # Agregar nuevo provider
  info "Cilium manifest available..."
{% else %}
  # none o cualquier otro
  info "CNI to be installed separately"
{% endif %}
```

## Variables Avanzadas

Puedes acceder a cualquier valor de k8s-versions.yaml:

```jinja2
{# Ejemplo: mostrar versión específica de componente #}
info "etcd image: {{ version_data.container_images.etcd }}"
info "CoreDNS version: {{ version_data.container_images.coredns }}"
```

## Consideraciones de Seguridad

**Importante:** Este script se ejecuta como root y realiza cambios críticos del sistema.

Cuando modifiques el template:
1. **No** agregues credenciales hardcodeadas
2. **Valida** todos los inputs antes de usarlos
3. **Verifica** que archivos existen antes de copiarlos
4. **Testea** en ambiente no-producción primero

Ejemplo de validación:

```bash
# INCORRECTO - Podría fallar silenciosamente
cp "$FILE" /etc/

# CORRECTO - Valida antes de copiar
if [[ -f "$FILE" ]]; then
    cp "$FILE" /etc/
    log "File copied"
else
    error "File not found: $FILE"
fi
```

## Testing de Cambios

**Nunca** ejecutes el script modificado directamente en producción.

Proceso recomendado:

1. Modificar template
2. Rebuild bundle: `make clean && make build`
3. Extraer: `make extract`
4. Revisar script generado: `cat bundle-inspect/*/install-k8s.sh`
5. Testear en VM/contenedor de prueba
6. Validar que todos los pasos funcionan
7. Aplicar en producción

## Troubleshooting

**Error: "Kubernetes binaries not found"**
- Verifica que el bundle se construyó correctamente
- Asegúrate de extraer el tarball antes de ejecutar

**Error: "containerd not running"**
- Revisa logs: `journalctl -u containerd -n 50`
- Verifica config: `cat /etc/containerd/config.toml`

**Error: "swap still enabled"**
- El script debería deshabilitar swap automáticamente
- Verifica que el paso 5 se ejecutó sin errores
- Manual: `swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab`

## Más Información

Ver también:
- [TEMPLATE-CUSTOMIZATION.md](../../docs/TEMPLATE-CUSTOMIZATION.md) - Guía completa de templates
- k8s-versions.yaml - Configuración de versiones
- README.md principal - Documentación del proyecto
