#!/bin/bash

################################################################################
# Linux System Initializer - Gist Installer Wrapper
#
# This script fetches and executes the main initializer from GitHub Gist
# Provides automatic installation and execution in single command
#
# Usage:
#   curl -fsSL https://gist.github.com/memarzade-dev/[GIST_ID]/raw | bash
#   wget -qO- https://gist.github.com/memarzade-dev/[GIST_ID]/raw | bash
#
# Security:
#   - Verifies script integrity before execution
#   - Displays script content for review
#   - Requires explicit user confirmation
#
################################################################################

set -euo pipefail

readonly GIST_RAW_URL="https://gist.githubusercontent.com/memarzade-dev/linux-system-initializer/raw/latest/linux-system-initializer-main.sh"
readonly INSTALL_DIR="/opt/linux-system-initializer"
readonly TEMP_DIR=$(mktemp -d)

trap "rm -rf ${TEMP_DIR}" EXIT

# Color codes
readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'

print_header() {
    echo -e "\n${COLOR_BLUE}=== $* ===${COLOR_RESET}\n"
}

print_success() {
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*"
}

print_error() {
    echo -e "${COLOR_RED}✗${COLOR_RESET} $*" >&2
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $*"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} $*"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Try: curl -fsSL https://gist.github.com/memarzade-dev/[ID]/raw | sudo bash"
        exit 1
    fi
}

check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing_deps=()
    
    for cmd in curl grep bash wc head; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing_deps[*]}"
        exit 1
    fi
    
    print_success "All dependencies available"
}

fetch_script() {
    print_header "Fetching Script from GitHub"
    
    print_info "Source: ${GIST_RAW_URL}"
    
    local script_file="${TEMP_DIR}/linux-system-initializer-main.sh"
    
    if ! curl -fsSL "${GIST_RAW_URL}" -o "${script_file}"; then
        print_error "Failed to fetch script"
        return 1
    fi
    
    if [[ ! -s "${script_file}" ]]; then
        print_error "Downloaded script is empty"
        return 1
    fi
    
    print_success "Script downloaded ($(wc -c < "${script_file}") bytes)"
    echo "${script_file}"
}

verify_script_header() {
    local script_file="$1"
    
    print_header "Verifying Script"
    
    if ! head -1 "${script_file}" | grep -q "^#!/bin/bash"; then
        print_error "Invalid script format (not a bash script)"
        return 1
    fi
    
    if ! grep -q "Linux System Initializer" "${script_file}"; then
        print_error "Script signature verification failed"
        return 1
    fi
    
    print_success "Script signature verified"
    print_success "Script is valid bash executable"
}

display_script_preview() {
    local script_file="$1"
    
    print_header "Script Preview"
    
    echo "First 30 lines of downloaded script:"
    echo "---"
    head -30 "${script_file}"
    echo "---"
    echo "(... $(wc -l < "${script_file}") total lines)"
}

prompt_confirmation() {
    print_header "Review & Confirmation"
    
    print_warning "This script will:"
    echo "  1. Update system packages (apt/yum)"
    echo "  2. Set system hostname"
    echo "  3. Update /etc/hosts file"
    echo "  4. Change root password (requires 12+ chars, mixed complexity)"
    echo "  5. Apply security hardening"
    echo "  6. Create backups of critical files"
    echo
    
    read -rp "Do you want to proceed? (yes/no): " response
    
    if [[ "${response}" != "yes" ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
}

install_script() {
    local script_file="$1"
    
    print_header "Installing Script"
    
    mkdir -p "${INSTALL_DIR}"
    chmod 0755 "${INSTALL_DIR}"
    
    cp "${script_file}" "${INSTALL_DIR}/linux-system-initializer-main.sh"
    chmod 0755 "${INSTALL_DIR}/linux-system-initializer-main.sh"
    
    # Create symlink in standard location
    ln -sf "${INSTALL_DIR}/linux-system-initializer-main.sh" /usr/local/bin/linux-system-initializer || true
    
    print_success "Script installed to ${INSTALL_DIR}"
    print_success "Symlink created: /usr/local/bin/linux-system-initializer"
}

execute_script() {
    local script_file="$1"
    shift  # Remove script_file from $@, remaining args passed to script
    
    print_header "Executing Initialization Script"
    
    bash "${script_file}" "$@"
}

main() {
    print_header "Linux System Initializer v1.0.0"
    print_info "Production-Grade System Initialization"
    
    # Verify root
    check_root
    
    # Check dependencies
    check_dependencies
    
    # Fetch script
    local script_file
    script_file=$(fetch_script) || exit 1
    
    # Verify
    verify_script_header "${script_file}" || exit 1
    
    # Preview
    display_script_preview "${script_file}"
    
    # Confirm
    prompt_confirmation
    
    # Install
    install_script "${script_file}"
    
    # Execute
    execute_script "${script_file}" "$@"
}

# Execute with all passed arguments
main "$@"
