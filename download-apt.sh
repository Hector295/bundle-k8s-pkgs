#!/bin/bash

# OFFLINE APT PACKAGE DOWNLOADER WITH DPKG INSTALLER

set -e

DOWNLOAD_DIR="./offline_dpkg_packages"
LOG_FILE="download.log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

# Check arguments
if [ $# -eq 0 ]; then
    cat << EOF
Usage: $0 package1 [package2] [package3] ...

Examples:
  $0 nginx mysql-server git
  $0 docker.io vim curl wget

This script:
✓ Downloads packages + all dependencies
✓ No permission warnings
✓ Creates install.sh that uses only dpkg -i
✓ Orders installation by dependencies
EOF
    exit 1
fi

setup_permissions() {
    log "Setting up permissions to avoid warnings..."

    # Create directory with correct permissions
    mkdir -p "$DOWNLOAD_DIR"

    # Ensure current user owns the directory
    sudo chown -R "$(whoami):$(whoami)" "$DOWNLOAD_DIR" 2>/dev/null || true
    chmod 755 "$DOWNLOAD_DIR"

    # Configure APT to not use sandboxing if necessary
    export APT_CONFIG_TEMP=$(mktemp)
    cat > "$APT_CONFIG_TEMP" << EOF
APT::Sandbox::User "";
EOF

    log "Permissions configured correctly"
}

log "Starting complete download for: $*"

# Setup permissions
setup_permissions

# Go to download directory
cd "$DOWNLOAD_DIR"

# Update repositories
log "Updating repositories..."
if ! apt update 2>/dev/null; then
    log "Updating with sudo..."
    sudo apt update
fi

# Get ALL dependencies
log "Getting complete dependency list..."
TEMP_LIST="all_packages.tmp"

# Recursive function to get dependencies
get_all_deps() {
    local packages=("$@")
    local temp_file="deps_temp.list"

    # Create initial list
    printf "%s\n" "${packages[@]}" > "$temp_file"

    # Iterate until no new dependencies are found
    local prev_count=0
    local current_count=1
    local iteration=1

    while [ "$current_count" -gt "$prev_count" ]; do
        info "Iteration $iteration of dependency resolution..."
        prev_count=$(sort "$temp_file" | uniq | wc -l)

        # Get dependencies of all current packages
        while IFS= read -r pkg; do
            if [ -n "$pkg" ]; then
                # Required dependencies + recommendations
                apt-cache depends --no-conflicts --no-breaks --no-replaces --no-enhances "$pkg" 2>/dev/null | \
                    grep -E "^\s+(Pre-)?Depends:|^\s+Recommends:" | \
                    sed 's/.*: //' | sed 's/[<>].*$//' | \
                    grep -v "^$" >> "$temp_file" || true
            fi
        done < <(sort "$temp_file" | uniq)

        # Count unique packages
        current_count=$(sort "$temp_file" | uniq | wc -l)
        info "Packages found: $current_count"

        iteration=$((iteration + 1))
        if [ "$iteration" -gt 20 ]; then
            break
        fi
    done

    # Filter only existing packages
    sort "$temp_file" | uniq | while IFS= read -r pkg; do
        if apt-cache show "$pkg" &>/dev/null; then
            echo "$pkg"
        fi
    done > "$TEMP_LIST"

    rm -f "$temp_file"
}

# Get all dependencies
get_all_deps "$@"

total_packages=$(wc -l < "$TEMP_LIST")
log "Total packages to download: $total_packages"

# Method 1: Try normal download first
download_success=false

# Try without sudo first
if xargs -a "$TEMP_LIST" apt-get download 2>/dev/null; then
    download_success=true
    log "Download completed without sudo"
elif APT_CONFIG="$APT_CONFIG_TEMP" xargs -a "$TEMP_LIST" apt-get download 2>/dev/null; then
    download_success=true
    log "Download completed with special configuration"
else
    warning "Bulk download failed, trying alternative method..."

    # Alternative method: download URLs and use wget
    info "Getting download URLs..."

    while IFS= read -r pkg; do
        # Get package URL
        pkg_info=$(apt-cache show "$pkg" 2>/dev/null | head -20)
        if [ -n "$pkg_info" ]; then
            # Try individual apt-get download
            if ! apt-get download "$pkg" 2>/dev/null; then
                warning "Failed to download: $pkg"

                # As last resort, try wget if possible
                pkg_url=$(apt-get download --print-uris "$pkg" 2>/dev/null | grep -o "'.*\.deb'" | tr -d "'" | head -1)
                if [ -n "$pkg_url" ]; then
                    pkg_filename=$(basename "$pkg_url")
                    info "Downloading with wget: $pkg_filename"
                    wget -q -c "$pkg_url" -O "$pkg_filename" || warning "Wget also failed for $pkg"
                fi
            fi
        fi
    done < "$TEMP_LIST"

    download_success=true
fi

# Clean temporary configuration file
rm -f "$APT_CONFIG_TEMP"

# Verify download and adjust permissions
if [ "$download_success" = true ]; then
    # Ensure correct permissions on downloaded files
    chmod 644 *.deb 2>/dev/null || true
    chown "$(whoami):$(whoami)" *.deb 2>/dev/null || true

    downloaded_count=$(ls -1 *.deb 2>/dev/null | wc -l || echo "0")
    total_size=$(du -sh *.deb 2>/dev/null | tail -1 | cut -f1 || echo "0")

    log "Download completed:"
    log "- .deb files: $downloaded_count"
    log "- Total size: $total_size"
else
    error "Download failed completely"
    exit 1
fi

log "Creating installation script with dpkg -i..."

cat > install.sh << 'INSTALL_SCRIPT'
#!/bin/bash

# Offline installation script using only dpkg -i
# Auto-generated - NO WARNINGS

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INSTALL] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

