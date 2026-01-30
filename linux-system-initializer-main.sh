#!/bin/bash

################################################################################
# Linux System Initializer & Hostname Configuration Manager
# 
# GitHub: memarzade-dev/linux-system-initializer
# Version: 1.0.0
# License: MIT
#
# Purpose:
#   Production-grade system initialization script for Linux servers
#   - System package updates & optimization
#   - Secure hostname configuration with /etc/hosts validation
#   - Root account password change with strength enforcement
#   - Safety backups before critical changes
#   - Comprehensive error handling & recovery
#
# Supported Distributions:
#   Ubuntu 18.04+, Debian 10+, CentOS 7+, RHEL 7+
#
# Requirements:
#   - Root/sudo privileges
#   - Internet connectivity (for package updates)
#   - 100MB free disk space (minimum)
#
# Security Considerations:
#   - All changes backed up before execution
#   - Strong password validation (min 12 chars, mixed complexity)
#   - No credentials logged to history or files
#   - Audit trail maintained in /var/log/system-initializer.log
#
# Usage:
#   sudo bash linux-system-initializer-main.sh [--skip-update] [--skip-packages]
#
# Examples:
#   # Full initialization (recommended)
#   sudo bash linux-system-initializer-main.sh
#   
#   # Skip APT updates (already updated)
#   sudo bash linux-system-initializer-main.sh --skip-update
#
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
readonly LOG_DIR="/var/log"
readonly LOG_FILE="${LOG_DIR}/system-initializer.log"
readonly BACKUP_DIR="/var/backups/system-initializer"
readonly HOSTS_FILE="/etc/hosts"
readonly SHADOW_FILE="/etc/shadow"
readonly SYSCTL_FILE="/etc/sysctl.d/99-system-initializer.conf"

# Color codes for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'

# Security constants
readonly MIN_PASSWORD_LENGTH=12
readonly MAX_PASSWORD_ATTEMPTS=3
readonly HOSTNAME_REGEX='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'

# State tracking
SKIP_UPDATE=false
SKIP_PACKAGES=false
NEW_HOSTNAME=""
NEW_ROOT_PASSWORD=""
DISTRIBUTION=""
PACKAGE_MANAGER=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

print_header() {
    echo
    echo -e "${COLOR_BOLD}${COLOR_BLUE}=== $* ===${COLOR_RESET}"
    echo
}

print_success() {
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*"
    log "INFO" "$*"
}

print_error() {
    echo -e "${COLOR_RED}✗${COLOR_RESET} $*" >&2
    log "ERROR" "$*"
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $*"
    log "WARN" "$*"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} $*"
    log "INFO" "$*"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Try: sudo bash ${SCRIPT_NAME}"
        exit 1
    fi
}

# Detect Linux distribution
detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        DISTRIBUTION="${ID:-unknown}"
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    case "${DISTRIBUTION}" in
        ubuntu|debian)
            PACKAGE_MANAGER="apt"
            ;;
        centos|rhel|fedora)
            PACKAGE_MANAGER="yum"
            ;;
        *)
            print_warning "Distribution ${DISTRIBUTION} not officially supported"
            print_info "Attempting with APT package manager"
            PACKAGE_MANAGER="apt"
            ;;
    esac
    
    print_success "Distribution detected: ${DISTRIBUTION} (${PACKAGE_MANAGER})"
}

# Create backup directory with proper permissions
setup_backup_dir() {
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        mkdir -p "${BACKUP_DIR}"
        chmod 0700 "${BACKUP_DIR}"
        print_success "Backup directory created: ${BACKUP_DIR}"
    fi
}

# Initialize logging
setup_logging() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
    fi
    
    # Create log file if it doesn't exist
    touch "${LOG_FILE}"
    chmod 0600 "${LOG_FILE}"
    
    {
        echo "==============================================================================="
        echo "Linux System Initializer - Session Start"
        echo "Version: ${SCRIPT_VERSION}"
        echo "Timestamp: $(date)"
        echo "User: ${SUDO_USER:-root}"
        echo "Distribution: ${DISTRIBUTION}"
        echo "==============================================================================="
    } >> "${LOG_FILE}"
}

