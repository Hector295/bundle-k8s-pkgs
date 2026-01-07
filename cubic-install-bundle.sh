#!/bin/bash

# ============================================================================
# Cubic Bundle Installer
# ============================================================================
# Script para ejecutar dentro del entorno chroot de Cubic
# Extrae e instala el bundle K8S automáticamente
# ============================================================================

set -e

# Colors
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

# ========================= CONFIGURATION =========================

BUNDLE_LOCATION="${1:-/opt/k8s-offline-bundle*.tar.gz}"
EXTRACT_DIR="/opt"
KEEP_BUNDLE="${2:-no}"  # Set to "yes" to keep bundle after installation

# ========================= MAIN =========================

echo -e "${CYAN}"
echo "════════════════════════════════════════════════════════════════"
echo "  K8S Bundle Installer for Cubic"
echo "════════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo ""

# Find bundle file
info "Searching for bundle..."
BUNDLE_FILE=$(ls $BUNDLE_LOCATION 2>/dev/null | head -1)

if [[ -z "$BUNDLE_FILE" ]]; then
    error "Bundle file not found at: $BUNDLE_LOCATION"
fi

log "Found bundle: $(basename "$BUNDLE_FILE")"

# Verify bundle integrity if checksum exists
if [[ -f "${BUNDLE_FILE}.sha256" ]]; then
    info "Verifying bundle integrity..."
    if sha256sum -c "${BUNDLE_FILE}.sha256" >/dev/null 2>&1; then
        log "Bundle integrity verified (SHA256)"
    else
        warning "SHA256 checksum verification failed"
    fi
fi

# Extract bundle
info "Extracting bundle to $EXTRACT_DIR..."
tar -xzf "$BUNDLE_FILE" -C "$EXTRACT_DIR"

BUNDLE_DIR=$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name "k8s-offline-bundle*" | head -1)

if [[ -z "$BUNDLE_DIR" ]]; then
    error "Failed to find extracted bundle directory"
fi

log "Bundle extracted to: $BUNDLE_DIR"

# Run installation
info "Running bundle installation..."
cd "$BUNDLE_DIR"

if [[ -f "./install.sh" ]]; then
    bash ./install.sh
    log "Installation completed successfully"
else
    error "install.sh not found in bundle"
fi

# Cleanup
if [[ "$KEEP_BUNDLE" != "yes" ]]; then
    info "Cleaning up..."
    rm -rf "$BUNDLE_DIR"
    rm -f "$BUNDLE_FILE" "${BUNDLE_FILE}.sha256" "${BUNDLE_FILE}.md5"
    log "Bundle files removed"
else
    info "Keeping bundle files as requested"
fi

echo ""
echo -e "${GREEN}"
echo "════════════════════════════════════════════════════════════════"
echo "  K8S Bundle Installation Completed!"
echo "════════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo ""
info "Your ISO is now ready with K8S prerequisites"
echo ""
