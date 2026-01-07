.PHONY: help build-1.30 build-1.29 build-1.28 verify clean list-versions test-install

# Default K8S version
K8S_VERSION ?= 1.30.2
UBUNTU_VERSION ?= 22.04
ARCH ?= amd64

# Output bundle name
BUNDLE_NAME = k8s-complete-$(K8S_VERSION)-ubuntu$(UBUNTU_VERSION)-$(ARCH)
BUNDLE_FILE = k8s-bundle-output/$(BUNDLE_NAME).tar.gz

help:
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "  Kubernetes Complete Bundle - Makefile"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  make build               - Build bundle with default version (K8s $(K8S_VERSION))"
	@echo "  make build-1.30          - Build K8s 1.30.2 bundle"
	@echo "  make build-1.29          - Build K8s 1.29.6 bundle"
	@echo "  make build-1.28          - Build K8s 1.28.11 bundle"
	@echo ""
	@echo "  make build K8S_VERSION=X - Build specific K8s version"
	@echo "  make verify              - Verify bundle integrity"
	@echo "  make extract             - Extract bundle for inspection"
	@echo "  make clean               - Remove generated files"
	@echo "  make list-versions       - List available K8s versions"
	@echo "  make show-info           - Show bundle information"
	@echo "  make test-install        - Test installation in Docker"
	@echo ""
	@echo "Environment variables:"
	@echo "  K8S_VERSION    = $(K8S_VERSION)"
	@echo "  UBUNTU_VERSION = $(UBUNTU_VERSION)"
	@echo "  ARCH           = $(ARCH)"
	@echo "  CNI_PROVIDER   = calico (or flannel)"
	@echo ""
	@echo "Examples:"
	@echo "  make build                           # Default: K8s 1.30.2"
	@echo "  make build-1.29                      # K8s 1.29.6"
	@echo "  make build K8S_VERSION=1.30.2        # Explicit version"
	@echo "  make build ARCH=arm64                # ARM64 build"
	@echo "  CNI_PROVIDER=flannel make build      # Use Flannel CNI"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""

# Build with default or specified version
build:
	@echo "Building Kubernetes $(K8S_VERSION) bundle..."
	./create-k8s-bundle.sh $(K8S_VERSION) $(UBUNTU_VERSION) $(ARCH)

# Quick build targets for common versions
build-1.30:
	@$(MAKE) build K8S_VERSION=1.30.2

build-1.29:
	@$(MAKE) build K8S_VERSION=1.29.6

build-1.28:
	@$(MAKE) build K8S_VERSION=1.28.11

# Build for ARM64
build-arm64:
	@$(MAKE) build ARCH=arm64

# Verify bundle
verify:
	@if [ ! -f "$(BUNDLE_FILE)" ]; then \
		echo "Error: Bundle not found: $(BUNDLE_FILE)"; \
		echo "Run 'make build' first"; \
		exit 1; \
	fi
	@echo "Verifying bundle: $(BUNDLE_FILE)"
	@if [ -f "$(BUNDLE_FILE).sha256" ]; then \
		cd k8s-bundle-output && sha256sum -c $(BUNDLE_NAME).tar.gz.sha256; \
	else \
		echo "Warning: SHA256 checksum not found"; \
	fi
	@tar -tzf "$(BUNDLE_FILE)" | head -20
	@echo "..."
	@echo "Bundle appears valid"

# Show bundle information
show-info:
	@if [ ! -f "$(BUNDLE_FILE)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo ""
	@echo "Bundle Information:"
	@echo "─────────────────────────────────────────────────────"
	@echo "Name:       $(BUNDLE_NAME)"
	@echo "File:       $(BUNDLE_FILE)"
	@echo "Size:       $$(du -h "$(BUNDLE_FILE)" | cut -f1)"
	@echo "K8s:        $(K8S_VERSION)"
	@echo "Ubuntu:     $(UBUNTU_VERSION)"
	@echo "Arch:       $(ARCH)"
	@echo ""
	@if [ -f "$(BUNDLE_FILE).sha256" ]; then \
		echo "SHA256:     $$(cat "$(BUNDLE_FILE).sha256" | cut -d' ' -f1)"; \
	fi
	@echo ""
	@echo "Contents:"
	@tar -tzf "$(BUNDLE_FILE)" | grep -E '(kubeadm|kubelet|kubectl|containerd|README)' | head -10
	@echo ""

# Extract bundle for inspection
extract:
	@if [ ! -f "$(BUNDLE_FILE)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "Extracting bundle..."
	@mkdir -p bundle-inspect
	@tar -xzf "$(BUNDLE_FILE)" -C bundle-inspect
	@echo "✓ Extracted to: bundle-inspect/$(BUNDLE_NAME)/"
	@echo ""
	@echo "To inspect:"
	@echo "  cd bundle-inspect/$(BUNDLE_NAME)"
	@echo "  ls -la"
	@echo ""

# List available versions
list-versions:
	@./list-k8s-versions.py

# Show version matrix
show-matrix:
	@./list-k8s-versions.py --matrix

# Test installation in Docker
test-install:
	@if [ ! -f "$(BUNDLE_FILE)" ]; then \
		echo "Error: Bundle not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "Testing installation in Docker container..."
	@docker run --rm --privileged \
		-v "$(PWD)/k8s-bundle-output:/bundle:ro" \
		-v "$(PWD)/bundle-inspect:/tmp/test:rw" \
		ubuntu:$(UBUNTU_VERSION) bash -c ' \
		cd /tmp/test && \
		tar -xzf /bundle/$(BUNDLE_NAME).tar.gz && \
		cd $(BUNDLE_NAME) && \
		echo "Bundle extracted successfully" && \
		ls -la && \
		echo "" && \
		echo "To actually test installation, run:" && \
		echo "  sudo ./install-k8s.sh" \
	'

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -rf k8s-bundle-workspace/
	rm -rf k8s-bundle-output/
	rm -rf bundle-inspect/
	rm -rf offline_dpkg_packages/
	rm -rf offline_pip_packages/
	rm -f *.log
	@echo "✓ Clean complete"

# Deep clean (including downloads)
distclean: clean
	@echo "Deep cleaning..."
	rm -rf /tmp/k8s-*
	@echo "✓ Deep clean complete"

# Check prerequisites
check-prereqs:
	@echo "Checking prerequisites..."
	@command -v python3 >/dev/null || { echo "✗ python3 not found"; exit 1; }
	@python3 -c "import yaml" 2>/dev/null || { echo "✗ python3-yaml not found"; exit 1; }
	@command -v curl >/dev/null || { echo "✗ curl not found"; exit 1; }
	@command -v wget >/dev/null || { echo "✗ wget not found"; exit 1; }
	@test -f k8s-versions.yaml || { echo "✗ k8s-versions.yaml not found"; exit 1; }
	@test -f download-apt.sh || { echo "✗ download-apt.sh not found"; exit 1; }
	@test -f download-pip.sh || { echo "✗ download-pip.sh not found"; exit 1; }
	@echo "✓ All prerequisites met"

# Build all versions
build-all:
	@echo "Building all K8s versions..."
	@$(MAKE) build-1.30
	@$(MAKE) build-1.29
	@$(MAKE) build-1.28
	@echo ""
	@echo "✓ All bundles built"
	@ls -lh k8s-bundle-output/

# Quick build and verify
quick:
	@$(MAKE) build
	@$(MAKE) verify
	@$(MAKE) show-info
