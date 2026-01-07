#!/bin/bash

# ============================================================================
# Example Automation Script
# ============================================================================
# Este script demuestra cómo automatizar el proceso completo de:
# 1. Crear el bundle
# 2. Verificarlo
# 3. Integrarlo en Cubic
# 4. Generar ISO final
#
# Úsalo como base para tus propios scripts de automatización/CI-CD
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓ $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ✗ ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ $1${NC}"; }
warning() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠ $1${NC}"; }
section() {
    echo -e "${CYAN}"
    echo "════════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

# ========================= CONFIGURATION =========================

# Rutas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_ISO="${1:-ubuntu-22.04-server-amd64.iso}"
OUTPUT_ISO="${2:-k8s-ubuntu-22.04-custom.iso}"
CUBIC_WORKSPACE="${HOME}/Cubic/k8s-automation"

# Opciones
AUTO_CLEANUP=${AUTO_CLEANUP:-yes}
SKIP_VERIFICATION=${SKIP_VERIFICATION:-no}
KEEP_BUNDLE_IN_ISO=${KEEP_BUNDLE_IN_ISO:-no}

# ========================= FUNCTIONS =========================

check_prerequisites() {
    section "Checking Prerequisites"

    local missing=()

    # Check commands
    for cmd in tar gzip sha256sum make; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    # Check scripts
    for script in prepare-k8s-bundle.sh verify-bundle.sh cubic-install-bundle.sh; do
        if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
            missing+=("$script")
        fi
    done

    # Check base ISO
    if [[ ! -f "$BASE_ISO" ]]; then
        missing+=("Base ISO: $BASE_ISO")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing prerequisites: ${missing[*]}"
    fi

    log "All prerequisites met"
}

create_bundle() {
    section "Step 1: Creating K8S Bundle"

    cd "$SCRIPT_DIR"

    info "Building bundle..."
    if make build; then
        log "Bundle created successfully"
    else
        error "Failed to create bundle"
    fi

    if [[ "$SKIP_VERIFICATION" != "yes" ]]; then
        info "Verifying bundle..."
        if make verify; then
            log "Bundle verification passed"
        else
            error "Bundle verification failed"
        fi
    fi

    # Get bundle info
    make show-info
}

setup_cubic_workspace() {
    section "Step 2: Setting Up Cubic Workspace"

    info "Cubic workspace: $CUBIC_WORKSPACE"

    # Note: Este paso normalmente requiere interacción con Cubic GUI
    # En un entorno automatizado, necesitarías usar Cubic en modo headless
    # o tener el workspace ya preparado

    if [[ ! -d "$CUBIC_WORKSPACE" ]]; then
        warning "Cubic workspace not found: $CUBIC_WORKSPACE"
        info "Please create Cubic project manually or use existing workspace"
        info "Then set: CUBIC_WORKSPACE=/path/to/cubic/project"
        exit 0
    fi

    log "Cubic workspace found"
}

copy_bundle_to_cubic() {
    section "Step 3: Copying Bundle to Cubic"

    local bundle_file=$(ls bundle-output/k8s-offline-bundle-*.tar.gz | head -1)
    local cubic_root="${CUBIC_WORKSPACE}/custom-root"

    if [[ ! -f "$bundle_file" ]]; then
        error "Bundle file not found"
    fi

    if [[ ! -d "$cubic_root" ]]; then
        error "Cubic root not found: $cubic_root"
    fi

    info "Copying bundle to Cubic..."
    cp "$bundle_file" "${cubic_root}/opt/"
    cp "${bundle_file}.sha256" "${cubic_root}/opt/" 2>/dev/null || true
    cp cubic-install-bundle.sh "${cubic_root}/opt/"

    log "Bundle copied to Cubic workspace"
}

create_cubic_automation_script() {
    section "Step 4: Creating Cubic Automation Script"

    local cubic_root="${CUBIC_WORKSPACE}/custom-root"
    local auto_script="${cubic_root}/tmp/install-k8s-bundle.sh"

    cat > "$auto_script" << 'EOF'
#!/bin/bash
# Auto-generated script for Cubic chroot execution

set -e

cd /opt

# Install bundle
if [[ -f "./cubic-install-bundle.sh" ]]; then
    bash ./cubic-install-bundle.sh /opt/k8s-offline-bundle-*.tar.gz no
else
    # Fallback: manual installation
    tar -xzf k8s-offline-bundle-*.tar.gz
    cd k8s-offline-bundle
    ./install.sh
    cd /opt
    rm -rf k8s-offline-bundle
fi

# Optional: Remove bundle from final ISO to save space
# Uncomment if you don't need it in the ISO
# rm -f /opt/k8s-offline-bundle-*.tar.gz

echo "K8S bundle installation completed"
EOF

    chmod +x "$auto_script"

    log "Cubic automation script created"
    info "Run this in Cubic chroot: bash /tmp/install-k8s-bundle.sh"
}

generate_installation_report() {
    section "Generating Installation Report"

    local report_file="installation-report-$(date +%Y%m%d-%H%M%S).txt"

    cat > "$report_file" << EOF
K8S Bundle Installation Report
==============================

Date: $(date)
Bundle: $(ls bundle-output/k8s-offline-bundle-*.tar.gz | head -1)
Base ISO: $BASE_ISO
Output ISO: $OUTPUT_ISO

Bundle Contents:
---------------
$(tar -tzf bundle-output/k8s-offline-bundle-*.tar.gz | head -30)

Bundle Size:
-----------
$(du -h bundle-output/k8s-offline-bundle-*.tar.gz)

Checksums:
---------
$(cat bundle-output/k8s-offline-bundle-*.tar.gz.sha256 2>/dev/null || echo "N/A")

Next Steps:
----------
1. Open Cubic and load the project at: $CUBIC_WORKSPACE
2. In Cubic chroot, run: bash /tmp/install-k8s-bundle.sh
3. Generate the final ISO
4. Test the ISO in a VM or physical machine

Verification Commands:
---------------------
# After booting from generated ISO
lsmod | grep ip_vs
sysctl net.ipv4.ip_forward
dpkg -l | grep jq
pip3 list | grep jc
swapon --show

Notes:
-----
- Bundle will be installed in /opt/ of the ISO
- All kernel modules will load on first boot
- Swap is disabled automatically
- Sysctl settings are persistent

EOF

    log "Report generated: $report_file"
    cat "$report_file"
}

cleanup() {
    if [[ "$AUTO_CLEANUP" == "yes" ]]; then
        section "Cleanup"

        info "Cleaning temporary files..."
        cd "$SCRIPT_DIR"
        make clean

        log "Cleanup complete"
    fi
}

show_summary() {
    section "Automation Complete!"

    echo ""
    echo "Summary:"
    echo "--------"
    echo "✓ Bundle created and verified"
    echo "✓ Bundle copied to Cubic workspace"
    echo "✓ Automation script created"
    echo "✓ Installation report generated"
    echo ""
    echo "Cubic Workspace: $CUBIC_WORKSPACE"
    echo ""
    echo "Next steps:"
    echo "1. Open Cubic GUI"
    echo "2. Load project: $CUBIC_WORKSPACE"
    echo "3. In terminal (chroot), run:"
    echo "   bash /tmp/install-k8s-bundle.sh"
    echo "4. Click 'Generate' to create ISO"
    echo ""
    echo "For fully automated ISO generation, see:"
    echo "  https://github.com/PJ-Singh-001/Cubic/wiki/Command-Line-Options"
    echo ""
}

# ========================= MAIN =========================

main() {
    echo -e "${CYAN}"
    echo "════════════════════════════════════════════════════════════════"
    echo "  K8S Bundle - Automation Example"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo ""
    echo "Base ISO: $BASE_ISO"
    echo "Output ISO: $OUTPUT_ISO"
    echo "Cubic Workspace: $CUBIC_WORKSPACE"
    echo ""

    check_prerequisites
    create_bundle
    setup_cubic_workspace
    copy_bundle_to_cubic
    create_cubic_automation_script
    generate_installation_report
    show_summary

    if [[ "$AUTO_CLEANUP" == "yes" ]]; then
        cleanup
    fi
}

# ========================= HELP =========================

show_help() {
    cat << EOF
Usage: $0 [BASE_ISO] [OUTPUT_ISO]

Example Automation Script for K8S Bundle + Cubic

Arguments:
  BASE_ISO     Path to base Ubuntu ISO (default: ubuntu-22.04-server-amd64.iso)
  OUTPUT_ISO   Name for output custom ISO (default: k8s-ubuntu-22.04-custom.iso)

Environment Variables:
  CUBIC_WORKSPACE         Path to Cubic project (default: ~/Cubic/k8s-automation)
  AUTO_CLEANUP            Auto cleanup after completion (default: yes)
  SKIP_VERIFICATION       Skip bundle verification (default: no)
  KEEP_BUNDLE_IN_ISO      Keep bundle in final ISO (default: no)

Examples:
  $0
  $0 ubuntu-22.04.iso my-k8s-iso.iso
  CUBIC_WORKSPACE=/path/to/cubic $0

This script will:
1. Create the K8S bundle
2. Verify bundle integrity
3. Copy bundle to Cubic workspace
4. Generate automation scripts
5. Create installation report

For CI/CD integration, modify this script to fit your pipeline.

EOF
}

# ========================= EXECUTION =========================

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

main "$@"
