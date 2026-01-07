# Skip Options - Guía de Uso

## Variables de Entorno Disponibles

```bash
SKIP_APT_DOWNLOAD=auto|yes|no          # Default: auto
SKIP_PIP_DOWNLOAD=auto|yes|no          # Default: auto
SKIP_K8S_DOWNLOAD=yes|no               # Default: no
SKIP_CONTAINERD_DOWNLOAD=yes|no        # Default: no
SKIP_CNI_DOWNLOAD=yes|no               # Default: no
```

## Modos de Skip

### `auto` (Default para APT y PIP)
- **Detecta automáticamente** si existen paquetes descargados
- Si existen: los reutiliza
- Si no existen: descarga normalmente
- **Recomendado para la mayoría de casos**

### `yes`
- **Fuerza el skip** y reutiliza paquetes existentes
- Si no existen paquetes: muestra warning y descarga de todos modos
- Útil cuando quieres asegurarte de no descargar

### `no`
- **Siempre descarga** aunque existan paquetes previos
- Ignora paquetes existentes completamente
- Útil para forzar re-descarga con nuevas versiones

## Ejemplos de Uso

### 1. Skip Solo APT (Tu Caso)

```bash
# Opción A: Modo explícito
SKIP_APT_DOWNLOAD=yes ./create-k8s-bundle.sh

# Opción B: Con make
SKIP_APT_DOWNLOAD=yes make build

# Lo que hace:
# ✓ Reutiliza APT packages (ahorra 40 min)
# ✓ Descarga K8s binaries (~2 min)
# ✓ Descarga containerd (~1 min)
# ✓ Descarga CNI (~1 min)
# ✓ Descarga PIP packages (~1 min)
```

### 2. Skip APT y PIP

```bash
SKIP_APT_DOWNLOAD=yes SKIP_PIP_DOWNLOAD=yes ./create-k8s-bundle.sh

# Lo que hace:
# ✓ Reutiliza APT packages
# ✓ Reutiliza PIP packages
# ✓ Descarga solo binarios (K8s, containerd, CNI)
```

### 3. Skip Todo Excepto APT

```bash
SKIP_K8S_DOWNLOAD=yes \
SKIP_CONTAINERD_DOWNLOAD=yes \
SKIP_CNI_DOWNLOAD=yes \
./create-k8s-bundle.sh

# Lo que hace:
# ✓ Descarga APT packages
# ✓ Descarga PIP packages
# ✗ Skip K8s binaries
# ✗ Skip containerd
# ✗ Skip CNI
```

### 4. Modo Auto (Default)

```bash
# Sin variables - comportamiento auto
./create-k8s-bundle.sh

# Lo que hace:
# - APT: auto-detecta y reutiliza si existen
# - PIP: auto-detecta y reutiliza si existen
# - K8s: siempre descarga
# - Containerd: siempre descarga
# - CNI: siempre descarga
```

### 5. Forzar Re-descarga de Todo

```bash
SKIP_APT_DOWNLOAD=no \
SKIP_PIP_DOWNLOAD=no \
./create-k8s-bundle.sh

# Lo que hace:
# ✗ Descarga APT aunque existan
# ✗ Descarga PIP aunque existan
# ✗ Descarga todo desde cero
```

## Casos de Uso Comunes

### Caso 1: Ya descargaste APT (40 min) y falló después

```bash
# Solo quieres saltar APT
SKIP_APT_DOWNLOAD=yes ./create-k8s-bundle.sh
```

### Caso 2: Quieres actualizar solo binarios de K8s

```bash
# Reutiliza packages del sistema, re-descarga binarios
SKIP_APT_DOWNLOAD=yes \
SKIP_PIP_DOWNLOAD=yes \
./create-k8s-bundle.sh
```

### Caso 3: Desarrollo/Testing (skip todo lo posible)

```bash
# Solo para verificar que el script funciona sin descargar
SKIP_APT_DOWNLOAD=yes \
SKIP_PIP_DOWNLOAD=yes \
SKIP_K8S_DOWNLOAD=yes \
SKIP_CONTAINERD_DOWNLOAD=yes \
SKIP_CNI_DOWNLOAD=yes \
./create-k8s-bundle.sh
```

