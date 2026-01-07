#!/bin/bash

# Python Package Downloader with all dependencies for offline installation

set -e

# ========================= CONFIGURATION =========================
DOWNLOAD_DIR="./offline_pip_packages"
LOG_FILE="download_pip.log"
REQUIREMENTS_FILE="downloaded_requirements.txt"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ========================= FUNCIONES =========================

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

progress() {
    echo -e "${PURPLE}[PROGRESS] $1${NC}" | tee -a "$LOG_FILE"
}

# Help function
show_help() {
    cat << EOF
OFFLINE SCRIPT FOR PIP PACKAGES

Usage: $0 [OPTIONS] package1 [package2] [package3]...

OPTIONS:
  -r, --requirements FILE    Use requirements.txt file
  --no-deps                  Don't download dependencies
  --pre                      Include pre-release versions
  --simple                   Simple download (more compatible)
  -h, --help                 Show this help

EXAMPLES:
  $0 jc
  $0 requests flask django
  $0 -r requirements.txt
  $0 --simple numpy pandas
  $0 --no-deps requests==2.28.1

Fixed and functional script!
EOF
}

# ========================= ARGUMENT PROCESSING =========================

PACKAGES=()
REQUIREMENTS=""
NO_DEPS=false
PRE_RELEASE=false
SIMPLE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--requirements)
            REQUIREMENTS="$2"
            shift 2
            ;;
        --no-deps)
            NO_DEPS=true
            shift
            ;;
        --pre)
            PRE_RELEASE=true
            shift
            ;;
        --simple)
            SIMPLE_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            PACKAGES+=("$1")
            shift
            ;;
    esac
done