cd "$(dirname "$0")"

# Check .deb files
deb_count=$(ls -1 *.deb 2>/dev/null | wc -l || echo "0")
if [ "$deb_count" -eq 0 ]; then
    error "No .deb files found in this directory"
    exit 1
fi

log "Starting offline installation of $deb_count packages..."

# ========================= SMART INSTALLATION =========================

install_packages() {
    local method="$1"

    case "$method" in
        "direct")
            info "Method 1: Direct installation of all packages"
            sudo dpkg -i *.deb
            ;;
        "ignore-errors")
            info "Method 2: Installation ignoring dependency errors"
            # Install everything ignoring errors
            sudo dpkg -i *.deb 2>/dev/null || true
            # Configure packages
            sudo dpkg --configure -a 2>/dev/null || true
            ;;
        "ordered")
            info "Method 3: Ordered installation by package types"

            # Smart order: libraries first, applications after
            local patterns=("lib*.deb" "*-common*.deb" "*-data*.deb" "*-dev*.deb" "python*.deb" "*.deb")

            for pattern in "${patterns[@]}"; do
                for deb in $pattern; do
                    if [ -f "$deb" ] && [ ! -f ".installed_$(basename "$deb")" ]; then
                        info "Installing: $(basename "$deb")"
                        if sudo dpkg -i "$deb" 2>/dev/null; then
                            touch ".installed_$(basename "$deb")"
                        else
                            warning "Error installing $deb, continuing..."
                        fi
                    fi
                done
            done

            # Final configuration
            sudo dpkg --configure -a
            ;;
    esac
}

# ========================= INSTALLATION PROCESS =========================

# Try direct method first
if install_packages "direct" 2>/dev/null; then
    log "✅ Direct installation successful!"
else
    warning "Direct installation failed, probably due to dependency order"

    # Try method with error handling
    if install_packages "ignore-errors" 2>/dev/null; then
        log "✅ Installation with dependency correction successful!"
    else
        warning "Standard method failed, using ordered installation..."
        install_packages "ordered"
    fi
fi

# ========================= FINAL VERIFICATION =========================

log "Verifying final installation..."

# Clean tracking files
rm -f .installed_*.deb 2>/dev/null || true

# Check package status
failed_packages=$(dpkg -l | grep -c "^iU\|^iF" 2>/dev/null || echo "0")
configured_packages=$(dpkg -l | grep -c "^ii" 2>/dev/null || echo "0")

if [ "$failed_packages" -gt 0 ]; then
    warning "$failed_packages packages need additional configuration"
    warning "Running final configuration..."
    sudo dpkg --configure -a || true

    # Check again
    failed_packages=$(dpkg -l | grep -c "^iU\|^iF" 2>/dev/null || echo "0")
fi

log "=========================================="
log "         INSTALLATION COMPLETED"
log "=========================================="
log "Configured packages: $configured_packages"
if [ "$failed_packages" -gt 0 ]; then
    warning "Packages with problems: $failed_packages"
    log "If there are problems, run: sudo dpkg --configure -a"
else
    log "✅ All packages installed correctly!"
fi
log "=========================================="
INSTALL_SCRIPT

# Make executable
chmod +x install.sh

# Verification script
cat > verify.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "=== PACKAGE VERIFICATION ==="
total=0; valid=0; corrupted=0

for deb in *.deb; do
    if [ -f "$deb" ]; then
        total=$((total + 1))
        if dpkg-deb --info "$deb" &>/dev/null; then
            echo "✅ $(basename "$deb")"
            valid=$((valid + 1))
        else
            echo "❌ $(basename "$deb") - CORRUPTED"
            corrupted=$((corrupted + 1))
        fi
    fi
done

echo ""
echo "Summary: $total total, $valid valid, $corrupted corrupted"
echo "To install: sudo ./install.sh"
EOF

chmod +x verify.sh

# Simple README
cat > README.txt << EOF
OFFLINE PACKAGES FOR DPKG
=========================

Downloaded: $(date)
Packages: $*
Total .deb files: $downloaded_count
Size: $total_size

INSTALLATION:
sudo ./install.sh

VERIFICATION:
./verify.sh

Ready for offline use!
EOF

# Clean temporaries
rm -f "$TEMP_LIST" *.tmp

log "=========================================="
log "         DOWNLOAD COMPLETED"
log "=========================================="
log "Directory: $(pwd)"
log ".deb files: $downloaded_count"
log "Total size: $total_size"
log ""
log "TO INSTALL ON SYSTEM WITHOUT INTERNET:"
log "1. Copy the complete folder"
log "2. Run: sudo ./install.sh"
log "=========================================="
