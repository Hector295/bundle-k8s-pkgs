#!/bin/bash

# ============================================================================
# K8S Bundle Verification Script
# ============================================================================
# Verifica la integridad y contenido de un bundle K8S antes de usarlo
# ============================================================================

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log() { echo -e "${GREEN}[✓] $1${NC}"; }
error() { echo -e "${RED}[✗] $1${NC}"; }
info() { echo -e "${BLUE}[ℹ] $1${NC}"; }
warning() { echo -e "${YELLOW}[⚠] $1${NC}"; }
section() { echo -e "${CYAN}━━━ $1 ━━━${NC}"; }

# ========================= CONFIGURATION =========================

BUNDLE_PATH="${1:-bundle-output/k8s-offline-bundle-*.tar.gz}"
TEMP_VERIFY_DIR="/tmp/k8s-bundle-verify-$$"

# ========================= FUNCTIONS =========================

cleanup() {
    if [[ -d "$TEMP_VERIFY_DIR" ]]; then
        rm -rf "$TEMP_VERIFY_DIR"
    fi
}

trap cleanup EXIT

verify_checksum() {
    section "Checksum Verification"

    if [[ -f "${BUNDLE_FILE}.sha256" ]]; then
        info "Verifying SHA256 checksum..."
        if sha256sum -c "${BUNDLE_FILE}.sha256" 2>/dev/null; then
            log "SHA256 checksum valid"
        else
            error "SHA256 checksum verification failed!"
            return 1
        fi
    else
        warning "SHA256 checksum file not found"
    fi

    if [[ -f "${BUNDLE_FILE}.md5" ]]; then
        info "Verifying MD5 checksum..."
        if md5sum -c "${BUNDLE_FILE}.md5" 2>/dev/null; then
            log "MD5 checksum valid"
        else
            error "MD5 checksum verification failed!"
            return 1
        fi
    else
        warning "MD5 checksum file not found"
    fi

    echo ""
}

