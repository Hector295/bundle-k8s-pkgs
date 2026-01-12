# System Configuration Files

Este directorio contiene las configuraciones del sistema para los nodos worker de Kubernetes.

## Archivos

### apt-packages.yaml
Lista de paquetes APT del sistema.

**Formato:**
```yaml
- name: "package-name"
  version: "1.2.3*"  # Optional, use "" for latest
```

**Ejemplo - Agregar htop:**
```yaml
- name: "htop"
  version: ""
```

### pip-packages.yaml
Paquetes Python instalados vía pip.

**Formato:**
```yaml
- name: "package-name"
  version: "1.2.3"  # Optional, use "latest" or ""
```

**Ejemplo - Agregar ansible:**
```yaml
- name: "ansible"
  version: "latest"
```

### kernel-modules.yaml
Módulos de kernel que se cargarán en el sistema.

**Formato:**
```yaml
- module-name
```

**Ejemplo - Agregar iscsi_tcp:**
```yaml
- iscsi_tcp
```

### sysctl-settings.yaml
Parámetros de kernel (sysctl).

**Formato:**
```yaml
parameter.name: value
```

**Ejemplo - Agregar tcp_tw_reuse:**
```yaml
net.ipv4.tcp_tw_reuse: 1
```

## Rebuild Después de Cambios

Después de modificar cualquier archivo:

```bash
make clean
make build
```

## Validación de Sintaxis

Validar YAML antes de build:

```bash
python3 -c "import yaml; yaml.safe_load(open('config/apt-packages.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('config/pip-packages.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('config/kernel-modules.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('config/sysctl-settings.yaml'))"
```

## Separación de Concerns

**Este directorio (`config/`):**
- Paquetes del sistema operativo (APT, PIP)
- Módulos de kernel
- Parámetros sysctl

**Archivo `k8s-versions.yaml` (raíz):**
- Versiones de Kubernetes
- Versiones de componentes (containerd, runc, CNI)
- Imágenes de contenedores

**Directorio `templates/`:**
- Templates Jinja2 para scripts
- Configuraciones avanzadas (containerd, crictl)

Esta separación permite:
- Actualizar paquetes sin tocar versiones de K8s
- Reutilizar configuraciones entre versiones
- Edición simple sin detalles innecesarios