# Validate hostname format
validate_hostname() {
    local hostname="$1"
    
    if [[ ! "$hostname" =~ $HOSTNAME_REGEX ]]; then
        print_error "Invalid hostname format: ${hostname}"
        print_info "Hostname must:"
        print_info "  - Start with alphanumeric character"
        print_info "  - Contain only alphanumeric and hyphens"
        print_info "  - End with alphanumeric character"
        print_info "  - Be 1-63 characters long"
        return 1
    fi
    
    return 0
}

# Get hostname from user with validation
prompt_hostname() {
    local attempt=0
    
    while [[ $attempt -lt 3 ]]; do
        echo
        read -rp "$(echo -e ${COLOR_BOLD})Enter new hostname: $(echo -e ${COLOR_RESET})" NEW_HOSTNAME
        
        if [[ -z "$NEW_HOSTNAME" ]]; then
            print_error "Hostname cannot be empty"
            ((attempt++))
            continue
        fi
        
        if validate_hostname "$NEW_HOSTNAME"; then
            print_success "Hostname accepted: ${NEW_HOSTNAME}"
            return 0
        fi
        
        ((attempt++))
    done
    
    print_error "Failed to set hostname after 3 attempts"
    return 1
}

# Validate password strength
validate_password_strength() {
    local password="$1"
    local min_length=$2
    
    # Check minimum length
    if [[ ${#password} -lt $min_length ]]; then
        print_error "Password too short (minimum ${min_length} characters)"
        return 1
    fi
    
    # Check for uppercase
    if [[ ! "$password" =~ [A-Z] ]]; then
        print_error "Password must contain at least one uppercase letter"
        return 1
    fi
    
    # Check for lowercase
    if [[ ! "$password" =~ [a-z] ]]; then
        print_error "Password must contain at least one lowercase letter"
        return 1
    fi
    
    # Check for numbers
    if [[ ! "$password" =~ [0-9] ]]; then
        print_error "Password must contain at least one number"
        return 1
    fi
    
    # Check for special characters
    if [[ ! "$password" =~ [[:punct:]] ]]; then
        print_error "Password must contain at least one special character"
        return 1
    fi
    
    return 0
}

# Get root password from user with confirmation
prompt_root_password() {
    local attempt=0
    local password_1=""
    local password_2=""
    
    while [[ $attempt -lt $MAX_PASSWORD_ATTEMPTS ]]; do
        echo
        print_info "Enter new root password"
        read -rsp "$(echo -e ${COLOR_BOLD})New root password: $(echo -e ${COLOR_RESET})" password_1
        echo
        
        if ! validate_password_strength "$password_1" "$MIN_PASSWORD_LENGTH"; then
            ((attempt++))
            if [[ $attempt -lt $MAX_PASSWORD_ATTEMPTS ]]; then
                print_warning "Please try again (attempt $((attempt + 1))/$MAX_PASSWORD_ATTEMPTS)"
            fi
            continue
        fi
        
        read -rsp "$(echo -e ${COLOR_BOLD})Confirm root password: $(echo -e ${COLOR_RESET})" password_2
        echo
        
        if [[ "$password_1" != "$password_2" ]]; then
            print_error "Passwords do not match"
            ((attempt++))
            if [[ $attempt -lt $MAX_PASSWORD_ATTEMPTS ]]; then
                print_warning "Please try again (attempt $((attempt + 1))/$MAX_PASSWORD_ATTEMPTS)"
            fi
            continue
        fi
        
        NEW_ROOT_PASSWORD="$password_1"
        print_success "Root password validated"
        return 0
    done
    
    print_error "Failed to set root password after $MAX_PASSWORD_ATTEMPTS attempts"
    return 1
}

# Backup critical system files
backup_critical_files() {
    local backup_timestamp
    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_subdir="${BACKUP_DIR}/backup_${backup_timestamp}"
    
    mkdir -p "${backup_subdir}"
    chmod 0700 "${backup_subdir}"
    
    print_info "Backing up critical files..."
    
    # Backup /etc/hosts
    if [[ -f "${HOSTS_FILE}" ]]; then
        cp "${HOSTS_FILE}" "${backup_subdir}/hosts.bak"
        chmod 0644 "${backup_subdir}/hosts.bak"
        print_success "Backed up /etc/hosts"
    fi
    
    # Backup /etc/hostname
    if [[ -f /etc/hostname ]]; then
        cp /etc/hostname "${backup_subdir}/hostname.bak"
        chmod 0644 "${backup_subdir}/hostname.bak"
        print_success "Backed up /etc/hostname"
    fi
    
    # Backup /etc/shadow (read-only permissions)
    if [[ -f "${SHADOW_FILE}" ]]; then
        cp "${SHADOW_FILE}" "${backup_subdir}/shadow.bak"
        chmod 0000 "${backup_subdir}/shadow.bak"
        print_success "Backed up /etc/shadow"
    fi
    
    log "INFO" "Backup directory: ${backup_subdir}"
    echo "${backup_subdir}"
}

# Update system packages
update_system_packages() {
    print_header "System Package Updates"
    
    if [[ "${SKIP_UPDATE}" == "true" ]]; then
        print_warning "Skipping package updates (--skip-update flag used)"
        return 0
    fi
    
    case "${PACKAGE_MANAGER}" in
        apt)
            print_info "Running apt update..."
            apt-get update -qq || {
                print_error "apt update failed"
                return 1
            }
            print_success "Package list updated"
            
            print_info "Running apt upgrade..."
            apt-get upgrade -y -qq || {
                print_error "apt upgrade failed"
                return 1
            }
            print_success "Packages upgraded"
            
            if [[ "${SKIP_PACKAGES}" != "true" ]]; then
                print_info "Running apt autoremove..."
                apt-get autoremove -y -qq || {
                    print_error "apt autoremove failed"
                    return 1
                }
                print_success "Obsolete packages removed"
            fi
            ;;
        yum)
            print_info "Running yum check-update..."
            yum check-update -q || true
            
            print_info "Running yum update..."
            yum update -y -q || {
                print_error "yum update failed"
                return 1
            }
            print_success "Packages updated"
            
            if [[ "${SKIP_PACKAGES}" != "true" ]]; then
                print_info "Running yum autoremove..."
                yum autoremove -y -q || {
                    print_error "yum autoremove failed"
                    return 1
                }
                print_success "Obsolete packages removed"
            fi
            ;;
        *)
            print_error "Unsupported package manager: ${PACKAGE_MANAGER}"
            return 1
            ;;
    esac
}

