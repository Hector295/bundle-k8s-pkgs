# Template Customization Guide

Esta guía explica cómo personalizar los templates Jinja2 del proyecto k8s-bundle para adaptarlo a tus necesidades específicas.

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Estructura de Templates](#estructura-de-templates)
3. [Sintaxis Jinja2](#sintaxis-jinja2)
4. [Casos de Uso Comunes](#casos-de-uso-comunes)
5. [Variables Disponibles](#variables-disponibles)
6. [Testing de Cambios](#testing-de-cambios)
7. [Troubleshooting](#troubleshooting)

---

## Introducción

Este proyecto usa templates Jinja2 para generar configuraciones y scripts de instalación. Los templates te permiten personalizar el comportamiento sin modificar código bash directamente.

**Beneficios:**
- Separación entre configuración y lógica
- Fácil mantenimiento y versionado
- Personalización sin tocar código fuente
- Soporte para lógica condicional

**Estructura:**
```
templates/
├── config/          # Configuraciones (containerd, crictl)
├── scripts/         # Scripts auxiliares (módulos, sysctl)
└── install/         # Script de instalación principal
```

---

## Estructura de Templates

### Templates de Configuración

**`templates/config/containerd-config.toml.j2`**
- Configuración de containerd
- Personalizable para registry mirrors, debug, autenticación

**`templates/config/crictl.yaml.j2`**
- Configuración de crictl
- Personalizable para endpoints, timeouts

### Templates de Scripts

**`templates/scripts/load-kernel-modules.sh.j2`**
- Carga módulos de kernel
- Raramente necesita modificación

**`templates/scripts/apply-sysctl.sh.j2`**
- Aplica configuraciones sysctl
- Raramente necesita modificación

### Template de Instalación

**`templates/install/install-k8s.sh.j2`**
- Script principal de instalación
- Usa lógica condicional para CNI providers
- Altamente personalizable

---

## Sintaxis Jinja2

### Variables

```jinja2
{{ variable_name }}
```

**Ejemplo:**
```jinja2
# Kubernetes Version: {{ k8s_version }}
sandbox_image = "{{ pause_image }}"
```

### Comentarios

```jinja2
{# Este comentario NO aparece en el output #}
```

**Ejemplo:**
```jinja2
{# TODO: Agregar soporte para proxy #}
{# Este bloque está deshabilitado temporalmente #}
```

### Condicionales

```jinja2
{% if condicion %}
  código si verdadero
{% elif otra_condicion %}
  código si otra condición
{% else %}
  código si todo falso
{% endif %}
```

**Ejemplo:**
```jinja2
{% if cni_provider == 'calico' %}
echo "  3. Apply Calico CNI:"
echo "     kubectl apply -f calico.yaml"
{% elif cni_provider == 'flannel' %}
echo "  3. Apply Flannel CNI:"
echo "     kubectl apply -f flannel.yaml"
{% else %}
echo "  3. Install CNI via Helm"
{% endif %}
```

### Loops

```jinja2
{% for item in lista %}
  {{ item }}
{% endfor %}
```

**Ejemplo:**
```jinja2
{% for module in version_data.kernel_modules %}
modprobe {{ module }}
{% endfor %}
```

### Filtros

```jinja2
{{ texto|filtro }}
```

**Filtros comunes:**
- `capitalize` - Primera letra mayúscula
- `upper` - Todo mayúsculas
- `lower` - Todo minúsculas
- `default(valor)` - Valor por defecto si variable es None

**Ejemplo:**
```jinja2
log "{{ cni_provider|capitalize }} manifest copied"
# Output: "Calico manifest copied"
```

---

## Casos de Uso Comunes

### 1. Agregar Registry Mirror Privado

**Archivo:** `templates/config/containerd-config.toml.j2`

Agregar al final del archivo:

```toml
# Private registry mirror
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.mycompany.com"]
  endpoint = ["https://registry.mycompany.com:5000"]

# Docker Hub mirror (opcional)
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
  endpoint = ["https://mirror.mycompany.com"]
```

Rebuild:
```bash
make clean
make build
```

Verificar:
```bash
tar -xzf k8s-bundle-output/k8s-complete-*.tar.gz -C /tmp
grep "registry.mycompany.com" /tmp/k8s-complete-*/config/containerd-config.toml
```

---

### 2. Configurar Autenticación de Registry

**Archivo:** `templates/config/containerd-config.toml.j2`

Agregar:

```toml
# Registry authentication
[plugins."io.containerd.grpc.v1.cri".registry.configs."registry.mycompany.com".auth]
  username = "{{ registry_username }}"  # Debe definirse en process_template()
  password = "{{ registry_password }}"  # Debe definirse en process_template()
```

**Importante:** No hardcodear credenciales. Usar variables de entorno:

En `scripts/create-k8s-bundle.sh`, función `process_template()`, agregar:

```bash
context = {
    # ... variables existentes ...
    'registry_username': '${REGISTRY_USERNAME:-}',
    'registry_password': '${REGISTRY_PASSWORD:-}',
}
```

Uso:
```bash
export REGISTRY_USERNAME="myuser"
export REGISTRY_PASSWORD="mypass"
make build
```

---

### 3. Configurar Proxy para Containerd

**Archivo:** `templates/install/install-k8s.sh.j2`

En la sección `CONTAINERD`, después de `mkdir -p /etc/systemd/system`, agregar:

```jinja2
    # Configure proxy for containerd
{% if proxy_url is defined and proxy_url %}
    mkdir -p /etc/systemd/system/containerd.service.d
    cat > /etc/systemd/system/containerd.service.d/http-proxy.conf << 'PROXY_EOF'
[Service]
Environment="HTTP_PROXY={{ proxy_url }}"
Environment="HTTPS_PROXY={{ proxy_url }}"
Environment="NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
PROXY_EOF
    log "Proxy configured for containerd"
{% endif %}
```

Definir variable en `process_template()`:

```python
'proxy_url': '${HTTP_PROXY:-}',  # Vacío si no está definido
```

Uso:
```bash
export HTTP_PROXY="http://proxy.company.com:8080"
make build
```

---

### 4. Aumentar Timeout de Crictl

**Archivo:** `templates/config/crictl.yaml.j2`

Cambiar:

```yaml
# Timeout for operations (in seconds)
timeout: 60  # Aumentado de 30 a 60
```

---

### 5. Habilitar Debug Logging en Containerd

**Archivo:** `templates/config/containerd-config.toml.j2`

Descomentar bloque:

```toml
# Enable debug logging
[debug]
  level = "debug"
```

**Nota:** Esto genera logs muy verbosos. Solo para troubleshooting.

---

### 6. Agregar Paso Personalizado en Instalación

**Archivo:** `templates/install/install-k8s.sh.j2`

Después del paso 9, antes de verificación:

```bash
# ========================= CUSTOM STEP =========================

section "Step 10/10: Installing Custom Tools"

# Ejemplo: Instalar Helm
if [[ -f "$SCRIPT_DIR/binaries/custom/helm" ]]; then
    install -m 755 "$SCRIPT_DIR/binaries/custom/helm" /usr/local/bin/
    log "Helm installed"
fi

# Ejemplo: Configurar NTP
if command -v chronyc &>/dev/null; then
    systemctl enable chronyd
    systemctl start chronyd
    log "NTP configured"
fi
```

---

### 7. Personalizar Pod Network CIDR

**Archivo:** `templates/install/install-k8s.sh.j2`

En la sección "Next steps", modificar:

```jinja2
echo "  1. Initialize cluster (master node):"
echo "     kubeadm init --pod-network-cidr={{ pod_network_cidr }}"
```

Definir variable:

```python
'pod_network_cidr': '${POD_NETWORK_CIDR:-10.244.0.0/16}',
```

Uso:
```bash
export POD_NETWORK_CIDR="10.100.0.0/16"
make build
```

---

### 8. Agregar Nuevo CNI Provider

**Archivo:** `templates/install/install-k8s.sh.j2`

En la sección CNI, modificar el condicional:

```jinja2
{% if cni_provider == 'calico' %}
    info "Calico manifest available..."
{% elif cni_provider == 'flannel' %}
    info "Flannel manifest available..."
{% elif cni_provider == 'cilium' %}
    info "Cilium manifest available at: $SCRIPT_DIR/binaries/cni/cilium.yaml"
    info "Apply with: kubectl apply -f cilium.yaml"
{% elif cni_provider == 'none' %}
    info "CNI provider set to 'none'..."
{% else %}
    warning "Unknown CNI provider: {{ cni_provider }}"
{% endif %}
```

Uso:
```bash
CNI_PROVIDER=cilium make build
```

---

## Variables Disponibles

### Variables Globales

Disponibles en todos los templates:

| Variable | Tipo | Descripción | Ejemplo |
|----------|------|-------------|---------|
| `k8s_version` | string | Versión de Kubernetes | `"1.30.2"` |
| `containerd_version` | string | Versión de containerd | `"1.7.18"` |
| `runc_version` | string | Versión de runc | `"1.1.13"` |
| `cni_version` | string | Versión de CNI plugins | `"1.5.0"` |
| `pause_image` | string | Imagen pause | `"registry.k8s.io/pause:3.9"` |
| `arch` | string | Arquitectura | `"amd64"` o `"arm64"` |
| `ubuntu_version` | string | Versión de Ubuntu | `"22.04"` |
| `cni_provider` | string | Proveedor CNI | `"calico"`, `"flannel"`, `"none"` |
| `runtime_endpoint` | string | Endpoint CRI | `"unix:///var/run/containerd/containerd.sock"` |
| `image_endpoint` | string | Endpoint imágenes | `"unix:///var/run/containerd/containerd.sock"` |
| `timeout` | integer | Timeout crictl | `30` |

### Variable Avanzada

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `version_data` | dict | Acceso completo a k8s-versions.yaml |

**Ejemplo de uso:**

```jinja2
{# Acceder a cualquier valor del YAML #}
etcd_image: {{ version_data.container_images.etcd }}
coredns_image: {{ version_data.container_images.coredns }}

{# Iterar sobre módulos de kernel #}
{% for module in version_data.kernel_modules %}
- {{ module }}
{% endfor %}

{# Acceder a paquetes APT #}
{% for pkg in version_data.system_packages.apt %}
- {{ pkg.name }} ({{ pkg.version }})
{% endfor %}
```

### Agregar Variables Personalizadas

Editar `scripts/create-k8s-bundle.sh`, función `process_template()`:

```python
context = {
    # Variables existentes...
    'k8s_version': '${k8s_ver}',

    # Agregar tu variable
    'mi_variable': '${MI_VARIABLE:-valor_default}',
    'otra_var': 'valor_fijo',
}
```

Uso en templates:

```jinja2
{{ mi_variable }}
{{ otra_var }}
```

---

## Testing de Cambios

### Proceso Recomendado

1. **Backup de templates originales:**
   ```bash
   cp templates/config/containerd-config.toml.j2 templates/config/containerd-config.toml.j2.bak
   ```

2. **Modificar template**

3. **Rebuild bundle:**
   ```bash
   make clean
   make build
   ```

4. **Extraer y revisar:**
   ```bash
   make extract
   cat bundle-inspect/*/config/containerd-config.toml
   ```

5. **Validar sintaxis Jinja2:**
   ```bash
   python3 << 'EOF'
   import jinja2
   template_env = jinja2.Environment(loader=jinja2.FileSystemLoader('templates'))
   template = template_env.get_template('config/containerd-config.toml.j2')
   print("✓ Template syntax OK")
   EOF
   ```

6. **Testear en VM/contenedor:**
   ```bash
   # Transferir bundle a VM de prueba
   scp k8s-bundle-output/k8s-complete-*.tar.gz testvm:/tmp/

   # En VM: extraer y ejecutar
   tar -xzf k8s-complete-*.tar.gz
   cd k8s-complete-*
   sudo bash install-k8s.sh
   ```

7. **Verificar resultado:**
   ```bash
   # Verificar configuración aplicada
   cat /etc/containerd/config.toml
   cat /etc/crictl.yaml

   # Verificar servicios
   systemctl status containerd
   crictl version
   ```

### Testing de Lógica Condicional

Testear diferentes valores de CNI provider:

```bash
CNI_PROVIDER=calico make build
CNI_PROVIDER=flannel make build
CNI_PROVIDER=none make build
```

Verificar diferencias:

```bash
tar -xzf k8s-bundle-output/k8s-complete-*-calico.tar.gz -C /tmp/calico
tar -xzf k8s-bundle-output/k8s-complete-*-flannel.tar.gz -C /tmp/flannel
diff /tmp/calico/install-k8s.sh /tmp/flannel/install-k8s.sh
```

---

## Troubleshooting

### Error: "template not found"

**Causa:** Template .j2 no existe o está en ubicación incorrecta

**Solución:**
```bash
# Verificar que existe
ls -la templates/config/*.j2

# Verificar rutas en create-k8s-bundle.sh
grep "process_template.*containerd" scripts/create-k8s-bundle.sh
```

---

### Error: "jinja2.exceptions.UndefinedError: 'variable' is undefined"

**Causa:** Variable usada en template pero no definida en context

**Solución:**

1. Verificar que la variable está en `process_template()`:
   ```bash
   grep "'variable_name'" scripts/create-k8s-bundle.sh
   ```

2. Agregar variable al context:
   ```python
   context = {
       # ...
       'variable_name': 'valor',
   }
   ```

3. O usar valor default en template:
   ```jinja2
   {{ variable_name|default('valor_por_defecto') }}
   ```

---

### Error: "jinja2.exceptions.TemplateSyntaxError"

**Causa:** Sintaxis Jinja2 incorrecta

**Ejemplos comunes:**

```jinja2
# INCORRECTO - falta {% endif %}
{% if condition %}
  contenido

# CORRECTO
{% if condition %}
  contenido
{% endif %}

# INCORRECTO - comilla mal cerrada
{{ "texto }}

# CORRECTO
{{ "texto" }}

# INCORRECTO - { en lugar de {%
{ if condition }

# CORRECTO
{% if condition %}
```

**Validación:**
```bash
python3 << 'EOF'
import jinja2
import sys
try:
    env = jinja2.Environment(loader=jinja2.FileSystemLoader('templates'))
    template = env.get_template('config/containerd-config.toml.j2')
    print("✓ Syntax OK")
except jinja2.exceptions.TemplateSyntaxError as e:
    print(f"✗ Syntax Error: {e}")
    sys.exit(1)
EOF
```

---

### Cambios no se aplican

**Causa:** Template cacheado o editando archivo incorrecto

**Solución:**

1. Asegurarte de editar el .j2:
   ```bash
   # INCORRECTO - editar archivo generado
   nano bundle-inspect/config/containerd-config.toml

   # CORRECTO - editar template
   nano templates/config/containerd-config.toml.j2
   ```

2. Forzar rebuild completo:
   ```bash
   make clean
   rm -rf k8s-bundle-workspace/
   make build
   ```

3. Verificar que cambio está en template:
   ```bash
   grep "mi_cambio" templates/config/containerd-config.toml.j2
   ```

---

### Build falla con "Required templates missing"

**Causa:** Template eliminado o renombrado

**Solución:**

1. Verificar templates requeridos:
   ```bash
   ls -1 templates/config/*.j2
   ls -1 templates/scripts/*.j2
   ls -1 templates/install/*.j2
   ```

2. Restaurar de git si fue eliminado:
   ```bash
   git checkout templates/config/containerd-config.toml.j2
   ```

3. O deshabilitar validación (no recomendado):
   ```bash
   # En create-k8s-bundle.sh, comentar:
   # validate_templates
   ```

---

## Mejores Prácticas

1. **Siempre usar control de versiones:**
   ```bash
   git add templates/
   git commit -m "feat: add private registry mirror support"
   ```

2. **Documentar cambios en templates:**
   ```jinja2
   {# 2026-01-12: Added support for private registry mirror #}
   [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.local"]
     endpoint = ["https://registry.local:5000"]
   ```

3. **Testear en ambiente no-producción primero**

4. **No hardcodear credenciales - usar variables de entorno**

5. **Mantener templates legibles con comentarios**

6. **Usar valores default para variables opcionales:**
   ```jinja2
   {{ proxy_url|default('') }}
   ```

---

## Recursos Adicionales

- [Jinja2 Documentation](https://jinja.palletsprojects.com/)
- [Containerd Configuration](https://github.com/containerd/containerd/blob/main/docs/cri/config.md)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- `templates/config/README.md` - Documentación de templates de configuración
- `templates/scripts/README.md` - Documentación de templates de scripts
- `templates/install/README.md` - Documentación del template de instalación

---

## Soporte

Si encuentras problemas:

1. Revisar esta guía de troubleshooting
2. Verificar logs de build en `k8s-bundle-output/k8s-bundle-creation.log`
3. Validar sintaxis Jinja2 con script de validación
4. Testear en ambiente limpio
5. Abrir issue en el repositorio con detalles del error
