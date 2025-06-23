#!/bin/bash

# Simple validation script for exo-cluster-scripts project
# This checks for common issues and ensures scripts are ready for use

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

echo "=== Project Validation ==="
echo ""

errors=0
warnings=0

# Check required files exist
echo "Checking required files..."
required_files=(
    "install_exo_auto.sh"
    "scripts/setup_python_env.sh"
    "scripts/install_exo_service.sh"
    "scripts/start_exo.sh"
    "scripts/check_exo_status.sh"
    "scripts/uninstall_exo_service.sh"
    "scripts/com.exolabs.exo.plist"
    "scripts/exo_config_example.sh"
    "README.md"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        print_status "Found $file"
    else
        print_error "Missing $file"
        ((errors++))
    fi
done

# Check script permissions
echo ""
echo "Checking script permissions..."
executable_files=(
    "install_exo_auto.sh"
    "scripts/setup_python_env.sh" 
    "scripts/install_exo_service.sh"
    "scripts/start_exo.sh"
    "scripts/check_exo_status.sh"
    "scripts/uninstall_exo_service.sh"
)

for file in "${executable_files[@]}"; do
    if [[ -f "$file" ]]; then
        if [[ -x "$file" ]]; then
            print_status "$file is executable"
        else
            print_warning "$file is not executable (fixing...)"
            chmod +x "$file"
            ((warnings++))
        fi
    fi
done

# Check plist syntax
echo ""
echo "Checking plist syntax..."
if command -v plutil &> /dev/null; then
    if plutil -lint scripts/com.exolabs.exo.plist > /dev/null 2>&1; then
        print_status "plist file syntax is valid"
    else
        print_error "plist file syntax is invalid"
        ((errors++))
    fi
else
    print_warning "plutil not available, cannot validate plist"
    ((warnings++))
fi

# Check for placeholder URLs
echo ""
echo "Checking for placeholder content..."
if grep -r "your-username" . --exclude="validate_project.sh" > /dev/null 2>&1; then
    print_warning "Found placeholder URLs that should be updated"
    grep -r "your-username" . --exclude="validate_project.sh" | head -3
    ((warnings++))
else
    print_status "No placeholder URLs found"
fi

# Check basic system requirements
echo ""
echo "Checking system requirements..."
if [[ "$(uname)" == "Darwin" ]]; then
    print_status "Running on macOS"
else
    print_error "This project is designed for macOS only"
    ((errors++))
fi

if command -v git &> /dev/null; then
    print_status "Git is available"
else
    print_error "Git is required but not installed"
    ((errors++))
fi

if command -v curl &> /dev/null; then
    print_status "curl is available"
else
    print_error "curl is required but not installed"
    ((errors++))
fi

# Summary
echo ""
echo "=== Validation Summary ==="
if [[ $errors -eq 0 ]]; then
    print_status "All critical checks passed"
else
    print_error "$errors critical errors found"
fi

if [[ $warnings -gt 0 ]]; then
    print_warning "$warnings warnings found"
fi

echo ""
if [[ $errors -eq 0 ]]; then
    echo "✅ Project is ready for use!"
    echo "Run: ./install_exo_auto.sh"
else
    echo "❌ Please fix the errors above before using"
    exit 1
fi 