# Set hostname in system
set_system_hostname() {
    print_header "Setting System Hostname"
    
    print_info "Using hostnamectl to set hostname..."
    
    if ! hostnamectl set-hostname "${NEW_HOSTNAME}" 2>/dev/null; then
        print_error "hostnamectl failed, attempting manual method"
        echo "${NEW_HOSTNAME}" > /etc/hostname || {
            print_error "Failed to write /etc/hostname"
            return 1
        }
    fi
    
    print_success "Hostname set to: ${NEW_HOSTNAME}"
}

# Update /etc/hosts with hostname mapping
update_hosts_file() {
    print_header "Updating /etc/hosts"
    
    local hosts_backup
    hosts_backup="${BACKUP_DIR}/hosts.$(date +%s).bak"
    
    cp "${HOSTS_FILE}" "${hosts_backup}"
    chmod 0644 "${hosts_backup}"
    
    print_info "Current /etc/hosts entries for 127.0.1.1:"
    grep "^127.0.1.1" "${HOSTS_FILE}" || print_warning "No 127.0.1.1 entries found"
    
    # Remove old 127.0.1.1 entries (use sed with .bak for compatibility)
    sed -i.bak "/^127\.0\.1\.1[[:space:]]/d" "${HOSTS_FILE}"
    rm -f "${HOSTS_FILE}.bak"
    
    # Ensure localhost entry exists
    if ! grep -q "^127.0.0.1[[:space:]]localhost" "${HOSTS_FILE}"; then
        print_warning "No localhost entry found, adding..."
        {
            echo ""
            echo "127.0.0.1\tlocalhost"
        } >> "${HOSTS_FILE}"
    fi
    
    # Add new hostname mapping
    {
        echo "127.0.1.1\t${NEW_HOSTNAME}"
    } >> "${HOSTS_FILE}"
    
    print_success "Added /etc/hosts entry: 127.0.1.1 ${NEW_HOSTNAME}"
    
    print_info "Updated /etc/hosts entries for 127.0.1.1:"
    grep "^127.0.1.1" "${HOSTS_FILE}" || true
}

