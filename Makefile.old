.PHONY: help build verify clean install-cubic test-vm all

# Variables
BUNDLE_OUTPUT = bundle-output/k8s-offline-bundle-1.0.0.tar.gz
SCRIPTS = prepare-k8s-bundle.sh cubic-install-bundle.sh verify-bundle.sh download-apt.sh download-pip.sh

# Default target
help:
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "  K8S Offline Bundle - Makefile Commands"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  make build        - Create the offline bundle"
	@echo "  make verify       - Verify bundle integrity and contents"
	@echo "  make clean        - Remove generated files and directories"
	@echo "  make install-cubic - Install bundle in Cubic (requires Cubic project)"
	@echo "  make test-vm      - Test bundle in a local VM (requires multipass)"
	@echo "  make all          - Build and verify bundle"
	@echo "  make show-info    - Show bundle information"
	@echo "  make checksums    - Verify all checksums"
	@echo "  make help         - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make build        # Create bundle"
	@echo "  make verify       # Verify bundle"
	@echo "  make clean build  # Clean and rebuild"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""

# Build the bundle
build: check-prerequisites
	@echo "Building K8S offline bundle..."
	./prepare-k8s-bundle.sh
	@echo ""
	@echo "✓ Bundle created successfully!"
	@echo "  Location: $(BUNDLE_OUTPUT)"
	@echo ""

