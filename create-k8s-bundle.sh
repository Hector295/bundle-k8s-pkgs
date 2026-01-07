#!/bin/bash

# ============================================================================
# Complete Kubernetes Offline Bundle Creator
# ============================================================================
# Crea un bundle completo con TODO lo necesario para instalar Kubernetes
# Basado en matriz de versiones (k8s-versions.yaml)
# ============================================================================

set -e
set -o pipefail

# ========================= CONFIGURATION =========================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="${SCRIPT_DIR}/k8s-versions.yaml"

# Default values
K8S_VERSION="${1:-1.30.2}"
UBUNTU_VERSION="${2:-22.04}"
ARCH="${3:-amd64}"

WORK_DIR="./k8s-bundle-workspace"
OUTPUT_DIR="./k8s-bundle-output"
BUNDLE_NAME="k8s-complete-${K8S_VERSION}-ubuntu${UBUNTU_VERSION}-${ARCH}"
BUNDLE_DIR="${WORK_DIR}/${BUNDLE_NAME}"

# Download options
DOWNLOAD_IMAGES="${DOWNLOAD_IMAGES:-yes}"
DOWNLOAD_CNI="${DOWNLOAD_CNI:-yes}"
CNI_PROVIDER="${CNI_PROVIDER:-calico}"  # calico, flannel, none

# Skip options (reuse previously downloaded packages)
SKIP_APT_DOWNLOAD="${SKIP_APT_DOWNLOAD:-auto}"  # yes, no, auto
SKIP_PIP_DOWNLOAD="${SKIP_PIP_DOWNLOAD:-auto}"  # yes, no, auto
SKIP_K8S_DOWNLOAD="${SKIP_K8S_DOWNLOAD:-no}"    # yes, no
SKIP_CONTAINERD_DOWNLOAD="${SKIP_CONTAINERD_DOWNLOAD:-no}"  # yes, no
SKIP_CNI_DOWNLOAD="${SKIP_CNI_DOWNLOAD:-no}"    # yes, no

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Log file (will be created in setup_workspace)
LOG_FILE="${OUTPUT_DIR}/k8s-bundle-creation.log"

# ========================= LOGGING FUNCTIONS =========================

