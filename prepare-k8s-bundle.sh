#!/bin/bash

# ============================================================================
# K8S ISO Bundle Preparation Script
# ============================================================================
# Prepara un tar.gz con todos los paquetes y configuraciones necesarias
# para una ISO custom de Kubernetes basada en Ubuntu Server
# ============================================================================

set -e
set -o pipefail

# ========================= CONFIGURATION =========================

BUNDLE_NAME="k8s-offline-bundle"
BUNDLE_VERSION="1.0.0"
WORK_DIR="./bundle-workspace"
OUTPUT_DIR="./bundle-output"
BUNDLE_DIR="${WORK_DIR}/${BUNDLE_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Log file
LOG_FILE="${OUTPUT_DIR}/bundle-preparation.log"

# ========================= APT PACKAGES =========================

APT_PACKAGES=(
    "cron"
    "dmidecode"
    "ebtables=2.0.11*"
    "ethtool"
    "ipmitool"
    "iputils-ping"
    "ipvsadm=1:1.31*"
    "iptables=1.8*"
    "jq=1.6-2*"
    "lsof"
    "multipath-tools=0.8.8*"
    "network-manager"
    "nfs-common=1:2.6.1*"
    "nftables"
    "open-iscsi"
    "python3-pip"
    "rsyslog"
    "s3cmd=2.2.0-1"
    "sysstat"
    "tcpdump"
    "ufw"
    "vim"
    "lldpd"
)

# ========================= PIP PACKAGES =========================

PIP_PACKAGES=(
    "jc"
)

# ========================= KERNEL MODULES =========================

KERNEL_MODULES=(
    "ip_vs"
    "ip_vs_rr"
    "ip_vs_wrr"
    "ip_vs_sh"
    "ip_vs_wlc"
    "ip_vs_lc"
    "nf_conntrack"
    "nvme_tcp"
)

# ========================= LOGGING FUNCTIONS =========================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ INFO: $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

progress() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] ⚙ $1${NC}" | tee -a "$LOG_FILE"
}

section() {
    echo -e "${CYAN}" | tee -a "$LOG_FILE"
    echo -e "═══════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo -e "  $1" | tee -a "$LOG_FILE"
    echo -e "═══════════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
}

# ========================= VALIDATION FUNCTIONS =========================

check_prerequisites() {
    section "Checking Prerequisites"

    local missing_deps=()

    # Check for required scripts
    if [[ ! -f "${SCRIPT_DIR}/download-apt.sh" ]]; then
        missing_deps+=("download-apt.sh not found in ${SCRIPT_DIR}")
    fi

    if [[ ! -f "${SCRIPT_DIR}/download-pip.sh" ]]; then
        missing_deps+=("download-pip.sh not found in ${SCRIPT_DIR}")
    fi

    # Check for required commands
    local required_commands=("tar" "gzip" "apt-cache" "dpkg")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing prerequisites:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi

    log "All prerequisites met"
}

# ========================= SETUP FUNCTIONS =========================

setup_workspace() {
    section "Setting Up Workspace"

    # Clean previous workspace if exists
    if [[ -d "$WORK_DIR" ]]; then
        warning "Removing previous workspace: $WORK_DIR"
        rm -rf "$WORK_DIR"
    fi

    # Create directory structure
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$BUNDLE_DIR"/{packages/{apt,pip},scripts,config,modules}

    # Initialize log file
    : > "$LOG_FILE"

    log "Workspace created at: $WORK_DIR"
    log "Output directory: $OUTPUT_DIR"
}

# ========================= DOWNLOAD FUNCTIONS =========================

