#!/bin/bash

# Build and Deploy Script for lsdembed
# This script automates the entire build and deployment process to PyPI

set -e  # Exit on any error

echo "🚀 Starting lsdembed build and deployment process..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check if python is available
    if ! command -v python &> /dev/null; then
        print_error "Python is not installed or not in PATH"
        exit 1
    fi
    
    # Check if pip is available
    if ! command -v pip &> /dev/null; then
        print_error "pip is not installed or not in PATH"
        exit 1
    fi
    
    # Check if patchelf is available (install if not)
    if ! command -v patchelf &> /dev/null; then
        print_warning "patchelf not found. Installing..."
        sudo apt-get update && sudo apt-get install -y patchelf
    fi
    
    print_success "All dependencies are available"
}

# Install required Python packages
install_python_deps() {
    print_status "Installing Python dependencies..."
    
    pip install --upgrade pip
    pip install build twine auditwheel
    
    print_success "Python dependencies installed"
}

# Clean previous builds
clean_build() {
    print_status "Cleaning previous builds..."
    
    # Remove dist directory if it exists
    if [ -d "dist" ]; then
        rm -rf dist/*
        print_status "Cleaned dist/ directory"
    fi
    
    # Remove wheelhouse directory if it exists
    if [ -d "wheelhouse" ]; then
        rm -rf wheelhouse/*
        print_status "Cleaned wheelhouse/ directory"
    fi
    
    # Remove build directories
    if [ -d "build" ]; then
        rm -rf build/
        print_status "Cleaned build/ directory"
    fi
    
    # Remove egg-info directories
    find . -name "*.egg-info" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Build directories cleaned"
}

# Build source distribution
build_sdist() {
    print_status "Building source distribution..."
    
    python -m build --sdist
    
    if [ $? -eq 0 ]; then
        print_success "Source distribution built successfully"
    else
        print_error "Failed to build source distribution"
        exit 1
    fi
}

# Build wheel
build_wheel() {
    print_status "Building wheel..."
    
    python -m build --wheel
    
    if [ $? -eq 0 ]; then
        print_success "Wheel built successfully"
    else
        print_error "Failed to build wheel"
        exit 1
    fi
}

# Repair wheel with auditwheel
repair_wheel() {
    print_status "Repairing wheel with auditwheel..."
    
    # Find the linux wheel file
    LINUX_WHEEL=$(find dist/ -name "*linux_x86_64.whl" | head -1)
    
    if [ -z "$LINUX_WHEEL" ]; then
        print_warning "No linux wheel found to repair"
        return 0
    fi
    
    print_status "Repairing wheel: $LINUX_WHEEL"
    auditwheel repair "$LINUX_WHEEL"
    
    if [ $? -eq 0 ]; then
        # Copy repaired wheel to dist
        REPAIRED_WHEEL=$(find wheelhouse/ -name "*.whl" | head -1)
        if [ -n "$REPAIRED_WHEEL" ]; then
            cp "$REPAIRED_WHEEL" dist/
            # Remove the original linux wheel
            rm "$LINUX_WHEEL"
            print_success "Wheel repaired and copied to dist/"
        fi
    else
        print_error "Failed to repair wheel"
        exit 1
    fi
}

# Check built files
check_built_files() {
    print_status "Checking built files..."
    
    if [ ! -d "dist" ] || [ -z "$(ls -A dist/)" ]; then
        print_error "No files found in dist/ directory"
        exit 1
    fi
    
    print_status "Files in dist/:"
    ls -la dist/
    
    # Check for proper wheel tags
    MANYLINUX_WHEEL=$(find dist/ -name "*manylinux*.whl" | head -1)
    if [ -n "$MANYLINUX_WHEEL" ]; then
        print_success "Found properly tagged manylinux wheel: $(basename "$MANYLINUX_WHEEL")"
    else
        print_warning "No manylinux wheel found - this may cause upload issues"
    fi
}

# Upload to PyPI
upload_to_pypi() {
    print_status "Uploading to PyPI..."
    
    # Check if .pypirc exists
    if [ ! -f "$HOME/.pypirc" ]; then
        print_error ".pypirc file not found. Please configure your PyPI credentials first."
        print_status "Create ~/.pypirc with your PyPI token or run: twine configure"
        exit 1
    fi
    
    print_status "Starting upload..."
    twine upload dist/* --verbose
    
    if [ $? -eq 0 ]; then
        print_success "Successfully uploaded to PyPI!"
        
        # Extract package name and version from setup
        PACKAGE_NAME=$(python -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['name'])" 2>/dev/null || echo "lsdembed")
        PACKAGE_VERSION=$(python -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])" 2>/dev/null || echo "unknown")
        
        print_success "Package available at: https://pypi.org/project/$PACKAGE_NAME/$PACKAGE_VERSION/"
    else
        print_error "Failed to upload to PyPI"
        exit 1
    fi
}

# Main execution
main() {
    echo "🔧 lsdembed Build & Deploy Script"
    echo "=================================="
    
    check_dependencies
    install_python_deps
    clean_build
    build_sdist
    build_wheel
    repair_wheel
    check_built_files
    
    # Ask for confirmation before uploading
    echo ""
    read -p "🚀 Ready to upload to PyPI. Continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        upload_to_pypi
        print_success "🎉 Deployment completed successfully!"
    else
        print_status "Upload cancelled. Files are ready in dist/ directory."
        print_status "To upload manually later, run: twine upload dist/*"
    fi
}

# Run main function
main "$@"