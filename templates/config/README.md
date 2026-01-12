# Configuration Templates

Este directorio contiene templates Jinja2 para archivos de configuración de Kubernetes.

## Templates Disponibles

### containerd-config.toml.j2
Configuración de containerd para Kubernetes.

**Variables disponibles:**
- `k8s_version` - Versión de Kubernetes (para documentación)
- `containerd_version` - Versión de containerd (para documentación)
- `pause_image` - Imagen pause extraída de k8s-versions.yaml

**Personalización común:**
1. **Agregar registry mirror privado:**
   ```toml
   [plugins."io.containerd.grpc.v1.cri".registry.mirrors."myregistry.local"]
     endpoint = ["https://myregistry.local:5000"]
   ```

2. **Habilitar debug logging:**
   ```toml
   [debug]
     level = "debug"
   ```

3. **Configurar autenticación de registry:**
   ```toml
   [plugins."io.containerd.grpc.v1.cri".registry.configs."myregistry.local".auth]
     username = "user"
     password = "pass"
   ```

### crictl.yaml.j2
Configuración de crictl (herramienta CLI para CRI).

**Variables disponibles:**
- `k8s_version` - Versión de Kubernetes (para documentación)
- `runtime_endpoint` - Endpoint del runtime (default: unix:///var/run/containerd/containerd.sock)
- `image_endpoint` - Endpoint de imágenes (default: unix:///var/run/containerd/containerd.sock)
- `timeout` - Timeout para operaciones en segundos (default: 30)

**Personalización común:**
1. **Aumentar timeout:**
   ```yaml
   timeout: 60
   ```

2. **Habilitar debug mode:**
   ```yaml
   debug: true
   ```

3. **Habilitar pull automático:**
   ```yaml
   pull-image-on-create: true
   ```

## Sintaxis Jinja2

Los templates usan Jinja2. Sintaxis básica:

**Variables:**
```jinja2
{{ variable_name }}
```

**Comentarios (no aparecen en output):**
```jinja2
{# Este es un comentario #}
```

**Condicionales:**
```jinja2
{% if condition %}
  contenido si verdadero
{% else %}
  contenido si falso
{% endif %}
```

**Loops:**
```jinja2
{% for item in list %}
  {{ item }}
{% endfor %}
```

**Filtros:**
```jinja2
{{ texto|capitalize }}  # Primera letra mayúscula
{{ texto|upper }}       # Todo mayúsculas
{{ texto|lower }}       # Todo minúsculas
```

## Proceso de Construcción

Cuando ejecutas `make build`:

1. El script lee k8s-versions.yaml
2. Procesa cada template (.j2) con las variables correspondientes
3. Genera los archivos de configuración finales
4. Los incluye en el bundle

## Troubleshooting

**Error: "template not found"**
- Verifica que el archivo .j2 existe en este directorio
- Asegúrate de no haber renombrado o movido templates

**Error: "variable undefined"**
- La variable falta en el contexto de Jinja2
- Revisa process_template() en create-k8s-bundle.sh

**Cambios no se aplican:**
- Asegúrate de editar el archivo .j2, no el archivo generado
- Ejecuta `make clean && make build` para forzar regeneración
