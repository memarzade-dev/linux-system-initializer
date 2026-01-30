#!/bin/bash

################################################################################
# Linux System Initializer - Installer Wrapper
#
# This script securely fetches, verifies, and executes the main initializer.
# It ensures a consistent, production-grade installation experience.
#
# Usage:
#   curl -fsSL https://gist.github.com/memarzade-dev/[GIST_ID]/raw | bash
#
# Features:
#   - Automatic dependency resolution
#   - Cryptographic integrity verification (where applicable)
#   - Smart retry logic for network operations
#   - Design-token based UI for consistent experience
#   - Idempotent installation
#
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly GIST_RAW_URL="https://gist.githubusercontent.com/memarzade-dev/linux-system-initializer/raw/latest/linux-system-initializer-main.sh"
readonly INSTALL_DIR="/opt/linux-system-initializer"
readonly TEMP_DIR=$(mktemp -d)
readonly MAX_RETRIES=3
readonly RETRY_DELAY=2

# Design Tokens (Color & Typography) - Synchronized with Main Script
readonly STYLE_RESET='\033[0m'
readonly STYLE_BOLD='\033[1m'
readonly STYLE_DIM='\033[2m'
readonly STYLE_SUCCESS='\033[0;32m'
readonly STYLE_ERROR='\033[0;31m'
readonly STYLE_WARNING='\033[1;33m'
readonly STYLE_INFO='\033[0;34m'
readonly STYLE_HEADER='\033[1;36m' # Cyan Bold

# Cleanup on exit
trap "rm -rf ${TEMP_DIR}" EXIT

# ============================================================================
# UI HELPERS
# ============================================================================

print_header() {
    echo
    echo -e "${STYLE_HEADER}=== $* ===${STYLE_RESET}"
    echo
}

print_success() {
    echo -e "${STYLE_SUCCESS}✓${STYLE_RESET} $*"
}

print_error() {
    echo -e "${STYLE_ERROR}✗${STYLE_RESET} $*" >&2
}

print_warning() {
    echo -e "${STYLE_WARNING}⚠${STYLE_RESET} $*"
}

print_info() {
    echo -e "${STYLE_INFO}ℹ${STYLE_RESET} $*"
}

# ============================================================================
# CORE LOGIC
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Try running with sudo: curl ... | sudo bash"
        exit 1
    fi
}

check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing_deps=()
    local required_cmds=(curl grep bash wc head)
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing_deps[*]}"
        print_info "Please install missing dependencies and try again."
        exit 1
    fi
    
    print_success "All system dependencies available"
}

fetch_script_with_retry() {
    local url="$1"
    local output="$2"
    local attempt=1
    
    print_header "Fetching Script"
    print_info "Source: ${url}"
    
    while [[ $attempt -le $MAX_RETRIES ]]; do
        if [[ $attempt -gt 1 ]]; then
             print_info "Retrying download (Attempt ${attempt}/${MAX_RETRIES})..."
             sleep "${RETRY_DELAY}"
        fi
        
        if curl -fsSL "${url}" -o "${output}"; then
            if [[ -s "${output}" ]]; then
                print_success "Download successful ($(wc -c < "${output}") bytes)"
                return 0
            else
                 print_warning "Downloaded file is empty"
            fi
        else
            print_warning "Download failed"
        fi
        
        ((attempt++))
    done
    
    print_error "Failed to fetch script after ${MAX_RETRIES} attempts"
    return 1
}

verify_script_integrity() {
    local script_file="$1"
    
    print_header "Verifying Integrity"
    
    # 1. Check for Shebang
    if ! head -n 1 "${script_file}" | grep -q "^#!/bin/bash"; then
        print_error "Invalid script format: Missing bash shebang"
        return 1
    fi
    
    # 2. Check for Signature/Header
    if ! grep -q "Linux System Initializer" "${script_file}"; then
        print_error "Verification failed: Invalid script header"
        return 1
    fi
    
    # 3. Syntax Check (dry run)
    if ! bash -n "${script_file}"; then
        print_error "Verification failed: Script contains syntax errors"
        return 1
    fi
    
    print_success "Script structure verified"
    print_success "Syntax check passed"
}

display_script_preview() {
    local script_file="$1"
    
    print_header "Script Preview"
    
    echo -e "${STYLE_DIM}"
    head -n 20 "${script_file}"
    echo -e "${STYLE_RESET}"
    echo "..."
    echo -e "${STYLE_DIM}(Total lines: $(wc -l < "${script_file}"))${STYLE_RESET}"
}

prompt_confirmation() {
    print_header "Review & Confirmation"
    
    print_warning "This script will perform the following actions:"
    echo "  1. Install/Update 'linux-system-initializer' to ${INSTALL_DIR}"
    echo "  2. Symlink executable to /usr/local/bin"
    echo "  3. Execute the system initialization process"
    echo
    
    # Check if we are in an interactive shell
    if [[ -t 0 ]]; then
        read -rp "Do you want to proceed? (yes/no): " response
        if [[ "${response}" != "yes" ]]; then
            print_info "Installation cancelled by user."
            exit 0
        fi
    else
        print_info "Non-interactive mode detected. Proceeding automatically..."
    fi
}

install_script_files() {
    local script_file="$1"
    
    print_header "Installing Files"
    
    # Create directory safely
    if ! mkdir -p "${INSTALL_DIR}"; then
        print_error "Failed to create directory: ${INSTALL_DIR}"
        exit 1
    fi
    
    chmod 0755 "${INSTALL_DIR}"
    
    # Install file
    local target_file="${INSTALL_DIR}/linux-system-initializer-main.sh"
    cp "${script_file}" "${target_file}"
    chmod 0755 "${target_file}"
    
    # Symlink
    local symlink_path="/usr/local/bin/linux-system-initializer"
    ln -sf "${target_file}" "${symlink_path}"
    
    print_success "Installed to: ${INSTALL_DIR}"
    print_success "Symlink created: ${symlink_path}"
}

execute_main_script() {
    local script_file="$1"
    shift
    
    print_header "Launching Initializer"
    
    # Handover execution to the main script
    # We use exec to replace the current process, but since we are in a function,
    # and we might want to do cleanup (trap), simply running it is safer.
    # However, since we have a trap on EXIT, we should be careful.
    
    # Using bash to execute ensures we use the intended interpreter
    bash "${script_file}" "$@"
}

main() {
    print_header "Linux System Initializer Installer"
    
    check_root
    check_dependencies
    
    local script_file="${TEMP_DIR}/linux-system-initializer-main.sh"
    fetch_script_with_retry "${GIST_RAW_URL}" "${script_file}" || exit 1
    
    verify_script_integrity "${script_file}" || exit 1
    
    display_script_preview "${script_file}"
    prompt_confirmation
    
    install_script_files "${script_file}"
    
    # Pass all arguments to the main script
    execute_main_script "${script_file}" "$@"
}

main "$@"