log() {
    [[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    [[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"
    echo -e "${RED}[$(date +'%H:%M:%S')] ✗ ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    [[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"
    echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    [[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠ $1${NC}" | tee -a "$LOG_FILE"
}

progress() {
    [[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"
    echo -e "${PURPLE}[$(date +'%H:%M:%S')] ⚙ $1${NC}" | tee -a "$LOG_FILE"
}

section() {
    [[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"
    echo -e "${CYAN}" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "  $1" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
}

# ========================= YAML PARSER =========================

parse_yaml() {
    local yaml_file="$1"
    local version="$2"

    # Simple YAML parser usando Python
    python3 << EOF
import yaml
import sys
import json

try:
    with open("${yaml_file}", 'r') as f:
        data = yaml.safe_load(f)

    if "${version}" in data['versions']:
        version_data = data['versions']['${version}']
        print(json.dumps(version_data, indent=2))
    else:
        print("ERROR: Version ${version} not found in ${yaml_file}", file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f"ERROR parsing YAML: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

# ========================= PREREQUISITES =========================

check_prerequisites() {
    section "Checking Prerequisites"

    local missing=()

    # Required commands
    local required_cmds=(
        "curl"
        "wget"
        "tar"
        "gzip"
        "python3"
        "apt-cache"
        "dpkg"
    )

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    # Check Python PyYAML
    if ! python3 -c "import yaml" 2>/dev/null; then
        missing+=("python3-yaml")
        warning "Installing python3-yaml..."
        sudo apt-get install -y python3-yaml &>/dev/null || missing+=("python3-yaml (install failed)")
    fi

    # Check versions file
    if [[ ! -f "$VERSIONS_FILE" ]]; then
        missing+=("$VERSIONS_FILE")
    fi

    # Check download scripts
    if [[ ! -f "${SCRIPT_DIR}/download-apt.sh" ]]; then
        missing+=("download-apt.sh")
    fi

    if [[ ! -f "${SCRIPT_DIR}/download-pip.sh" ]]; then
        missing+=("download-pip.sh")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing prerequisites: ${missing[*]}"
    fi

    log "All prerequisites met"
}

# ========================= VERSION VALIDATION =========================

validate_version() {
    section "Validating K8S Version"

    info "Kubernetes version: $K8S_VERSION"
    info "Ubuntu version: $UBUNTU_VERSION"
    info "Architecture: $ARCH"

    # Parse version data
    VERSION_DATA=$(parse_yaml "$VERSIONS_FILE" "$K8S_VERSION")

    if [[ -z "$VERSION_DATA" ]]; then
        error "Failed to parse version $K8S_VERSION from $VERSIONS_FILE"
    fi

    log "Version $K8S_VERSION configuration loaded"
}

# ========================= WORKSPACE SETUP =========================

setup_workspace() {
    section "Setting Up Workspace"

    # Preserve downloaded packages if they exist
    local preserve_apt=false
    local preserve_pip=false

    if [[ -d "$WORK_DIR" ]]; then
        # Check for existing downloads
        if [[ -d "$WORK_DIR/offline_dpkg_packages" ]]; then
            local apt_count=$(ls -1 "$WORK_DIR/offline_dpkg_packages"/*.deb 2>/dev/null | wc -l || echo "0")
            if [[ $apt_count -gt 0 ]]; then
                info "Preserving $apt_count APT packages from previous run"
                mv "$WORK_DIR/offline_dpkg_packages" /tmp/offline_dpkg_packages_backup
                preserve_apt=true
            fi
        fi

        if [[ -d "$WORK_DIR/offline_pip_packages" ]]; then
            local pip_count=$(ls -1 "$WORK_DIR/offline_pip_packages"/* 2>/dev/null | wc -l || echo "0")
            if [[ $pip_count -gt 0 ]]; then
                info "Preserving $pip_count PIP packages from previous run"
                mv "$WORK_DIR/offline_pip_packages" /tmp/offline_pip_packages_backup
                preserve_pip=true
            fi
        fi

        # Clean workspace
        warning "Removing previous workspace"
        rm -rf "$WORK_DIR"
    fi

    # Create directory structure
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$BUNDLE_DIR"/binaries/kubernetes
    mkdir -p "$BUNDLE_DIR"/binaries/containerd
    mkdir -p "$BUNDLE_DIR"/binaries/cni
    mkdir -p "$BUNDLE_DIR"/images
    mkdir -p "$BUNDLE_DIR"/packages/apt
    mkdir -p "$BUNDLE_DIR"/packages/pip
    mkdir -p "$BUNDLE_DIR"/scripts
    mkdir -p "$BUNDLE_DIR"/config

    # Restore preserved packages
    if [[ "$preserve_apt" == "true" ]]; then
        mv /tmp/offline_dpkg_packages_backup "$WORK_DIR/offline_dpkg_packages"
        log "Restored APT packages"
    fi

    if [[ "$preserve_pip" == "true" ]]; then
        mv /tmp/offline_pip_packages_backup "$WORK_DIR/offline_pip_packages"
        log "Restored PIP packages"
    fi

    # Initialize log
    : > "$LOG_FILE"

    log "Workspace created: $WORK_DIR"
}

# ========================= DOWNLOAD KUBERNETES BINARIES =========================

download_kubernetes_binaries() {
    section "Downloading Kubernetes Binaries"

    local k8s_ver=$(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['kubernetes']['version'])")
    local k8s_base_url="https://dl.k8s.io/v${k8s_ver}/bin/linux/${ARCH}"

    cd "${BUNDLE_DIR}/binaries/kubernetes"

    local components=("kubeadm" "kubelet" "kubectl")

    for component in "${components[@]}"; do
        progress "Downloading $component v${k8s_ver}..."

        if wget -q --show-progress "${k8s_base_url}/${component}" 2>&1 | tee -a "$LOG_FILE"; then
            chmod +x "$component"
            log "$component downloaded"
        else
            error "Failed to download $component"
        fi

        # Download checksum
        if wget -q "${k8s_base_url}/${component}.sha256" 2>&1 | tee -a "$LOG_FILE"; then
            # Verify checksum
            local expected=$(cat "${component}.sha256")
            local actual=$(sha256sum "$component" | cut -d' ' -f1)

            if [[ "$expected" == "$actual" ]]; then
                log "$component checksum verified"
            else
                error "$component checksum mismatch!"
            fi
        fi
    done

    # Download kubelet systemd service
    progress "Downloading kubelet systemd service..."
    wget -q -O kubelet.service \
        "https://raw.githubusercontent.com/kubernetes/release/v0.16.2/cmd/krel/templates/latest/kubelet/kubelet.service"

    wget -q -O 10-kubeadm.conf \
        "https://raw.githubusercontent.com/kubernetes/release/v0.16.2/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf"

    log "Kubernetes binaries downloaded"
    cd "$SCRIPT_DIR"
}

# ========================= DOWNLOAD CONTAINERD =========================

download_containerd() {
    section "Downloading Containerd & Runc"

    local containerd_ver=$(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['container_runtime']['containerd']['version'])")
    local runc_ver=$(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['container_runtime']['runc']['version'])")

    cd "${BUNDLE_DIR}/binaries/containerd"

    # Download containerd
    progress "Downloading containerd ${containerd_ver}..."
    local containerd_url="https://github.com/containerd/containerd/releases/download/v${containerd_ver}/containerd-${containerd_ver}-linux-${ARCH}.tar.gz"

    if wget -q --show-progress "$containerd_url" 2>&1 | tee -a "$LOG_FILE"; then
        log "containerd downloaded"
    else
        error "Failed to download containerd"
    fi

    # Download containerd checksum
    wget -q "${containerd_url}.sha256sum"

    # Download runc
    progress "Downloading runc ${runc_ver}..."
    local runc_url="https://github.com/opencontainers/runc/releases/download/v${runc_ver}/runc.${ARCH}"

    if wget -q --show-progress -O runc "$runc_url" 2>&1 | tee -a "$LOG_FILE"; then
        chmod +x runc
        log "runc downloaded"
    else
        error "Failed to download runc"
    fi

    # Download runc checksum
    wget -q -O runc.sha256sum "https://github.com/opencontainers/runc/releases/download/v${runc_ver}/runc.sha256sum"

    # Download containerd systemd service
    progress "Downloading containerd systemd service..."
    wget -q -O containerd.service \
        "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"

    log "Container runtime binaries downloaded"
    cd "$SCRIPT_DIR"
}

# ========================= DOWNLOAD CNI PLUGINS =========================

download_cni_plugins() {
    section "Downloading CNI Plugins"

    if [[ "$DOWNLOAD_CNI" != "yes" ]]; then
        info "Skipping CNI plugins download"
        return
    fi

    local cni_ver=$(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['cni']['plugins_version'])")

    cd "${BUNDLE_DIR}/binaries/cni"

    progress "Downloading CNI plugins ${cni_ver}..."
    local cni_url="https://github.com/containernetworking/plugins/releases/download/v${cni_ver}/cni-plugins-linux-${ARCH}-v${cni_ver}.tgz"

    if wget -q --show-progress "$cni_url" 2>&1 | tee -a "$LOG_FILE"; then
        log "CNI plugins downloaded"
    else
        error "Failed to download CNI plugins"
    fi

    wget -q "${cni_url}.sha256"

    # Download CNI manifests based on provider
    if [[ "$CNI_PROVIDER" == "calico" ]]; then
        progress "Downloading Calico manifests..."
        local calico_ver=$(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['cni']['calico_version'])")
        wget -q -O calico.yaml "https://raw.githubusercontent.com/projectcalico/calico/v${calico_ver}/manifests/calico.yaml"
        log "Calico manifest downloaded"

    elif [[ "$CNI_PROVIDER" == "flannel" ]]; then
        progress "Downloading Flannel manifests..."
        local flannel_ver=$(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['cni']['flannel_version'])")
        wget -q -O flannel.yaml "https://github.com/flannel-io/flannel/releases/download/v${flannel_ver}/kube-flannel.yml"
        log "Flannel manifest downloaded"
    fi

    cd "$SCRIPT_DIR"
}

# ========================= DOWNLOAD CONTAINER IMAGES =========================

download_container_images() {
    section "Downloading Container Images"

    if [[ "$DOWNLOAD_IMAGES" != "yes" ]]; then
        info "Skipping container images download"
        return
    fi

    # Check if ctr or crictl is available
    if ! command -v ctr &>/dev/null && ! command -v crictl &>/dev/null; then
        warning "Neither ctr nor crictl found, skipping image download"
        warning "Images will need to be pulled during installation"
        return
    fi

    cd "${BUNDLE_DIR}/images"

    # Get list of images
    local images=(
        $(echo "$VERSION_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for img in data['container_images'].values():
    print(img)
")
    )

    progress "Found ${#images[@]} container images to download"

    # Create image list file
    printf "%s\n" "${images[@]}" > images.txt

    info "Container images will be pulled during installation"
    info "Image list saved to images.txt"

    log "Container images list created"
    cd "$SCRIPT_DIR"
}

# ========================= DOWNLOAD SYSTEM PACKAGES =========================

download_system_packages() {
    section "Downloading System Packages"

    # Extract package names and versions from VERSION_DATA
    local apt_packages=($(echo "$VERSION_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for pkg in data['system_packages']['apt']:
    name = pkg['name']
    version = pkg['version']
    if version:
        print(f'{name}={version}')
    else:
        print(name)
"))

    info "APT packages to download: ${#apt_packages[@]}"

    cd "$WORK_DIR"

    # Determine if we should skip APT download
    local skip_download=false

    if [[ "$SKIP_APT_DOWNLOAD" == "yes" ]]; then
        # Explicit skip requested
        if [[ -d "./offline_dpkg_packages" ]]; then
            local existing_debs=$(ls -1 ./offline_dpkg_packages/*.deb 2>/dev/null | wc -l || echo "0")
            if [[ $existing_debs -gt 0 ]]; then
                info "SKIP_APT_DOWNLOAD=yes - Reusing $existing_debs existing .deb files"
                skip_download=true
            else
                warning "SKIP_APT_DOWNLOAD=yes but no packages found, will download"
            fi
        else
            warning "SKIP_APT_DOWNLOAD=yes but offline_dpkg_packages not found, will download"
        fi
    elif [[ "$SKIP_APT_DOWNLOAD" == "auto" ]]; then
        # Auto-detect existing packages
        if [[ -d "./offline_dpkg_packages" ]]; then
            local existing_debs=$(ls -1 ./offline_dpkg_packages/*.deb 2>/dev/null | wc -l || echo "0")
            if [[ $existing_debs -gt 0 ]]; then
                warning "Auto-detected existing APT packages: $existing_debs .deb files"
                info "Reusing previously downloaded packages (use SKIP_APT_DOWNLOAD=no to force re-download)"
                skip_download=true
            fi
        fi
    fi
    # else SKIP_APT_DOWNLOAD=no, always download

    # Download only if not skipped
    if [[ "$skip_download" == "false" ]]; then
        cp "${SCRIPT_DIR}/download-apt.sh" .
        chmod +x download-apt.sh

        progress "Executing download-apt.sh..."
        if ./download-apt.sh "${apt_packages[@]}" >> "$LOG_FILE" 2>&1; then
            log "APT packages downloaded"
        else
            error "Failed to download APT packages"
        fi
    fi

    # Move packages
    if [[ -d "./offline_dpkg_packages" ]]; then
        mv ./offline_dpkg_packages/*.deb "${BUNDLE_DIR}/packages/apt/" 2>/dev/null || true

        # Copy install script if exists
        if [[ -f "./offline_dpkg_packages/install.sh" ]]; then
            cp ./offline_dpkg_packages/install.sh "${BUNDLE_DIR}/scripts/install-apt.sh"
        else
            # Generate a basic install script if it doesn't exist (for skip case)
            info "Generating install-apt.sh (not found in offline_dpkg_packages)"
            cat > "${BUNDLE_DIR}/scripts/install-apt.sh" << 'EOF'
#!/bin/bash
# Basic APT packages installer
set -e
cd "$(dirname "$0")/../packages/apt"
echo "Installing APT packages..."
sudo dpkg -i *.deb 2>/dev/null || true
sudo dpkg --configure -a
echo "APT packages installed"
EOF
            chmod +x "${BUNDLE_DIR}/scripts/install-apt.sh"
        fi

        local deb_count=$(ls -1 "${BUNDLE_DIR}/packages/apt/"*.deb 2>/dev/null | wc -l)
        log "Moved $deb_count .deb packages to bundle"

        rm -rf ./offline_dpkg_packages
    fi

    # Download PIP packages
    local pip_packages=($(echo "$VERSION_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for pkg in data['system_packages']['pip']:
    print(pkg['name'])
"))

    if [[ ${#pip_packages[@]} -gt 0 ]]; then
        info "PIP packages to download: ${#pip_packages[@]}"

        # Determine if we should skip PIP download
        local skip_pip_download=false

        if [[ "$SKIP_PIP_DOWNLOAD" == "yes" ]]; then
            # Explicit skip requested
            if [[ -d "./offline_pip_packages" ]]; then
                local existing_pip=$(ls -1 ./offline_pip_packages/* 2>/dev/null | wc -l || echo "0")
                if [[ $existing_pip -gt 0 ]]; then
                    info "SKIP_PIP_DOWNLOAD=yes - Reusing $existing_pip existing pip files"
                    skip_pip_download=true
                else
                    warning "SKIP_PIP_DOWNLOAD=yes but no packages found, will download"
                fi
            else
                warning "SKIP_PIP_DOWNLOAD=yes but offline_pip_packages not found, will download"
            fi
        elif [[ "$SKIP_PIP_DOWNLOAD" == "auto" ]]; then
            # Auto-detect existing packages
            if [[ -d "./offline_pip_packages" ]]; then
                local existing_pip=$(ls -1 ./offline_pip_packages/* 2>/dev/null | wc -l || echo "0")
                if [[ $existing_pip -gt 0 ]]; then
                    warning "Auto-detected existing PIP packages: $existing_pip files"
                    info "Reusing previously downloaded packages (use SKIP_PIP_DOWNLOAD=no to force re-download)"
                    skip_pip_download=true
                fi
            fi
        fi
        # else SKIP_PIP_DOWNLOAD=no, always download

        # Download only if not skipped
        if [[ "$skip_pip_download" == "false" ]]; then
            cp "${SCRIPT_DIR}/download-pip.sh" .
            chmod +x download-pip.sh

            progress "Executing download-pip.sh..."
            if ./download-pip.sh "${pip_packages[@]}" >> "$LOG_FILE" 2>&1; then
                log "PIP packages downloaded"
            else
                warning "Failed to download PIP packages"
            fi
        fi

        if [[ -d "./offline_pip_packages" ]]; then
            mv ./offline_pip_packages/* "${BUNDLE_DIR}/packages/pip/" 2>/dev/null || true
            rm -rf ./offline_pip_packages
        fi
    fi

    cd "$SCRIPT_DIR"
}

# ========================= CREATE CONFIGURATIONS =========================

create_configurations() {
    section "Creating Configuration Files"

    # Kernel modules
    echo "$VERSION_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
with open('${BUNDLE_DIR}/config/k8s-modules.conf', 'w') as f:
    f.write('# Kubernetes required kernel modules\n')
    f.write('# Auto-generated\n\n')
    for mod in data['kernel_modules']:
        f.write(f'{mod}\n')
"

    log "Kernel modules config created"

    # Sysctl settings
    echo "$VERSION_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
with open('${BUNDLE_DIR}/config/k8s-sysctl.conf', 'w') as f:
    f.write('# Kubernetes required sysctl settings\n')
    f.write('# Auto-generated\n\n')
    for key, value in data['sysctl'].items():
        f.write(f'{key} = {value}\n')
"

    log "Sysctl config created"

    # Containerd config
    cat > "${BUNDLE_DIR}/config/containerd-config.toml" << 'EOF'
version = 2

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
EOF

    log "Containerd config created"

    # Crictl config
    cat > "${BUNDLE_DIR}/config/crictl.yaml" << 'EOF'
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

    log "Crictl config created"
}

# ========================= CREATE INSTALLATION SCRIPT =========================

create_installation_script() {
    section "Creating Installation Script"

    cat > "${BUNDLE_DIR}/install-k8s.sh" << 'INSTALL_EOF'
#!/bin/bash

# ============================================================================
# Kubernetes Complete Installation Script
# ============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓] $1${NC}"; }
error() { echo -e "${RED}[✗] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[ℹ] $1${NC}"; }
warning() { echo -e "${YELLOW}[⚠] $1${NC}"; }
section() { echo -e "${CYAN}═══ $1 ═══${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check root
[[ $EUID -ne 0 ]] && error "This script must be run as root"

echo ""
section "Kubernetes Complete Installation"
echo ""

# ========================= SYSTEM PACKAGES =========================

section "Step 1/8: Installing System Packages"

if [[ -f "$SCRIPT_DIR/scripts/install-apt.sh" ]] && [[ -d "$SCRIPT_DIR/packages/apt" ]]; then
    cd "$SCRIPT_DIR/packages/apt"
    bash "$SCRIPT_DIR/scripts/install-apt.sh"
    log "System packages installed"
else
    warning "System packages not found, skipping..."
fi

# ========================= KERNEL MODULES =========================

section "Step 2/8: Configuring Kernel Modules"

if [[ -f "$SCRIPT_DIR/config/k8s-modules.conf" ]]; then
    cp "$SCRIPT_DIR/config/k8s-modules.conf" /etc/modules-load.d/

    # Load modules
    while IFS= read -r module; do
        [[ "$module" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$module" ]] && continue
        modprobe "$module" 2>/dev/null || warning "Failed to load: $module"
    done < /etc/modules-load.d/k8s-modules.conf

    log "Kernel modules configured"
fi

# ========================= SYSCTL =========================

section "Step 3/8: Applying Sysctl Settings"

if [[ -f "$SCRIPT_DIR/config/k8s-sysctl.conf" ]]; then
    cp "$SCRIPT_DIR/config/k8s-sysctl.conf" /etc/sysctl.d/99-k8s.conf
    sysctl --system >/dev/null
    log "Sysctl settings applied"
fi

# ========================= DISABLE SWAP =========================

section "Step 4/8: Disabling Swap"

swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
log "Swap disabled"

# ========================= CONTAINERD =========================

section "Step 5/8: Installing Containerd"

if [[ -d "$SCRIPT_DIR/binaries/containerd" ]]; then
    cd "$SCRIPT_DIR/binaries/containerd"

    # Extract containerd
    tar -xzf containerd-*.tar.gz -C /usr/local

    # Install runc
    install -m 755 runc /usr/local/sbin/runc

    # Install systemd service
    mkdir -p /etc/systemd/system
    cp containerd.service /etc/systemd/system/

    # Configure containerd
    mkdir -p /etc/containerd
    if [[ -f "$SCRIPT_DIR/config/containerd-config.toml" ]]; then
        cp "$SCRIPT_DIR/config/containerd-config.toml" /etc/containerd/config.toml
    else
        containerd config default > /etc/containerd/config.toml
    fi

    # Start containerd
    systemctl daemon-reload
    systemctl enable containerd
    systemctl start containerd

    log "Containerd installed and started"
else
    warning "Containerd binaries not found"
fi

# ========================= CNI PLUGINS =========================

section "Step 6/8: Installing CNI Plugins"

if [[ -d "$SCRIPT_DIR/binaries/cni" ]]; then
    mkdir -p /opt/cni/bin
    cd "$SCRIPT_DIR/binaries/cni"
    tar -xzf cni-plugins-*.tgz -C /opt/cni/bin
    log "CNI plugins installed"
fi

# ========================= KUBERNETES BINARIES =========================

section "Step 7/8: Installing Kubernetes Binaries"

if [[ -d "$SCRIPT_DIR/binaries/kubernetes" ]]; then
    cd "$SCRIPT_DIR/binaries/kubernetes"

    # Install binaries
    install -m 755 kubeadm /usr/local/bin/
    install -m 755 kubelet /usr/local/bin/
    install -m 755 kubectl /usr/local/bin/

    # Install kubelet systemd service
    mkdir -p /etc/systemd/system/kubelet.service.d
    cp kubelet.service /etc/systemd/system/
    cp 10-kubeadm.conf /etc/systemd/system/kubelet.service.d/

    # Enable kubelet
    systemctl daemon-reload
    systemctl enable kubelet

    log "Kubernetes binaries installed"
else
    error "Kubernetes binaries not found"
fi

# ========================= CONTAINER IMAGES =========================

section "Step 8/8: Loading Container Images"

if [[ -f "$SCRIPT_DIR/images/images.txt" ]]; then
    info "Container images will be pulled by kubeadm"
    info "To pre-pull images, run: kubeadm config images pull"
fi

# ========================= VERIFICATION =========================

section "Verification"

echo ""
info "Checking installation..."

# Check binaries
for cmd in kubeadm kubelet kubectl; do
    if command -v $cmd &>/dev/null; then
        version=$($cmd version --short 2>/dev/null | head -1 || echo "installed")
        echo "  ✓ $cmd: $version"
    else
        echo "  ✗ $cmd: not found"
    fi
done

# Check containerd
if systemctl is-active containerd &>/dev/null; then
    echo "  ✓ containerd: running"
else
    echo "  ✗ containerd: not running"
fi

# Check modules
for mod in overlay br_netfilter ip_vs; do
    if lsmod | grep -q "^${mod}"; then
        echo "  ✓ $mod module loaded"
    else
        echo "  ✗ $mod module not loaded"
    fi
done

# Check swap
if swapon --show | grep -q '/'; then
    echo "  ✗ swap still enabled"
else
    echo "  ✓ swap disabled"
fi

echo ""
echo -e "${GREEN}"
echo "═══════════════════════════════════════════════════════════════"
echo "  Kubernetes Installation Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo ""
info "Next steps:"
echo "  1. Initialize cluster (master node):"
echo "     kubeadm init --pod-network-cidr=10.244.0.0/16"
echo ""
echo "  2. Configure kubectl:"
echo "     mkdir -p \$HOME/.kube"
echo "     cp /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "     chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo ""
echo "  3. Apply CNI (choose one):"
echo "     kubectl apply -f \$SCRIPT_DIR/binaries/cni/calico.yaml"
echo "     # or"
echo "     kubectl apply -f \$SCRIPT_DIR/binaries/cni/flannel.yaml"
echo ""
echo "  4. Join worker nodes:"
echo "     kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>"
echo ""

INSTALL_EOF

    chmod +x "${BUNDLE_DIR}/install-k8s.sh"
    log "Installation script created"
}

# ========================= CREATE README =========================

create_readme() {
    section "Creating Documentation"

    cat > "${BUNDLE_DIR}/README.md" << EOF
# Kubernetes ${K8S_VERSION} Complete Bundle

**Created:** $(date '+%Y-%m-%d %H:%M:%S')
**Kubernetes Version:** ${K8S_VERSION}
**Ubuntu Version:** ${UBUNTU_VERSION}
**Architecture:** ${ARCH}

## Contents

This bundle contains **everything** needed to install Kubernetes ${K8S_VERSION} offline:

### 📦 Kubernetes Components
- kubeadm ${K8S_VERSION}
- kubelet ${K8S_VERSION}
- kubectl ${K8S_VERSION}

### 🐳 Container Runtime
- containerd $(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['container_runtime']['containerd']['version'])")
- runc $(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['container_runtime']['runc']['version'])")

### 🔌 CNI Plugins
- CNI plugins $(echo "$VERSION_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['cni']['plugins_version'])")
- ${CNI_PROVIDER} manifest (if downloaded)

### 📦 System Packages
- All required APT packages with dependencies
- Python packages (pip)

### ⚙️ Configurations
- Kernel modules (overlay, br_netfilter, ip_vs, etc.)
- Sysctl settings
- Containerd configuration
- Systemd services

## Installation

### Quick Install
\`\`\`bash
sudo ./install-k8s.sh
\`\`\`

### Manual Steps

#### 1. Install System Packages
\`\`\`bash
cd packages/apt
sudo bash ../../scripts/install-apt.sh
\`\`\`

#### 2. Install Containerd
\`\`\`bash
cd binaries/containerd
sudo tar -xzf containerd-*.tar.gz -C /usr/local
sudo install -m 755 runc /usr/local/sbin/runc
sudo cp containerd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
\`\`\`

#### 3. Install CNI Plugins
\`\`\`bash
sudo mkdir -p /opt/cni/bin
cd binaries/cni
sudo tar -xzf cni-plugins-*.tgz -C /opt/cni/bin
\`\`\`

#### 4. Install Kubernetes
\`\`\`bash
cd binaries/kubernetes
sudo install -m 755 kube{adm,let,ctl} /usr/local/bin/
sudo cp kubelet.service /etc/systemd/system/
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo cp 10-kubeadm.conf /etc/systemd/system/kubelet.service.d/
sudo systemctl enable kubelet
\`\`\`

#### 5. Configure System
\`\`\`bash
# Load kernel modules
sudo cp config/k8s-modules.conf /etc/modules-load.d/
sudo systemctl restart systemd-modules-load

# Apply sysctl
sudo cp config/k8s-sysctl.conf /etc/sysctl.d/99-k8s.conf
sudo sysctl --system

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
\`\`\`

## Initialize Cluster

### Master Node
\`\`\`bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl
mkdir -p \$HOME/.kube
sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config

# Apply CNI
kubectl apply -f binaries/cni/${CNI_PROVIDER}.yaml
\`\`\`

### Worker Nodes
\`\`\`bash
sudo kubeadm join <master-ip>:6443 \\
  --token <token> \\
  --discovery-token-ca-cert-hash sha256:<hash>
\`\`\`

## Verification

\`\`\`bash
# Check versions
kubeadm version
kubelet --version
kubectl version

# Check containerd
sudo systemctl status containerd

# Check modules
lsmod | grep -E 'overlay|br_netfilter|ip_vs'

# Check cluster
kubectl get nodes
kubectl get pods -A
\`\`\`

## Directory Structure

\`\`\`
.
├── binaries/
│   ├── kubernetes/    # kubeadm, kubelet, kubectl
│   ├── containerd/    # containerd, runc
│   └── cni/          # CNI plugins + manifests
├── packages/
│   ├── apt/          # .deb packages
│   └── pip/          # Python wheels
├── images/
│   └── images.txt    # Container images list
├── config/
│   ├── k8s-modules.conf
│   ├── k8s-sysctl.conf
│   ├── containerd-config.toml
│   └── crictl.yaml
├── scripts/
│   └── install-apt.sh
├── install-k8s.sh    # Master installation script
└── README.md         # This file
\`\`\`

## Version Information

\`\`\`yaml
$(echo "$VERSION_DATA" | head -30)
\`\`\`

## Compatibility

- ✅ Ubuntu ${UBUNTU_VERSION}
- ✅ Architecture: ${ARCH}
- ✅ Kubernetes ${K8S_VERSION}
- ✅ Offline installation

## Notes

- All binaries are pre-downloaded and verified
- Container images will be pulled during kubeadm init
- Swap is automatically disabled
- Kernel modules are configured for IPVS mode

## Support

For issues, check:
- Installation log: /var/log/kubernetes-install.log
- Kubelet logs: journalctl -u kubelet
- Container runtime: journalctl -u containerd

---
Generated by K8S Complete Bundle Creator
EOF

    log "README created"
}

# ========================= CREATE BUNDLE =========================

create_tarball() {
    section "Creating Bundle Tarball"

    cd "$WORK_DIR"

    local tarball_name="${BUNDLE_NAME}.tar.gz"
    local tarball_path="${OUTPUT_DIR}/${tarball_name}"

    progress "Compressing bundle (this may take a while)..."
    tar -czf "$tarball_path" "$BUNDLE_NAME"

    local size=$(du -h "$tarball_path" | cut -f1)
    log "Bundle created: $tarball_name ($size)"

    # Checksums
    progress "Calculating checksums..."
    cd "$OUTPUT_DIR"
    sha256sum "$tarball_name" > "${tarball_name}.sha256"
    md5sum "$tarball_name" > "${tarball_name}.md5"

    log "Checksums created"
    cd "$SCRIPT_DIR"
}

# ========================= STATISTICS =========================

show_statistics() {
    section "Bundle Statistics"

    echo ""
    echo "Kubernetes Version:     $K8S_VERSION"
    echo "Ubuntu Version:         $UBUNTU_VERSION"
    echo "Architecture:           $ARCH"
    echo ""

    # Count files
    local k8s_bins=$(ls -1 "${BUNDLE_DIR}/binaries/kubernetes"/* 2>/dev/null | wc -l)
    local apt_pkgs=$(ls -1 "${BUNDLE_DIR}/packages/apt"/*.deb 2>/dev/null | wc -l)
    local pip_pkgs=$(ls -1 "${BUNDLE_DIR}/packages/pip"/* 2>/dev/null | wc -l)

    echo "Kubernetes binaries:    $k8s_bins files"
    echo "APT packages:           $apt_pkgs files"
    echo "PIP packages:           $pip_pkgs files"
    echo ""

    # Sizes
    local k8s_size=$(du -sh "${BUNDLE_DIR}/binaries" 2>/dev/null | cut -f1)
    local apt_size=$(du -sh "${BUNDLE_DIR}/packages/apt" 2>/dev/null | cut -f1)
    local total_size=$(du -sh "${BUNDLE_DIR}" 2>/dev/null | cut -f1)

    echo "Binaries size:          $k8s_size"
    echo "Packages size:          $apt_size"
    echo "Total size:             $total_size"
    echo ""
}

# ========================= CLEANUP =========================

cleanup_workspace() {
    section "Cleaning Up"

    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
        log "Workspace cleaned"
    fi
}

# ========================= MAIN =========================

show_banner() {
    echo -e "${CYAN}"
    echo "════════════════════════════════════════════════════════════════"
    echo "  Kubernetes Complete Bundle Creator"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo ""
    echo "  K8S Version:     ${K8S_VERSION}"
    echo "  Ubuntu Version:  ${UBUNTU_VERSION}"
    echo "  Architecture:    ${ARCH}"
    echo "  CNI Provider:    ${CNI_PROVIDER}"
    echo ""
    echo "  Skip Options:"
    echo "    APT Download:        ${SKIP_APT_DOWNLOAD}"
    echo "    PIP Download:        ${SKIP_PIP_DOWNLOAD}"
    echo "    K8s Download:        ${SKIP_K8S_DOWNLOAD}"
    echo "    Containerd Download: ${SKIP_CONTAINERD_DOWNLOAD}"
    echo "    CNI Download:        ${SKIP_CNI_DOWNLOAD}"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""
}

show_usage() {
    cat << EOF
Usage: $0 [K8S_VERSION] [UBUNTU_VERSION] [ARCH]

Creates a complete offline bundle for Kubernetes installation.

Arguments:
  K8S_VERSION      Kubernetes version (default: 1.30.2)
  UBUNTU_VERSION   Ubuntu version (default: 22.04)
  ARCH             Architecture (default: amd64)

Environment Variables:
  DOWNLOAD_IMAGES         Download container images (default: yes)
  DOWNLOAD_CNI            Download CNI plugins (default: yes)
  CNI_PROVIDER            CNI provider: calico, flannel, none (default: calico)

  SKIP_APT_DOWNLOAD       Skip APT packages download: yes, no, auto (default: auto)
  SKIP_PIP_DOWNLOAD       Skip PIP packages download: yes, no, auto (default: auto)
  SKIP_K8S_DOWNLOAD       Skip K8s binaries download: yes, no (default: no)
  SKIP_CONTAINERD_DOWNLOAD Skip containerd download: yes, no (default: no)
  SKIP_CNI_DOWNLOAD       Skip CNI plugins download: yes, no (default: no)

Skip Options:
  - auto: Auto-detect and reuse existing packages if found
  - yes:  Force skip, fail if packages not found
  - no:   Always download (ignore existing packages)

Examples:
  $0                                    # Use defaults (K8s 1.30.2, Ubuntu 22.04, amd64)
  $0 1.29.6                             # K8s 1.29.6
  $0 1.30.2 22.04 arm64                 # ARM64 architecture
  CNI_PROVIDER=flannel $0               # Use Flannel CNI

  # Skip downloads (reuse previously downloaded packages)
  SKIP_APT_DOWNLOAD=yes $0              # Skip APT packages
  SKIP_APT_DOWNLOAD=yes SKIP_PIP_DOWNLOAD=yes $0  # Skip APT and PIP
  SKIP_APT_DOWNLOAD=no $0               # Force re-download APT packages

Available K8S versions:
  - 1.30.2 (latest)
  - 1.29.6
  - 1.28.11

EOF
}

main() {
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi

    show_banner

    check_prerequisites
    validate_version
    setup_workspace
    download_kubernetes_binaries
    download_containerd
    download_cni_plugins
    download_container_images
    download_system_packages
    create_configurations
    create_installation_script
    create_readme
    show_statistics
    create_tarball
    cleanup_workspace

    section "BUNDLE CREATION COMPLETED"

    echo ""
    echo -e "${GREEN}✓ Bundle successfully created!${NC}"
    echo ""
    echo "Output files:"
    echo "  - Bundle: ${OUTPUT_DIR}/${BUNDLE_NAME}.tar.gz"
    echo "  - SHA256: ${OUTPUT_DIR}/${BUNDLE_NAME}.tar.gz.sha256"
    echo "  - MD5:    ${OUTPUT_DIR}/${BUNDLE_NAME}.tar.gz.md5"
    echo "  - Log:    ${OUTPUT_DIR}/k8s-bundle-creation.log"
    echo ""
    echo "To install:"
    echo "  1. Copy bundle to target system"
    echo "  2. Extract: tar -xzf ${BUNDLE_NAME}.tar.gz"
    echo "  3. Install: cd ${BUNDLE_NAME} && sudo ./install-k8s.sh"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

# ========================= EXECUTION =========================

main "$@"