### Caso 4: Primera ejecución completa

```bash
# No especificas nada, usa defaults
./create-k8s-bundle.sh

# O explícitamente:
SKIP_APT_DOWNLOAD=auto SKIP_PIP_DOWNLOAD=auto ./create-k8s-bundle.sh
```

## Output del Script

### Con SKIP_APT_DOWNLOAD=yes

```
════════════════════════════════════════════════════════════════
  Kubernetes Complete Bundle Creator
════════════════════════════════════════════════════════════════

  K8S Version:     1.30.2
  Ubuntu Version:  22.04
  Architecture:    amd64
  CNI Provider:    calico

  Skip Options:
    APT Download:        yes         ← ACTIVO
    PIP Download:        auto
    K8s Download:        no
    Containerd Download: no
    CNI Download:        no

════════════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════════
  Downloading System Packages
═══════════════════════════════════════════════════════════════
[20:50:03] ℹ INFO: APT packages to download: 31
[20:50:03] ℹ INFO: SKIP_APT_DOWNLOAD=yes - Reusing 156 existing .deb files
[20:50:04] ✓ Moved 156 .deb packages to bundle
```

### Con SKIP_APT_DOWNLOAD=auto (detecta)

```
═══════════════════════════════════════════════════════════════
  Downloading System Packages
═══════════════════════════════════════════════════════════════
[20:50:03] ℹ INFO: APT packages to download: 31
[20:50:03] ⚠ WARNING: Auto-detected existing APT packages: 156 .deb files
[20:50:03] ℹ INFO: Reusing previously downloaded packages (use SKIP_APT_DOWNLOAD=no to force re-download)
[20:50:04] ✓ Moved 156 .deb packages to bundle
```

### Con SKIP_APT_DOWNLOAD=no (fuerza descarga)

```
═══════════════════════════════════════════════════════════════
  Downloading System Packages
═══════════════════════════════════════════════════════════════
[20:50:03] ℹ INFO: APT packages to download: 31
[20:50:03] ⚙ Executing download-apt.sh...
[21:30:15] ✓ APT packages downloaded         ← 40 minutos después
[21:30:16] ✓ Moved 156 .deb packages to bundle
```

## Verificar Antes de Ejecutar

```bash
# Ver qué paquetes tienes descargados
ls -lh k8s-bundle-workspace/offline_dpkg_packages/*.deb | wc -l
ls -lh k8s-bundle-workspace/offline_pip_packages/* | wc -l

# Ver ayuda completa
./create-k8s-bundle.sh --help
```

## Troubleshooting

### "SKIP_APT_DOWNLOAD=yes but no packages found"

```bash
# El skip está activo pero no hay paquetes
# Solución: El script automáticamente descargará de todos modos
```

### Quiero forzar re-descarga

```bash
# Borrar paquetes existentes
rm -rf k8s-bundle-workspace/offline_dpkg_packages
rm -rf k8s-bundle-workspace/offline_pip_packages

# O usar SKIP_*=no
SKIP_APT_DOWNLOAD=no ./create-k8s-bundle.sh
```

### No estoy seguro de qué hacer

```bash
# Usa el modo auto (default) - es inteligente
./create-k8s-bundle.sh
```

## Resumen Rápido

| Escenario | Comando |
|-----------|---------|
| **Saltar APT (tu caso)** | `SKIP_APT_DOWNLOAD=yes ./create-k8s-bundle.sh` |
| **Saltar APT y PIP** | `SKIP_APT_DOWNLOAD=yes SKIP_PIP_DOWNLOAD=yes ./create-k8s-bundle.sh` |
| **Forzar re-descarga todo** | `SKIP_APT_DOWNLOAD=no SKIP_PIP_DOWNLOAD=no ./create-k8s-bundle.sh` |
| **Auto-detectar (default)** | `./create-k8s-bundle.sh` |
| **Ver opciones** | `./create-k8s-bundle.sh --help` |

---

**Recomendación para tu caso actual:**

```bash
SKIP_APT_DOWNLOAD=yes ./create-k8s-bundle.sh
```

Esto reutilizará tus 40 minutos de descarga APT y completará el bundle en ~8-10 minutos.
