# Script Templates

Este directorio contiene templates Jinja2 para scripts auxiliares de configuración.

## Templates Disponibles

### load-kernel-modules.sh.j2
Script que carga los módulos de kernel requeridos por Kubernetes.

**Qué hace:**
- Copia k8s-modules.conf a /etc/modules-load.d/
- Carga inmediatamente los módulos con modprobe
- Asegura que se carguen en cada boot

**Módulos cargados:**
- overlay (OverlayFS para contenedores)
- br_netfilter (Bridge netfilter para iptables)
- ip_vs, ip_vs_rr, ip_vs_wrr, ip_vs_sh (IPVS load balancing)
- nf_conntrack (Connection tracking)
- nvme_tcp (NVMe over TCP para storage)

**Variables disponibles:**
- Actualmente ninguna (script estático)

**Personalización:**
No suele requerir modificaciones. Los módulos se definen en k8s-versions.yaml.

### apply-sysctl.sh.j2
Script que aplica configuraciones de sysctl para Kubernetes.

**Qué hace:**
- Copia k8s-sysctl.conf a /etc/sysctl.d/99-k8s.conf
- Aplica configuraciones con `sysctl --system`
- Verifica configuraciones clave

**Configuraciones aplicadas:**
- net.ipv4.ip_forward = 1 (IP forwarding)
- net.bridge.bridge-nf-call-iptables = 1 (Bridge netfilter)
- vm.swappiness = 0 (Minimizar uso de swap)
- fs.inotify.max_user_watches = 524288 (Inotify limits)
- Y más...

**Variables disponibles:**
- Actualmente ninguna (script estático)

**Personalización:**
No suele requerir modificaciones. Los settings se definen en k8s-versions.yaml.

## Cuándo Modificar Estos Templates

**Casos de uso para modificación:**

1. **Agregar logging adicional:**
   ```bash
   info "Loaded module: $module - $(modinfo $module | grep description || echo 'N/A')"
   ```

2. **Cambiar comportamiento de errores:**
   ```bash
   # En lugar de warning, fallar en error
   modprobe "$module" || error "Failed to load critical module: $module"
   ```

3. **Agregar verificaciones post-instalación:**
   ```bash
   # Verificar que módulo se cargó correctamente
   if ! lsmod | grep -q "^${module}"; then
       error "Module $module failed to load"
   fi
   ```

## Nota Importante

Los archivos k8s-modules.conf y k8s-sysctl.conf NO son templates.
Se generan directamente desde k8s-versions.yaml en el script create-k8s-bundle.sh.

Para modificar qué módulos o sysctl settings se incluyen:
1. Editar k8s-versions.yaml
2. NO editar estos templates de scripts

Los templates de scripts solo controlan CÓMO se instalan, no QUÉ se instala.

## Testing de Cambios

Después de modificar un template:

```bash
# Rebuild el bundle
make clean
make build

# Extraer y verificar el script generado
make extract
cat bundle-inspect/*/scripts/load-kernel-modules.sh

# Test en ambiente seguro
# NO ejecutar en producción sin validar primero
```