verify_structure() {
    section "Bundle Structure Verification"

    info "Extracting bundle to temporary location..."
    mkdir -p "$TEMP_VERIFY_DIR"
    tar -xzf "$BUNDLE_FILE" -C "$TEMP_VERIFY_DIR"

    local bundle_dir=$(find "$TEMP_VERIFY_DIR" -maxdepth 1 -type d -name "k8s-offline-bundle*" | head -1)

    if [[ -z "$bundle_dir" ]]; then
        error "Bundle directory not found after extraction"
        return 1
    fi

    cd "$bundle_dir"

    # Check required files and directories
    local required_items=(
        "install.sh"
        "README.md"
        "packages/apt"
        "packages/pip"
        "scripts/install-apt.sh"
        "scripts/install-pip.sh"
        "scripts/load-kernel-modules.sh"
        "scripts/apply-sysctl.sh"
        "config/k8s-modules.conf"
        "config/k8s-sysctl.conf"
    )

    local missing_items=()

    for item in "${required_items[@]}"; do
        if [[ ! -e "$item" ]]; then
            missing_items+=("$item")
        fi
    done

    if [[ ${#missing_items[@]} -gt 0 ]]; then
        error "Missing required items:"
        for item in "${missing_items[@]}"; do
            echo "  - $item"
        done
        return 1
    else
        log "All required files and directories present"
    fi

    echo ""
}

verify_packages() {
    section "Package Verification"

    local bundle_dir=$(find "$TEMP_VERIFY_DIR" -maxdepth 1 -type d -name "k8s-offline-bundle*" | head -1)
    cd "$bundle_dir"

    # Check APT packages
    local apt_count=$(find packages/apt -name "*.deb" 2>/dev/null | wc -l)
    if [[ $apt_count -gt 0 ]]; then
        log "Found $apt_count APT packages (.deb)"

        info "Verifying .deb package integrity..."
        local corrupted=0
        while IFS= read -r deb; do
            if ! dpkg-deb --info "$deb" &>/dev/null; then
                warning "Corrupted package: $(basename "$deb")"
                corrupted=$((corrupted + 1))
            fi
        done < <(find packages/apt -name "*.deb")

        if [[ $corrupted -eq 0 ]]; then
            log "All .deb packages are valid"
        else
            warning "$corrupted corrupted .deb packages found"
        fi
    else
        warning "No APT packages found"
    fi

    # Check PIP packages
    local pip_count=$(find packages/pip -type f 2>/dev/null | wc -l)
    if [[ $pip_count -gt 0 ]]; then
        log "Found $pip_count PIP packages"
    else
        warning "No PIP packages found"
    fi

    echo ""
}

verify_scripts() {
    section "Script Verification"

    local bundle_dir=$(find "$TEMP_VERIFY_DIR" -maxdepth 1 -type d -name "k8s-offline-bundle*" | head -1)
    cd "$bundle_dir"

    info "Checking script executability..."

    local scripts=(
        "install.sh"
        "scripts/install-apt.sh"
        "scripts/install-pip.sh"
        "scripts/load-kernel-modules.sh"
        "scripts/apply-sysctl.sh"
    )

    local non_executable=()

    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                echo "  ✓ $(basename "$script") is executable"
            else
                non_executable+=("$script")
            fi
        fi
    done

    if [[ ${#non_executable[@]} -gt 0 ]]; then
        warning "Non-executable scripts found:"
        for script in "${non_executable[@]}"; do
            echo "  - $script"
        done
        info "This might cause issues during installation"
    else
        log "All scripts are executable"
    fi

    echo ""
}

verify_configs() {
    section "Configuration Verification"

    local bundle_dir=$(find "$TEMP_VERIFY_DIR" -maxdepth 1 -type d -name "k8s-offline-bundle*" | head -1)
    cd "$bundle_dir"

    # Check kernel modules config
    if [[ -f "config/k8s-modules.conf" ]]; then
        local module_count=$(grep -v '^#' config/k8s-modules.conf | grep -v '^$' | wc -l)
        log "Kernel modules config: $module_count modules defined"

        info "Modules to load:"
        grep -v '^#' config/k8s-modules.conf | grep -v '^$' | while read module; do
            echo "  - $module"
        done
    else
        error "Kernel modules config not found"
    fi

    echo ""

    # Check sysctl config
    if [[ -f "config/k8s-sysctl.conf" ]]; then
        local sysctl_count=$(grep -E '^[^#].*=' config/k8s-sysctl.conf | wc -l)
        log "Sysctl config: $sysctl_count settings defined"

        info "Key sysctl settings:"
        grep -E '^net\.(ipv4\.ip_forward|bridge\.bridge-nf-call-iptables)' config/k8s-sysctl.conf || true
    else
        error "Sysctl config not found"
    fi

    echo ""
}

show_summary() {
    section "Bundle Summary"

    local bundle_dir=$(find "$TEMP_VERIFY_DIR" -maxdepth 1 -type d -name "k8s-offline-bundle*" | head -1)
    cd "$bundle_dir"

    echo "Bundle: $(basename "$BUNDLE_FILE")"
    echo "Size: $(du -sh "$BUNDLE_FILE" | cut -f1)"
    echo ""

    # Package counts
    local apt_count=$(find packages/apt -name "*.deb" 2>/dev/null | wc -l || echo "0")
    local pip_count=$(find packages/pip -type f 2>/dev/null | wc -l || echo "0")
    local script_count=$(find scripts -name "*.sh" 2>/dev/null | wc -l || echo "0")
    local config_count=$(find config -name "*.conf" 2>/dev/null | wc -l || echo "0")

    echo "Contents:"
    echo "  APT Packages: $apt_count"
    echo "  PIP Packages: $pip_count"
    echo "  Scripts: $script_count"
    echo "  Configs: $config_count"
    echo ""

    # Disk usage
    local apt_size=$(du -sh packages/apt 2>/dev/null | cut -f1 || echo "0")
    local pip_size=$(du -sh packages/pip 2>/dev/null | cut -f1 || echo "0")

    echo "Disk Usage:"
    echo "  APT Packages: $apt_size"
    echo "  PIP Packages: $pip_size"
    echo ""

    # Version from README if available
    if [[ -f "README.md" ]]; then
        local version=$(grep "Version:" README.md | head -1 | cut -d: -f2 | xargs || echo "Unknown")
        local created=$(grep "Created:" README.md | head -1 | cut -d: -f2- | xargs || echo "Unknown")
        echo "Version: $version"
        echo "Created: $created"
    fi

    echo ""
}

list_packages() {
    section "Detailed Package List"

    local bundle_dir=$(find "$TEMP_VERIFY_DIR" -maxdepth 1 -type d -name "k8s-offline-bundle*" | head -1)
    cd "$bundle_dir"

    info "APT Packages:"
    if [[ -d "packages/apt" ]]; then
        find packages/apt -name "*.deb" -exec basename {} \; | sort | sed 's/^/  - /'
    fi
    echo ""

    info "PIP Packages:"
    if [[ -d "packages/pip" ]]; then
        find packages/pip -type f -exec basename {} \; | sort | sed 's/^/  - /'
    fi
    echo ""
}

# ========================= MAIN =========================

main() {
    echo -e "${CYAN}"
    echo "════════════════════════════════════════════════════════════════"
    echo "  K8S Bundle Verification Tool"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo ""

    # Find bundle file
    BUNDLE_FILE=$(ls $BUNDLE_PATH 2>/dev/null | head -1)

    if [[ -z "$BUNDLE_FILE" ]]; then
        error "Bundle file not found: $BUNDLE_PATH"
        echo ""
        echo "Usage: $0 [bundle-path]"
        echo "Example: $0 bundle-output/k8s-offline-bundle-1.0.0.tar.gz"
        exit 1
    fi

    info "Verifying bundle: $(basename "$BUNDLE_FILE")"
    echo ""

    # Run verifications
    verify_checksum
    verify_structure
    verify_packages
    verify_scripts
    verify_configs
    show_summary

    # Ask if user wants detailed package list
    if [[ -t 0 ]]; then  # Check if running interactively
        echo ""
        read -p "Show detailed package list? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            list_packages
        fi
    fi

    echo ""
    echo -e "${GREEN}"
    echo "════════════════════════════════════════════════════════════════"
    echo "  Verification Complete!"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo ""
    log "Bundle appears to be valid and ready for use"
    echo ""
}

# ========================= EXECUTION =========================

main "$@"