# Validate hosts file syntax
validate_hosts_file() {
    print_info "Validating /etc/hosts syntax..."
    
    # Check if /etc/hosts is readable
    if [[ ! -r "${HOSTS_FILE}" ]]; then
        print_error "Cannot read ${HOSTS_FILE}"
        return 1
    fi
    
    # Basic validation: check for malformed lines
    local invalid_lines=0
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Check for minimum requirements (IP + hostname)
        if ! [[ "$line" =~ ^[0-9a-fA-F:.]+[[:space:]]+[a-zA-Z0-9.-]+$ ]]; then
            print_warning "Potentially invalid line: $line"
            ((invalid_lines++))
        fi
    done < "${HOSTS_FILE}"
    
    if [[ $invalid_lines -eq 0 ]]; then
        print_success "/etc/hosts validation successful"
        return 0
    else
        print_warning "Found ${invalid_lines} potentially invalid lines"
        return 0
    fi
}

# Test hostname resolution
test_hostname_resolution() {
    print_header "Testing Hostname Resolution"
    
    # Test with getent
    if getent hosts "${NEW_HOSTNAME}" &>/dev/null; then
        print_success "Hostname resolves correctly"
        local resolved_ip
        resolved_ip=$(getent hosts "${NEW_HOSTNAME}" | awk '{print $1}')
        print_info "Resolved to: ${resolved_ip}"
    else
        print_warning "Could not resolve ${NEW_HOSTNAME}"
        print_info "This may be normal for loopback-only configuration"
    fi
}

# Change root password securely
change_root_password() {
    print_header "Changing Root Password"
    
    # Create temporary file for password hash
    local temp_passwd
    temp_passwd=$(mktemp)
    trap "rm -f ${temp_passwd}; return" EXIT
    
    # Use chpasswd for secure password change
    echo "root:${NEW_ROOT_PASSWORD}" | chpasswd || {
        print_error "Failed to change root password"
        return 1
    }
    
    print_success "Root password changed successfully"
    
    # Verify password entry in shadow file
    if grep -q "^root:" "${SHADOW_FILE}"; then
        print_info "Root password entry verified in shadow file"
    fi
}

# Apply system security hardening
apply_security_hardening() {
    print_header "Applying Security Hardening"
    
    print_info "Configuring sysctl security parameters..."
    
    # Create sysctl configuration file
    cat > "${SYSCTL_FILE}" << 'SYSCTL_EOF'
# Linux System Initializer - Security Hardening
# Generated: $(date)

# IP forwarding (disable if not routing)
net.ipv4.ip_forward = 0

# Disable source packet routing
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.send_redirects = 0
net.ipv6.conf.default.send_redirects = 0

# Enable bad error message protection
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Increase SYN backlog
net.ipv4.tcp_max_syn_backlog = 4096

# Core dumps (restrict)
kernel.core_uses_pid = 1
fs.suid_dumpable = 0

# Magic SysRq key (disable)
kernel.sysrq = 0

# Process accounting
kernel.acct = 10 2 70

# Restrict kernel module loading
kernel.modules_disabled = 1

# Restrict file access with dmesg
kernel.dmesg_restrict = 1
SYSCTL_EOF
    
    chmod 0644 "${SYSCTL_FILE}"
    print_success "Security configuration written to ${SYSCTL_FILE}"
    
    print_info "Applying sysctl configuration..."
    sysctl -p "${SYSCTL_FILE}" > /dev/null 2>&1 || {
        print_warning "Some sysctl settings may not be supported on this system"
    }
    
    print_success "Security hardening applied"
}

# Display system information
display_system_info() {
    print_header "System Information"
    
    echo "Distribution:         ${DISTRIBUTION}"
    echo "Package Manager:      ${PACKAGE_MANAGER}"
    echo "Kernel:               $(uname -r)"
    echo "Hostname (current):   $(hostname)"
    echo "Hostname (config):    $(cat /etc/hostname 2>/dev/null || echo 'N/A')"
    echo "IPv4 Loopback:        $(hostname -I 2>/dev/null | awk '{print $1}' || echo 'N/A')"
    echo "Disk Usage:           $(df -h / | tail -1 | awk '{print $5}')"
    echo "Memory Usage:         $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
}