# Verify bundle
verify:
	@if [ ! -f "$(BUNDLE_OUTPUT)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	./verify-bundle.sh $(BUNDLE_OUTPUT)

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -rf bundle-workspace/
	rm -rf bundle-output/
	rm -rf offline_dpkg_packages/
	rm -rf offline_pip_packages/
	rm -f *.log
	rm -f download*.log
	@echo "✓ Clean complete"

# Deep clean (including temporary test files)
distclean: clean
	rm -rf /tmp/k8s-bundle-verify-*
	@echo "✓ Deep clean complete"

# Check prerequisites
check-prerequisites:
	@echo "Checking prerequisites..."
	@command -v tar >/dev/null 2>&1 || { echo "Error: tar not found"; exit 1; }
	@command -v gzip >/dev/null 2>&1 || { echo "Error: gzip not found"; exit 1; }
	@command -v apt-cache >/dev/null 2>&1 || { echo "Error: apt-cache not found"; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found"; exit 1; }
	@test -f download-apt.sh || { echo "Error: download-apt.sh not found"; exit 1; }
	@test -f download-pip.sh || { echo "Error: download-pip.sh not found"; exit 1; }
	@echo "✓ All prerequisites met"

# Build and verify
all: build verify

# Show bundle information
show-info:
	@if [ ! -f "$(BUNDLE_OUTPUT)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo ""
	@echo "Bundle Information:"
	@echo "─────────────────────────────────────────────────────"
	@echo "File: $(BUNDLE_OUTPUT)"
	@echo -n "Size: "; du -h "$(BUNDLE_OUTPUT)" | cut -f1
	@echo -n "Created: "; stat -c %y "$(BUNDLE_OUTPUT)" 2>/dev/null || stat -f "%Sm" "$(BUNDLE_OUTPUT)"
	@echo ""
	@echo "Checksums:"
	@if [ -f "$(BUNDLE_OUTPUT).sha256" ]; then \
		echo -n "  SHA256: "; cat "$(BUNDLE_OUTPUT).sha256" | cut -d' ' -f1; \
	fi
	@if [ -f "$(BUNDLE_OUTPUT).md5" ]; then \
		echo -n "  MD5:    "; cat "$(BUNDLE_OUTPUT).md5" | cut -d' ' -f1; \
	fi
	@echo ""
	@echo "Contents:"
	@tar -tzf "$(BUNDLE_OUTPUT)" | head -20
	@echo "  ... (use 'tar -tzf $(BUNDLE_OUTPUT)' to see all files)"
	@echo ""

# Verify checksums only
checksums:
	@if [ ! -f "$(BUNDLE_OUTPUT)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "Verifying checksums..."
	@if [ -f "$(BUNDLE_OUTPUT).sha256" ]; then \
		sha256sum -c "$(BUNDLE_OUTPUT).sha256" && echo "✓ SHA256 valid"; \
	else \
		echo "⚠ SHA256 checksum file not found"; \
	fi
	@if [ -f "$(BUNDLE_OUTPUT).md5" ]; then \
		md5sum -c "$(BUNDLE_OUTPUT).md5" && echo "✓ MD5 valid"; \
	else \
		echo "⚠ MD5 checksum file not found"; \
	fi

# Install in Cubic (requires CUBIC_PROJECT environment variable)
install-cubic:
	@if [ -z "$(CUBIC_PROJECT)" ]; then \
		echo "Error: CUBIC_PROJECT environment variable not set"; \
		echo "Usage: CUBIC_PROJECT=~/Cubic/my-project make install-cubic"; \
		exit 1; \
	fi
	@if [ ! -d "$(CUBIC_PROJECT)" ]; then \
		echo "Error: Cubic project directory not found: $(CUBIC_PROJECT)"; \
		exit 1; \
	fi
	@if [ ! -f "$(BUNDLE_OUTPUT)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "Installing bundle to Cubic project..."
	cp "$(BUNDLE_OUTPUT)" "$(CUBIC_PROJECT)/custom-root/opt/"
	cp "$(BUNDLE_OUTPUT).sha256" "$(CUBIC_PROJECT)/custom-root/opt/" 2>/dev/null || true
	cp cubic-install-bundle.sh "$(CUBIC_PROJECT)/custom-root/opt/"
	@echo ""
	@echo "✓ Files copied to Cubic project"
	@echo ""
	@echo "Next steps (in Cubic chroot):"
	@echo "  cd /opt"
	@echo "  ./cubic-install-bundle.sh"
	@echo ""

# Test bundle in a VM using multipass
test-vm:
	@if ! command -v multipass >/dev/null 2>&1; then \
		echo "Error: multipass not found. Install it first."; \
		echo "  sudo snap install multipass"; \
		exit 1; \
	fi
	@if [ ! -f "$(BUNDLE_OUTPUT)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "Creating test VM..."
	multipass launch --name k8s-bundle-test --cpus 2 --memory 4G --disk 20G 22.04
	@echo "Copying bundle to VM..."
	multipass transfer "$(BUNDLE_OUTPUT)" k8s-bundle-test:/tmp/
	@echo "Extracting and installing bundle..."
	multipass exec k8s-bundle-test -- bash -c "cd /tmp && sudo tar -xzf k8s-offline-bundle-*.tar.gz && cd k8s-offline-bundle && sudo ./install.sh"
	@echo ""
	@echo "✓ Bundle installed in VM"
	@echo ""
	@echo "To access the VM:"
	@echo "  multipass shell k8s-bundle-test"
	@echo ""
	@echo "To verify installation:"
	@echo "  multipass exec k8s-bundle-test -- lsmod | grep ip_vs"
	@echo "  multipass exec k8s-bundle-test -- sudo sysctl net.ipv4.ip_forward"
	@echo ""
	@echo "To clean up:"
	@echo "  multipass delete k8s-bundle-test"
	@echo "  multipass purge"
	@echo ""

# Test basic functionality
test-local:
	@echo "Running local tests..."
	@echo ""
	@echo "1. Checking scripts are executable:"
	@for script in $(SCRIPTS); do \
		if [ -x "$$script" ]; then \
			echo "  ✓ $$script"; \
		else \
			echo "  ✗ $$script (not executable)"; \
		fi; \
	done
	@echo ""
	@echo "2. Checking script syntax:"
	@for script in $(SCRIPTS); do \
		if bash -n "$$script" 2>/dev/null; then \
			echo "  ✓ $$script (syntax OK)"; \
		else \
			echo "  ✗ $$script (syntax error)"; \
		fi; \
	done
	@echo ""
	@echo "✓ Local tests complete"

# List available package versions
list-packages:
	@echo "Available package versions in repositories:"
	@echo ""
	@echo "APT Packages:"
	@echo "─────────────────────────────────────────────────────"
	@apt-cache policy jq | grep Candidate || echo "  jq: not found"
	@apt-cache policy ipvsadm | grep Candidate || echo "  ipvsadm: not found"
	@apt-cache policy iptables | grep Candidate || echo "  iptables: not found"
	@apt-cache policy ebtables | grep Candidate || echo "  ebtables: not found"
	@echo ""
	@echo "PIP Packages:"
	@echo "─────────────────────────────────────────────────────"
	@pip3 index versions jc 2>/dev/null | head -5 || echo "  jc: check failed"
	@echo ""

# Update apt cache
update-cache:
	@echo "Updating APT cache..."
	sudo apt update
	@echo "✓ APT cache updated"

# Quick rebuild (clean + build + verify)
rebuild: clean build verify

# Extract bundle to inspect
extract:
	@if [ ! -f "$(BUNDLE_OUTPUT)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "Extracting bundle for inspection..."
	mkdir -p bundle-inspect
	tar -xzf "$(BUNDLE_OUTPUT)" -C bundle-inspect
	@echo "✓ Bundle extracted to: bundle-inspect/"
	@echo ""
	@echo "To inspect:"
	@echo "  cd bundle-inspect/k8s-offline-bundle"
	@echo "  ls -la"
	@echo ""
	@echo "To clean up:"
	@echo "  rm -rf bundle-inspect/"
	@echo ""