download_apt_packages() {
    section "Downloading APT Packages"

    info "Packages to download: ${#APT_PACKAGES[@]}"

    # Copy download script
    cp "${SCRIPT_DIR}/download-apt.sh" "$WORK_DIR/"
    chmod +x "$WORK_DIR/download-apt.sh"

    cd "$WORK_DIR"

    # Download packages
    progress "Executing download-apt.sh..."
    if ./download-apt.sh "${APT_PACKAGES[@]}" >> "$LOG_FILE" 2>&1; then
        log "APT packages downloaded successfully"
    else
        error "Failed to download APT packages"
        exit 1
    fi

    # Move packages to bundle directory
    if [[ -d "./offline_dpkg_packages" ]]; then
        progress "Moving APT packages to bundle..."
        mv ./offline_dpkg_packages/*.deb "${BUNDLE_DIR}/packages/apt/" 2>/dev/null || true

        # Also copy the installation scripts generated
        if [[ -f "./offline_dpkg_packages/install.sh" ]]; then
            cp ./offline_dpkg_packages/install.sh "${BUNDLE_DIR}/scripts/install-apt.sh"
        fi

        if [[ -f "./offline_dpkg_packages/verify.sh" ]]; then
            cp ./offline_dpkg_packages/verify.sh "${BUNDLE_DIR}/scripts/verify-apt.sh"
        fi

        # Count packages
        local deb_count=$(ls -1 "${BUNDLE_DIR}/packages/apt/"*.deb 2>/dev/null | wc -l || echo "0")
        log "Moved $deb_count .deb packages to bundle"

        # Clean up
        rm -rf ./offline_dpkg_packages
    else
        error "APT packages directory not found"
        exit 1
    fi

    cd "$SCRIPT_DIR"
}

download_pip_packages() {
    section "Downloading PIP Packages"

    info "Packages to download: ${#PIP_PACKAGES[@]}"

    # Copy download script
    cp "${SCRIPT_DIR}/download-pip.sh" "$WORK_DIR/"
    chmod +x "$WORK_DIR/download-pip.sh"

    cd "$WORK_DIR"

    # Download packages
    progress "Executing download-pip.sh..."
    if ./download-pip.sh "${PIP_PACKAGES[@]}" >> "$LOG_FILE" 2>&1; then
        log "PIP packages downloaded successfully"
    else
        error "Failed to download PIP packages"
        exit 1
    fi

    # Move packages to bundle directory
    if [[ -d "./offline_pip_packages" ]]; then
        progress "Moving PIP packages to bundle..."
        mv ./offline_pip_packages/*.whl "${BUNDLE_DIR}/packages/pip/" 2>/dev/null || true
        mv ./offline_pip_packages/*.tar.gz "${BUNDLE_DIR}/packages/pip/" 2>/dev/null || true
        mv ./offline_pip_packages/*.zip "${BUNDLE_DIR}/packages/pip/" 2>/dev/null || true

        # Copy installation scripts
        if [[ -f "./offline_pip_packages/install_offline.sh" ]]; then
            cp ./offline_pip_packages/install_offline.sh "${BUNDLE_DIR}/scripts/install-pip.sh"
        fi

        # Count packages
        local pip_count=$(ls -1 "${BUNDLE_DIR}/packages/pip/" 2>/dev/null | wc -l || echo "0")
        log "Moved $pip_count pip packages to bundle"

        # Clean up
        rm -rf ./offline_pip_packages
    else
        error "PIP packages directory not found"
        exit 1
    fi

    cd "$SCRIPT_DIR"
}

# ========================= CONFIGURATION FUNCTIONS =========================

create_kernel_modules_config() {
    section "Creating Kernel Modules Configuration"

    local modules_conf="${BUNDLE_DIR}/config/k8s-modules.conf"

    cat > "$modules_conf" << 'EOF'
# Kubernetes required kernel modules
# Auto-generated configuration

# IP Virtual Server modules (required for kube-proxy IPVS mode)
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
ip_vs_wlc
ip_vs_lc

# Connection tracking (required for networking)
nf_conntrack

# NVMe over TCP (required for storage)
nvme_tcp
EOF

    log "Kernel modules config created: $modules_conf"

    # Create modules load script
    local modules_script="${BUNDLE_DIR}/scripts/load-kernel-modules.sh"

    cat > "$modules_script" << 'EOF'
#!/bin/bash
# Load Kubernetes required kernel modules

set -e

MODULES_CONF="/etc/modules-load.d/k8s-modules.conf"

echo "[INFO] Loading Kubernetes kernel modules..."

# Copy modules configuration
if [[ -f "$(dirname "$0")/../config/k8s-modules.conf" ]]; then
    cp "$(dirname "$0")/../config/k8s-modules.conf" "$MODULES_CONF"
    echo "[INFO] Modules configuration installed to $MODULES_CONF"
fi

# Load modules immediately
while IFS= read -r module; do
    # Skip comments and empty lines
    [[ "$module" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$module" ]] && continue

    module=$(echo "$module" | xargs) # trim whitespace

    if ! lsmod | grep -q "^${module}"; then
        echo "[INFO] Loading module: $module"
        modprobe "$module" || echo "[WARNING] Failed to load module: $module"
    else
        echo "[INFO] Module already loaded: $module"
    fi
done < "$MODULES_CONF"

echo "[SUCCESS] Kernel modules loaded"
EOF

    chmod +x "$modules_script"
    log "Kernel modules load script created"
}

create_sysctl_config() {
    section "Creating Sysctl Configuration"

    local sysctl_conf="${BUNDLE_DIR}/config/k8s-sysctl.conf"

    cat > "$sysctl_conf" << 'EOF'
# Kubernetes required sysctl settings
# Auto-generated configuration

# Enable IP forwarding (required for networking)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Bridge netfilter settings (required for iptables to see bridged traffic)
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Connection tracking
net.netfilter.nf_conntrack_max = 1000000

# IPv4 settings
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable swap (Kubernetes requirement)
vm.swappiness = 0

# File system settings
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Network performance
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 16384
EOF

    log "Sysctl config created: $sysctl_conf"

    # Create sysctl apply script
    local sysctl_script="${BUNDLE_DIR}/scripts/apply-sysctl.sh"

    cat > "$sysctl_script" << 'EOF'
#!/bin/bash
# Apply Kubernetes sysctl settings

set -e

SYSCTL_CONF="/etc/sysctl.d/99-k8s.conf"

echo "[INFO] Applying Kubernetes sysctl settings..."

# Copy sysctl configuration
if [[ -f "$(dirname "$0")/../config/k8s-sysctl.conf" ]]; then
    cp "$(dirname "$0")/../config/k8s-sysctl.conf" "$SYSCTL_CONF"
    echo "[INFO] Sysctl configuration installed to $SYSCTL_CONF"
fi

# Apply settings
sysctl --system

echo "[SUCCESS] Sysctl settings applied"
EOF

    chmod +x "$sysctl_script"
    log "Sysctl apply script created"
}

create_master_install_script() {
    section "Creating Master Installation Script"

    local master_script="${BUNDLE_DIR}/install.sh"

    cat > "$master_script" << 'EOF'
#!/bin/bash

# ============================================================================
# K8S Offline Bundle - Master Installation Script
# ============================================================================
# This script installs all packages and configurations from the offline bundle
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓] $1${NC}"; }
error() { echo -e "${RED}[✗] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[ℹ] $1${NC}"; }
warning() { echo -e "${YELLOW}[⚠] $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

echo -e "${BLUE}"
echo "════════════════════════════════════════════════════════════════"
echo "  K8S Offline Bundle Installation"
echo "════════════════════════════════════════════════════════════════"
echo -e "${NC}"

# ========================= STEP 1: APT PACKAGES =========================

info "Step 1/5: Installing APT packages..."

if [[ -f "$SCRIPT_DIR/scripts/install-apt.sh" ]]; then
    cd "$SCRIPT_DIR/packages/apt"
    bash "$SCRIPT_DIR/scripts/install-apt.sh"
    log "APT packages installed"
else
    warning "APT installation script not found, skipping..."
fi

# ========================= STEP 2: PIP PACKAGES =========================

info "Step 2/5: Installing PIP packages..."

if [[ -f "$SCRIPT_DIR/scripts/install-pip.sh" ]]; then
    cd "$SCRIPT_DIR/packages/pip"
    bash "$SCRIPT_DIR/scripts/install-pip.sh"
    log "PIP packages installed"
else
    warning "PIP installation script not found, skipping..."
fi

# ========================= STEP 3: KERNEL MODULES =========================

info "Step 3/5: Configuring kernel modules..."

if [[ -f "$SCRIPT_DIR/scripts/load-kernel-modules.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/load-kernel-modules.sh"
    log "Kernel modules configured"
else
    warning "Kernel modules script not found, skipping..."
fi

# ========================= STEP 4: SYSCTL SETTINGS =========================

info "Step 4/5: Applying sysctl settings..."

if [[ -f "$SCRIPT_DIR/scripts/apply-sysctl.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/apply-sysctl.sh"
    log "Sysctl settings applied"
else
    warning "Sysctl script not found, skipping..."
fi

# ========================= STEP 5: DISABLE SWAP =========================

info "Step 5/5: Disabling swap (Kubernetes requirement)..."

if swapon --show | grep -q '/'; then
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
    log "Swap disabled"
else
    info "Swap already disabled"
fi

# ========================= VERIFICATION =========================

echo ""
info "Running verification checks..."

# Check modules
info "Loaded kernel modules:"
for module in ip_vs ip_vs_rr ip_vs_wrr nf_conntrack nvme_tcp; do
    if lsmod | grep -q "^${module}"; then
        echo "  ✓ $module"
    else
        echo "  ✗ $module (not loaded)"
    fi
done

# Check sysctl
info "Key sysctl settings:"
for setting in net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables; do
    value=$(sysctl -n "$setting" 2>/dev/null || echo "N/A")
    echo "  $setting = $value"
done

# Check swap
if swapon --show | grep -q '/'; then
    warning "Swap is still enabled!"
else
    echo "  ✓ Swap disabled"
fi

echo ""
echo -e "${GREEN}"
echo "════════════════════════════════════════════════════════════════"
echo "  Installation Completed Successfully!"
echo "════════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo ""
info "Your system is now prepared for Kubernetes installation"
info "Next steps:"
echo "  1. Install container runtime (containerd/crio)"
echo "  2. Install kubeadm, kubelet, kubectl"
echo "  3. Initialize cluster with: kubeadm init"
echo ""
EOF

    chmod +x "$master_script"
    log "Master installation script created"
}

create_bundle_readme() {
    section "Creating Bundle Documentation"

    local readme="${BUNDLE_DIR}/README.md"

    cat > "$readme" << EOF
# K8S Offline Bundle

**Version:** ${BUNDLE_VERSION}
**Created:** $(date '+%Y-%m-%d %H:%M:%S')
**System:** $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")

## Contents

This bundle contains all necessary packages and configurations to prepare a system for Kubernetes installation in an offline environment.

### Included Packages

#### APT Packages (${#APT_PACKAGES[@]} packages)
\`\`\`
$(printf '%s\n' "${APT_PACKAGES[@]}")
\`\`\`

#### PIP Packages (${#PIP_PACKAGES[@]} packages)
\`\`\`
$(printf '%s\n' "${PIP_PACKAGES[@]}")
\`\`\`

### Kernel Modules Configured
\`\`\`
$(printf '%s\n' "${KERNEL_MODULES[@]}")
\`\`\`

## Installation

### Quick Install
\`\`\`bash
sudo ./install.sh
\`\`\`

### Manual Installation

#### 1. Install APT packages
\`\`\`bash
cd packages/apt
sudo bash ../../scripts/install-apt.sh
\`\`\`

#### 2. Install PIP packages
\`\`\`bash
cd packages/pip
sudo bash ../../scripts/install-pip.sh
\`\`\`

#### 3. Configure kernel modules
\`\`\`bash
sudo bash scripts/load-kernel-modules.sh
\`\`\`

#### 4. Apply sysctl settings
\`\`\`bash
sudo bash scripts/apply-sysctl.sh
\`\`\`

## Directory Structure

\`\`\`
${BUNDLE_NAME}/
├── install.sh              # Master installation script
├── README.md              # This file
├── packages/
│   ├── apt/              # .deb packages
│   └── pip/              # Python wheels
├── scripts/
│   ├── install-apt.sh    # APT packages installer
│   ├── install-pip.sh    # PIP packages installer
│   ├── load-kernel-modules.sh
│   ├── apply-sysctl.sh
│   └── verify-*.sh       # Verification scripts
└── config/
    ├── k8s-modules.conf  # Kernel modules config
    └── k8s-sysctl.conf   # Sysctl settings
\`\`\`

## Verification

After installation, verify:

1. **Kernel modules loaded:**
   \`\`\`bash
   lsmod | grep -E 'ip_vs|nf_conntrack|nvme_tcp'
   \`\`\`

2. **Sysctl settings applied:**
   \`\`\`bash
   sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
   \`\`\`

3. **Swap disabled:**
   \`\`\`bash
   swapon --show  # Should return empty
   \`\`\`

4. **Packages installed:**
   \`\`\`bash
   dpkg -l | grep -E 'jq|ipvsadm|iptables'
   pip3 list | grep jc
   \`\`\`

## Integration with Cubic

To integrate this bundle into a custom ISO using Cubic:

1. Extract the bundle in the chroot environment:
   \`\`\`bash
   tar -xzf k8s-offline-bundle-${BUNDLE_VERSION}.tar.gz -C /opt/
   \`\`\`

2. Run the installation script:
   \`\`\`bash
   cd /opt/${BUNDLE_NAME}
   ./install.sh
   \`\`\`

3. Clean up (optional):
   \`\`\`bash
   rm -rf /opt/${BUNDLE_NAME}
   \`\`\`

## Compatibility

- **Ubuntu Server:** 20.04, 22.04, 24.04
- **Kubernetes:** 1.28+
- **Architecture:** amd64

## Notes

- All packages are downloaded with their dependencies
- Installation is idempotent (safe to run multiple times)
- No internet connection required during installation
- Swap will be permanently disabled

## Support

For issues or questions, check the installation logs and verify all prerequisites are met.

---
Generated by: K8S ISO Bundle Preparation Script
EOF

    log "README.md created"
}

# ========================= BUNDLE CREATION =========================

create_tarball() {
    section "Creating Bundle Tarball"

    cd "$WORK_DIR"

    local tarball_name="${BUNDLE_NAME}-${BUNDLE_VERSION}.tar.gz"
    local tarball_path="${OUTPUT_DIR}/${tarball_name}"

    progress "Compressing bundle..."
    tar -czf "$tarball_path" "$BUNDLE_NAME"

    local tarball_size=$(du -h "$tarball_path" | cut -f1)
    log "Bundle created: $tarball_name"
    log "Size: $tarball_size"

    # Calculate checksum
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

    local apt_count=$(ls -1 "${BUNDLE_DIR}/packages/apt/"*.deb 2>/dev/null | wc -l || echo "0")
    local pip_count=$(ls -1 "${BUNDLE_DIR}/packages/pip/" 2>/dev/null | wc -l || echo "0")
    local scripts_count=$(ls -1 "${BUNDLE_DIR}/scripts/"*.sh 2>/dev/null | wc -l || echo "0")
    local configs_count=$(ls -1 "${BUNDLE_DIR}/config/"*.conf 2>/dev/null | wc -l || echo "0")

    local apt_size=$(du -sh "${BUNDLE_DIR}/packages/apt" 2>/dev/null | cut -f1 || echo "0")
    local pip_size=$(du -sh "${BUNDLE_DIR}/packages/pip" 2>/dev/null | cut -f1 || echo "0")
    local total_size=$(du -sh "${BUNDLE_DIR}" 2>/dev/null | cut -f1 || echo "0")

    echo ""
    echo "APT Packages:     $apt_count files ($apt_size)"
    echo "PIP Packages:     $pip_count files ($pip_size)"
    echo "Scripts:          $scripts_count files"
    echo "Configurations:   $configs_count files"
    echo "Kernel Modules:   ${#KERNEL_MODULES[@]} modules"
    echo ""
    echo "Total Size:       $total_size"
    echo ""
}

# ========================= CLEANUP =========================

cleanup_workspace() {
    section "Cleaning Up Workspace"

    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
        log "Workspace cleaned"
    fi
}

# ========================= MAIN FUNCTION =========================

main() {
    echo -e "${CYAN}"
    echo "════════════════════════════════════════════════════════════════"
    echo "  K8S Offline Bundle Preparation Script"
    echo "  Version: ${BUNDLE_VERSION}"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo ""

    check_prerequisites
    setup_workspace
    download_apt_packages
    download_pip_packages
    create_kernel_modules_config
    create_sysctl_config
    create_master_install_script
    create_bundle_readme
    show_statistics
    create_tarball
    cleanup_workspace

    section "BUNDLE PREPARATION COMPLETED"

    echo ""
    echo -e "${GREEN}✓ Bundle successfully created!${NC}"
    echo ""
    echo "Output files:"
    echo "  - Bundle: ${OUTPUT_DIR}/${BUNDLE_NAME}-${BUNDLE_VERSION}.tar.gz"
    echo "  - SHA256: ${OUTPUT_DIR}/${BUNDLE_NAME}-${BUNDLE_VERSION}.tar.gz.sha256"
    echo "  - MD5:    ${OUTPUT_DIR}/${BUNDLE_NAME}-${BUNDLE_VERSION}.tar.gz.md5"
    echo "  - Log:    ${OUTPUT_DIR}/bundle-preparation.log"
    echo ""
    echo "To use with Cubic:"
    echo "  1. Copy the tar.gz to your ISO workspace"
    echo "  2. Extract in chroot: tar -xzf ${BUNDLE_NAME}-${BUNDLE_VERSION}.tar.gz -C /opt/"
    echo "  3. Install: cd /opt/${BUNDLE_NAME} && ./install.sh"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

# ========================= EXECUTION =========================

main "$@"