# Check arguments
if [ ${#PACKAGES[@]} -eq 0 ] && [ -z "$REQUIREMENTS" ]; then
    show_help
    exit 1
fi

# ========================= INITIAL SETUP =========================

setup_environment() {
    log "Setting up pip download environment..."

    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"

    # Detect pip
    local pip_cmd=""
    if command -v pip3 &>/dev/null; then
        pip_cmd="pip3"
    elif command -v pip &>/dev/null; then
        pip_cmd="pip"
    else
        error "pip not found. Install Python and pip first."
        exit 1
    fi

    info "Using pip: $pip_cmd"

    # Configure pip globally
    export PIP_CMD="$pip_cmd"

    # Update pip (silent to avoid warnings)
    log "Updating pip..."
    $pip_cmd install --upgrade pip --quiet 2>/dev/null || warning "Could not update pip"
}

# ========================= DIRECT DOWNLOAD =========================

download_packages_direct() {
    progress "Downloading pip packages..."

    local success=false

    # Build list of packages to download
    local packages_to_download=()

    # Add packages from arguments
    if [ ${#PACKAGES[@]} -gt 0 ]; then
        packages_to_download+=("${PACKAGES[@]}")
        log "Specified packages: ${PACKAGES[*]}"
    fi

    # Process requirements.txt if exists
    if [ -n "$REQUIREMENTS" ]; then
        if [ -f "$REQUIREMENTS" ]; then
            log "Processing requirements.txt: $REQUIREMENTS"
            while IFS= read -r line; do
                # Filter comments and empty lines
                if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "$line" ]]; then
                    packages_to_download+=("$line")
                fi
            done < "$REQUIREMENTS"
        else
            error "requirements.txt file not found: $REQUIREMENTS"
            exit 1
        fi
    fi

    if [ ${#packages_to_download[@]} -eq 0 ]; then
        error "No packages found to download"
        exit 1
    fi

    info "Total packages to download: ${#packages_to_download[@]}"

    # Try different download methods

    # Method 1: Simple download (more compatible)
    if [ "$SIMPLE_MODE" = true ]; then
        log "Simple mode activated"
        local download_args=("--dest" ".")

        if [ "$NO_DEPS" = true ]; then
            download_args+=("--no-deps")
        fi

        if [ "$PRE_RELEASE" = true ]; then
            download_args+=("--pre")
        fi

        log "Downloading with arguments: ${download_args[*]}"

        if $PIP_CMD download "${download_args[@]}" "${packages_to_download[@]}"; then
            success=true
            log "Simple mode download successful"
        fi
    else
        # Method 2: Binary only (faster)
        log "Trying binary download..."
        local download_args=("--dest" "." "--only-binary=:all:")

        if [ "$NO_DEPS" = true ]; then
            download_args+=("--no-deps")
        fi

        if [ "$PRE_RELEASE" = true ]; then
            download_args+=("--pre")
        fi

        log "Downloading with arguments: ${download_args[*]}"

        if $PIP_CMD download "${download_args[@]}" "${packages_to_download[@]}" 2>/dev/null; then
            success=true
            log "Binary download successful"
        else
            warning "Binary download failed, trying standard download..."

            # Method 3: Standard download
            local std_args=("--dest" ".")

            if [ "$NO_DEPS" = true ]; then
                std_args+=("--no-deps")
            fi

            if [ "$PRE_RELEASE" = true ]; then
                std_args+=("--pre")
            fi

            log "Downloading with standard arguments: ${std_args[*]}"

            if $PIP_CMD download "${std_args[@]}" "${packages_to_download[@]}"; then
                success=true
                log "Standard download successful"
            fi
        fi
    fi

    # Method 4: Individual as last resort
    if [ "$success" = false ]; then
        warning "Bulk download failed, trying individual download..."

        for package in "${packages_to_download[@]}"; do
            if [ -n "$package" ]; then
                info "Downloading individually: $package"

                local args=("--dest" ".")
                if [ "$NO_DEPS" = true ]; then
                    args+=("--no-deps")
                fi

                if $PIP_CMD download "${args[@]}" "$package"; then
                    info "✓ Downloaded: $package"
                    success=true
                else
                    warning "✗ Failed: $package"
                fi
            fi
        done
    fi

    if [ "$success" = false ]; then
        error "Failed to download all packages"
        exit 1
    fi

    # Verify download
    local whl_count=$(ls -1 *.whl 2>/dev/null | wc -l || echo "0")
    local tar_count=$(ls -1 *.tar.gz 2>/dev/null | wc -l || echo "0")
    local zip_count=$(ls -1 *.zip 2>/dev/null | wc -l || echo "0")
    local total_count=$((whl_count + tar_count + zip_count))

    if [ "$total_count" -eq 0 ]; then
        error "No files downloaded"
        exit 1
    fi

    log "Download completed:"
    log "- .whl files: $whl_count"
    log "- .tar.gz files: $tar_count"
    log "- .zip files: $zip_count"
    log "- Total: $total_count files"

    local total_size=$(du -sh . | cut -f1 2>/dev/null || echo "unknown")
    log "- Total size: $total_size"
}

# ========================= GENERATE INSTALLATION SCRIPTS =========================

create_install_scripts() {
    progress "Creating installation scripts..."

    # Main installation script
    cat > install_offline.sh << 'EOF'
#!/bin/bash

# Offline installation of pip packages
# Auto-generated

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INSTALL] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

cd "$(dirname "$0")"

# Detect pip
if command -v pip3 &>/dev/null; then
    PIP_CMD="pip3"
elif command -v pip &>/dev/null; then
    PIP_CMD="pip"
else
    error "pip not found"
    exit 1
fi

log "Installing offline packages with $PIP_CMD..."

# Count files
whl=$(ls *.whl 2>/dev/null | wc -l)
tar=$(ls *.tar.gz 2>/dev/null | wc -l)
zip=$(ls *.zip 2>/dev/null | wc -l)
total=$((whl + tar + zip))

if [ "$total" -eq 0 ]; then
    error "No packages to install"
    exit 1
fi

log "Found $total packages ($whl .whl, $tar .tar.gz, $zip .zip)"

# Install all files
log "Installing packages..."
if $PIP_CMD install --no-index --find-links . *.whl *.tar.gz *.zip 2>/dev/null; then
    log "✅ Installation successful"
else
    warning "Bulk installation failed, trying individual..."

    # Install individually
    for file in *.whl *.tar.gz *.zip; do
        if [ -f "$file" ]; then
            log "Installing: $file"
            $PIP_CMD install --no-index --find-links . "$file" || warning "Failed: $file"
        fi
    done
fi

log "Verifying installation..."
$PIP_CMD list

log "✅ Offline installation completed"
EOF

    # Virtual environment script
    cat > install_venv.sh << 'EOF'
#!/bin/bash

# Create virtual environment and install offline packages

VENV_NAME="offline_env"

echo "🐍 Creating virtual environment: $VENV_NAME"
python3 -m venv "$VENV_NAME"

echo "⚡ Activating virtual environment..."
source "$VENV_NAME/bin/activate"

echo "📦 Installing packages..."
bash install_offline.sh

echo ""
echo "✅ Ready! To use the environment:"
echo "  source $VENV_NAME/bin/activate"
EOF

    chmod +x *.sh
    log "Scripts created: install_offline.sh, install_venv.sh"
}

# ========================= FINAL REPORT =========================

create_report() {
    progress "Generating final report..."

    local whl=$(ls -1 *.whl 2>/dev/null | wc -l || echo "0")
    local tar=$(ls -1 *.tar.gz 2>/dev/null | wc -l || echo "0")
    local zip=$(ls -1 *.zip 2>/dev/null | wc -l || echo "0")
    local total=$((whl + tar + zip))
    local size=$(du -sh . | cut -f1 2>/dev/null || echo "?")

    cat > README.txt << EOF
OFFLINE PIP PACKAGES
===================

Date: $(date)
Location: $(pwd)

FILES:
- .whl: $whl
- .tar.gz: $tar
- .zip: $zip
- Total: $total packages
- Size: $size

INSTALLATION:
sudo ./install_offline.sh

VIRTUAL ENVIRONMENT:
./install_venv.sh

Ready for offline use!
EOF

    log "=========================================="
    log "         DOWNLOAD COMPLETED"
    log "=========================================="
    log "Packages: $total files"
    log "Size: $size"
    log "Location: $(pwd)"
    log "To install: ./install_offline.sh"
    log "=========================================="
}

# ========================= MAIN FUNCTION =========================

main() {
    log "Starting offline pip download..."

    setup_environment
    download_packages_direct
    create_install_scripts
    create_report

    log "PIP DOWNLOAD SUCCESSFUL!"
}

# ========================= EXECUTION =========================

main "$@"