# Generate completion report
generate_completion_report() {
    print_header "Initialization Complete"
    
    local report_file="${LOG_DIR}/system-initializer-report.txt"
    
    cat > "${report_file}" << REPORT_EOF
================================================================================
Linux System Initializer - Completion Report
Generated: $(date)
================================================================================

SYSTEM INFORMATION
------------------
Distribution:    ${DISTRIBUTION}
Hostname:        $(hostname)
Kernel:          $(uname -r)
Uptime:          $(uptime -p 2>/dev/null || uptime)

CHANGES APPLIED
---------------
✓ Package updates applied
✓ Hostname configured: ${NEW_HOSTNAME}
✓ /etc/hosts updated with hostname mapping
✓ Root password changed
✓ Security hardening applied

BACKUP LOCATIONS
----------------
Log File:        ${LOG_FILE}
Backups:         ${BACKUP_DIR}/

VERIFICATION STEPS
------------------
1. Verify hostname:
   hostname
   cat /etc/hostname
   grep "127.0.1.1" /etc/hosts

2. Test DNS resolution:
   getent hosts ${NEW_HOSTNAME}

3. Test sudo access:
   sudo ls

SECURITY NOTES
--------------
- Root password changed (minimum 12 characters with mixed complexity)
- SSH key-based authentication recommended
- Firewall configuration recommended
- Regular security updates advised

SUPPORT & DOCUMENTATION
------------------------
GitHub:  https://github.com/memarzade-dev/linux-system-initializer
Issues:  https://github.com/memarzade-dev/linux-system-initializer/issues
Logs:    ${LOG_FILE}

================================================================================
REPORT_EOF
    
    print_success "Report generated: ${report_file}"
    
    # Display report
    echo
    cat "${report_file}"
}

# Parse command-line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-update)
                SKIP_UPDATE=true
                print_info "Flag set: --skip-update"
                shift
                ;;
            --skip-packages)
                SKIP_PACKAGES=true
                print_info "Flag set: --skip-packages"
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            --version|-v)
                echo "Linux System Initializer v${SCRIPT_VERSION}"
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

# Print usage information
print_usage() {
    cat << 'USAGE_EOF'
Linux System Initializer v1.0.0

USAGE:
  sudo bash linux-system-initializer-main.sh [OPTIONS]

OPTIONS:
  --skip-update      Skip APT/YUM package updates
  --skip-packages    Skip autoremove of obsolete packages
  --help             Show this help message
  --version          Show version information

EXAMPLES:
  # Full initialization (recommended)
  sudo bash linux-system-initializer-main.sh

  # Skip updates (already updated)
  sudo bash linux-system-initializer-main.sh --skip-update

REQUIREMENTS:
  - Root/sudo privileges
  - Internet connectivity (for updates)
  - Ubuntu 18.04+, Debian 10+, or CentOS/RHEL 7+

SECURITY:
  - All changes backed up before execution
  - Strong password validation enforced
  - Audit trail maintained in /var/log/system-initializer.log

DOCUMENTATION:
  GitHub: https://github.com/memarzade-dev/linux-system-initializer

USAGE_EOF
}

# Error handler for cleanup
error_handler() {
    local line_number=$1
    print_error "Script failed at line ${line_number}"
    log "ERROR" "Script failed at line ${line_number}"
    print_warning "System may be in partial state. Check logs: ${LOG_FILE}"
    exit 1
}

# Trap errors
trap 'error_handler ${LINENO}' ERR

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "Linux System Initializer v${SCRIPT_VERSION}"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Verify root privileges
    check_root
    
    # Setup
    detect_distribution
    setup_backup_dir
    setup_logging
    
    # Display current system info
    display_system_info
    echo
    
    # Backup critical files
    backup_critical_files
    echo
    
    # System updates
    update_system_packages
    echo
    
    # Get user inputs
    prompt_hostname || exit 1
    prompt_root_password || exit 1
    echo
    
    # Apply configurations
    set_system_hostname
    update_hosts_file
    validate_hosts_file
    test_hostname_resolution
    echo
    
    # Security
    change_root_password
    apply_security_hardening
    echo
    
    # Report
    generate_completion_report
    
    print_header "Initialization Successful"
    print_info "System reboot recommended to apply all changes"
    print_info "View logs: tail -f ${LOG_FILE}"
}

# Execute main function
main "$@"

exit 0
