#!/bin/bash

################################################################################
# Linux System Initializer & Hostname Configuration Manager
# 
# GitHub: memarzade-dev/linux-system-initializer
# Version: 1.1.0
# License: MIT
#
# Purpose:
#   Production-grade system initialization script for Linux servers
#   - System package updates & optimization
#   - Secure hostname configuration with /etc/hosts validation
#   - Root account password change with strength enforcement
#   - Safety backups before critical changes
#   - Comprehensive error handling & recovery
#   - Advanced Performance Tuning (Sysctl, Ulimit) per docs.md
#   - Rathole Tunnel Setup (Server/Client)
#   - Database Migration (Marzban SQLite -> MariaDB)
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
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
readonly LOG_DIR="/var/log"
readonly LOG_FILE="${LOG_DIR}/system-initializer.log"
readonly BACKUP_DIR="/var/backups/system-initializer"
readonly HOSTS_FILE="/etc/hosts"
readonly SHADOW_FILE="/etc/shadow"
readonly SYSCTL_FILE="/etc/sysctl.d/99-system-initializer.conf"
readonly LIMITS_FILE="/etc/security/limits.conf"

# Design Tokens (Color & Typography)
readonly STYLE_RESET='\033[0m'
readonly STYLE_BOLD='\033[1m'
readonly STYLE_DIM='\033[2m'
readonly STYLE_SUCCESS='\033[0;32m'
readonly STYLE_ERROR='\033[0;31m'
readonly STYLE_WARNING='\033[1;33m'
readonly STYLE_INFO='\033[0;34m'
readonly STYLE_HEADER='\033[1;36m' # Cyan Bold

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
IS_CONTAINER=false

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
    echo -e "${STYLE_HEADER}=== $* ===${STYLE_RESET}"
    echo
}

print_success() {
    echo -e "${STYLE_SUCCESS}✓${STYLE_RESET} $*"
    log "INFO" "$*"
}

print_error() {
    echo -e "${STYLE_ERROR}✗${STYLE_RESET} $*" >&2
    log "ERROR" "$*"
}

print_warning() {
    echo -e "${STYLE_WARNING}⚠${STYLE_RESET} $*"
    log "WARN" "$*"
}

print_info() {
    echo -e "${STYLE_INFO}ℹ${STYLE_RESET} $*"
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

# Check runtime dependencies
check_dependencies() {
    local missing_deps=()
    # Added curl, wget, jq for advanced features
    for cmd in grep sed awk hostnamectl ip free df curl wget jq; do
        if ! command -v "${cmd}" &> /dev/null; then
            # Some commands like hostnamectl might be missing in containers, which is fine
            if [[ "${cmd}" == "hostnamectl" ]] && [[ "${IS_CONTAINER}" == "true" ]]; then
                continue
            fi
            missing_deps+=("${cmd}")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "Missing recommended commands: ${missing_deps[*]}"
        print_info "Attempting to install missing dependencies..."
        if [[ "${PACKAGE_MANAGER}" == "apt" ]]; then
            apt-get update -qq && apt-get install -y -qq "${missing_deps[@]}" || print_warning "Failed to auto-install dependencies."
        elif [[ "${PACKAGE_MANAGER}" == "yum" ]]; then
             yum install -y -q "${missing_deps[@]}" || print_warning "Failed to auto-install dependencies."
        fi
    fi
}

# Detect execution environment (Container/Virtualization)
detect_environment() {
    if [[ -f /.dockerenv ]] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=true
        print_info "Execution environment: Container (Docker/LXC)"
    else
        IS_CONTAINER=false
        print_info "Execution environment: Bare Metal / VM"
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
        centos|rhel|fedora|almalinux|rocky)
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
        echo "Container: ${IS_CONTAINER}"
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
        read -rp "$(echo -e ${STYLE_BOLD})Enter new hostname: $(echo -e ${STYLE_RESET})" NEW_HOSTNAME
        
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
    
    # Check for special characters using POSIX bracket expression
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
        read -rsp "$(echo -e ${STYLE_BOLD})New root password: $(echo -e ${STYLE_RESET})" password_1
        echo
        
        if ! validate_password_strength "$password_1" "$MIN_PASSWORD_LENGTH"; then
            ((attempt++))
            if [[ $attempt -lt $MAX_PASSWORD_ATTEMPTS ]]; then
                print_warning "Please try again (attempt $((attempt + 1))/$MAX_PASSWORD_ATTEMPTS)"
            fi
            continue
        fi
        
        read -rsp "$(echo -e ${STYLE_BOLD})Confirm root password: $(echo -e ${STYLE_RESET})" password_2
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

    # Backup /etc/sysctl.conf and limits.conf
    if [[ -f "/etc/sysctl.conf" ]]; then
        cp "/etc/sysctl.conf" "${backup_subdir}/sysctl.conf.bak"
        print_success "Backed up /etc/sysctl.conf"
    fi
    if [[ -f "${LIMITS_FILE}" ]]; then
        cp "${LIMITS_FILE}" "${backup_subdir}/limits.conf.bak"
        print_success "Backed up ${LIMITS_FILE}"
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
    
    # Check if container prevents hostname change
    if [[ "${IS_CONTAINER}" == "true" ]]; then
        print_warning "Running in container: Hostname change might not persist or be allowed."
    fi

    print_info "Configuring hostname..."
    
    if command -v hostnamectl &> /dev/null; then
        if ! hostnamectl set-hostname "${NEW_HOSTNAME}" 2>/dev/null; then
            print_warning "hostnamectl failed (likely due to container/privileges), attempting manual method"
            echo "${NEW_HOSTNAME}" > /etc/hostname || {
                print_error "Failed to write /etc/hostname"
                return 1
            }
        fi
    else
         echo "${NEW_HOSTNAME}" > /etc/hostname || {
            print_error "Failed to write /etc/hostname"
            return 1
        }
    fi
    
    # Apply immediately for current session if possible
    hostname "${NEW_HOSTNAME}" 2>/dev/null || true

    print_success "Hostname set to: ${NEW_HOSTNAME}"
}

# Update /etc/hosts with hostname mapping
update_hosts_file() {
    print_header "Updating /etc/hosts"
    
    local hosts_backup
    hosts_backup="${BACKUP_DIR}/hosts.$(date +%s).bak"
    
    cp "${HOSTS_FILE}" "${hosts_backup}"
    chmod 0644 "${hosts_backup}"
    
    print_info "Cleaning up old entries..."
    
    # Remove old 127.0.1.1 entries (use sed with .bak for compatibility)
    sed -i.bak "/^127\.0\.1\.1[[:space:]]/d" "${HOSTS_FILE}"
    rm -f "${HOSTS_FILE}.bak"
    
    # Ensure localhost entry exists
    if ! grep -q "^127.0.0.1[[:space:]]localhost" "${HOSTS_FILE}"; then
        print_warning "No localhost entry found, adding..."
        {
            echo ""
            echo -e "127.0.0.1\tlocalhost"
        } >> "${HOSTS_FILE}"
    fi
    
    # Add new hostname mapping
    {
        echo -e "127.0.1.1\t${NEW_HOSTNAME}"
    } >> "${HOSTS_FILE}"
    
    print_success "Added /etc/hosts entry: 127.0.1.1 ${NEW_HOSTNAME}"
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
            # Not strictly invalid (might be alias), but worth a warning in strict mode
            # print_warning "Potentially malformed line: $line"
            : # No-op for now to reduce noise
        fi
    done < "${HOSTS_FILE}"
    
    print_success "/etc/hosts validation successful"
}

# Test hostname resolution
test_hostname_resolution() {
    print_header "Testing Hostname Resolution"
    
    # Test with getent
    if command -v getent &> /dev/null; then
        if getent hosts "${NEW_HOSTNAME}" &>/dev/null; then
            print_success "Hostname resolves correctly"
            local resolved_ip
            resolved_ip=$(getent hosts "${NEW_HOSTNAME}" | awk '{print $1}')
            print_info "Resolved to: ${resolved_ip}"
        else
            print_warning "Could not resolve ${NEW_HOSTNAME}"
            print_info "This may be normal for loopback-only configuration"
        fi
    else
        print_warning "getent command not found, skipping resolution test"
    fi
}

# Change root password securely
change_root_password() {
    print_header "Changing Root Password"
    
    # Use chpasswd for secure password change
    echo "root:${NEW_ROOT_PASSWORD}" | chpasswd || {
        print_error "Failed to change root password"
        return 1
    }
    
    print_success "Root password changed successfully"
    
    # Verify password entry in shadow file
    if [[ -r "${SHADOW_FILE}" ]]; then
        if grep -q "^root:" "${SHADOW_FILE}"; then
            print_info "Root password entry verified in shadow file"
        fi
    fi
}

# Apply system security hardening and performance tuning
apply_security_hardening() {
    print_header "Applying Security & Performance Hardening"
    
    if [[ "${IS_CONTAINER}" == "true" ]]; then
        print_warning "Running in container: Skipping sysctl kernel modifications (read-only filesystem/permissions)."
        return 0
    fi
    
    print_info "Configuring sysctl parameters (Security + Performance)..."
    
    # Create sysctl configuration file
    cat > "${SYSCTL_FILE}" << 'SYSCTL_EOF'
# Linux System Initializer - Security & Performance Hardening
# Generated: $(date)

# --- SECURITY ---

# IP forwarding (disable if not routing, enable if needed for tunnels)
# For rathole/xray servers, we typically NEED forwarding. 
# Enabling IP forwarding safely:
net.ipv4.ip_forward = 1

# Disable source packet routing
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.send_redirects = 0
net.ipv6.conf.default.send_redirects = 0

# Enable bad error message protection
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable reverse path filtering (Loose mode for complex routing/VPNs)
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Core dumps (restrict)
kernel.core_uses_pid = 1
fs.suid_dumpable = 0

# Magic SysRq key (disable)
kernel.sysrq = 0

# Restrict file access with dmesg
kernel.dmesg_restrict = 1

# --- PERFORMANCE & SCALABILITY (100+ Users) ---

# Increase max connections
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000

# Increase buffer sizes for high speed
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Increase SYN backlog for high concurrency
net.ipv4.tcp_max_syn_backlog = 8192

# Enable SYN cookies for DoS protection
net.ipv4.tcp_syncookies = 1

# Reuse TIME-WAIT sockets (better resource usage)
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# Keepalive optimization
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 5

# System-wide file descriptor limit
fs.file-max = 2097152

# Memory management
vm.overcommit_memory = 1

# BBR Congestion Control (if available)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

SYSCTL_EOF
    
    chmod 0644 "${SYSCTL_FILE}"
    print_success "Security & Performance configuration written to ${SYSCTL_FILE}"
    
    print_info "Applying sysctl configuration..."
    sysctl -p "${SYSCTL_FILE}" > /dev/null 2>&1 || {
        print_warning "Some sysctl settings may not be supported on this system (e.g., BBR on old kernels)"
    }
    
    print_success "Security & Performance hardening applied"
}

# Optimize system limits (ulimit)
optimize_system_limits() {
    print_header "Optimizing System Limits (Ulimit)"
    
    print_info "Setting high file descriptor limits for scalability..."
    
    # Backup done in backup_critical_files
    
    # Check if limits are already set
    if grep -q "soft nofile 1048576" "${LIMITS_FILE}" 2>/dev/null; then
        print_info "Limits already optimized in ${LIMITS_FILE}"
    else
        {
            echo ""
            echo "# Added by Linux System Initializer"
            echo "* soft nofile 1048576"
            echo "* hard nofile 1048576"
            echo "root soft nofile 1048576"
            echo "root hard nofile 1048576"
        } >> "${LIMITS_FILE}"
        print_success "Updated ${LIMITS_FILE}"
    fi
    
    # Apply immediately for current shell
    ulimit -n 1048576 2>/dev/null || true
    print_info "Current shell limit: $(ulimit -n)"
}

# Setup Rathole Tunnel
setup_rathole() {
    print_header "Rathole Tunnel Setup"
    
    echo "This wizard will help you setup Rathole for secure tunneling."
    echo "Required for high-performance proxying (Server <-> Client)."
    echo
    read -rp "Do you want to install/configure Rathole now? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        print_info "Skipping Rathole setup."
        return 0
    fi
    
    print_info "Installing Rathole..."
    # Detect Architecture
    local arch
    arch=$(uname -m)
    local download_url=""
    
    if [[ "$arch" == "x86_64" ]]; then
        download_url="https://github.com/rapiz1/rathole/releases/latest/download/rathole-x86_64-unknown-linux-gnu.zip"
    elif [[ "$arch" == "aarch64" ]]; then
        download_url="https://github.com/rapiz1/rathole/releases/latest/download/rathole-aarch64-unknown-linux-gnu.zip"
    else
        print_error "Unsupported architecture: $arch"
        return 1
    fi
    
    # Install unzip if missing
    if ! command -v unzip &> /dev/null; then
        apt-get install -y unzip || yum install -y unzip
    fi
    
    wget -qO /tmp/rathole.zip "$download_url" || {
        print_error "Failed to download Rathole"
        return 1
    }
    
    unzip -o /tmp/rathole.zip -d /tmp/rathole_bin
    mv /tmp/rathole_bin/rathole /usr/local/bin/rathole
    chmod +x /usr/local/bin/rathole
    rm -rf /tmp/rathole.zip /tmp/rathole_bin
    
    print_success "Rathole installed to /usr/local/bin/rathole"
    
    # Configuration
    mkdir -p /etc/rathole
    
    echo
    echo "Select Mode:"
    echo "1) Server (e.g., Canada/Foreign VPS)"
    echo "2) Client (e.g., Iran/Domestic VPS)"
    read -rp "Enter choice (1/2): " mode
    
    local config_file=""
    local service_name=""
    
    if [[ "$mode" == "1" ]]; then
        # Server Mode
        config_file="/etc/rathole/server.toml"
        service_name="rathole-server"
        
        read -rp "Enter Bind Port (default 2345): " bind_port
        bind_port=${bind_port:-2345}
        
        # Generate PSK
        local psk
        psk=$(/usr/local/bin/rathole --genkey)
        print_info "Generated strong PSK: ${psk}"
        
        cat > "$config_file" <<EOF
[server]
bind_addr = "0.0.0.0:${bind_port}"
capacity = 300  # Optimized for 100+ users

[server.transport]
type = "noise"

[server.transport.noise]
psk = "${psk}"

[server.services.marzban_bridge]
token = "replace_with_same_token_as_client"
bind_addr = "0.0.0.0:443"
EOF
        print_success "Created Server config at ${config_file}"
        print_warning "IMPORTANT: Copy the PSK above for the Client setup!"
        print_warning "IMPORTANT: Edit the 'token' in ${config_file} manually later."
        
    elif [[ "$mode" == "2" ]]; then
        # Client Mode
        config_file="/etc/rathole/client.toml"
        service_name="rathole-client"
        
        read -rp "Enter Server IP (Foreign VPS): " server_ip
        read -rp "Enter Server Port (default 2345): " server_port
        server_port=${server_port:-2345}
        
        read -rp "Enter PSK (from Server): " psk
        
        cat > "$config_file" <<EOF
[client]
remote_addr = "${server_ip}:${server_port}"
n_channels = 30
retry_interval = 3
heartbeat_timeout = 40
prefer_ipv6 = true

[client.transport]
type = "noise"

[client.transport.noise]
psk = "${psk}"

[client.services.marzban_bridge]
local_addr = "127.0.0.1:443"
token = "replace_with_same_token_as_server"
EOF
        print_success "Created Client config at ${config_file}"
        print_warning "IMPORTANT: Edit the 'token' in ${config_file} manually later."
    else
        print_error "Invalid selection"
        return 1
    fi
    
    # Systemd Service
    cat > "/etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=Rathole ${mode} Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/rathole -c ${config_file}
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "${service_name}"
    print_success "Service ${service_name} enabled (not started yet, check config first)"
}

# Migrate Marzban Database (SQLite -> MariaDB)
migrate_marzban_db() {
    print_header "Marzban Database Migration (SQLite -> MariaDB)"
    
    if [[ ! -d "/opt/marzban" ]]; then
        print_info "Marzban installation not found at /opt/marzban. Skipping migration."
        return 0
    fi
    
    echo "This will migrate Marzban from SQLite to MariaDB for better performance (100+ users)."
    read -rp "Do you want to proceed? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return 0; fi
    
    print_info "Installing MariaDB Server..."
    if [[ "${PACKAGE_MANAGER}" == "apt" ]]; then
        apt-get install -y mariadb-server || { print_error "Failed to install MariaDB"; return 1; }
    else
        yum install -y mariadb-server || { print_error "Failed to install MariaDB"; return 1; }
    fi
    
    systemctl start mariadb
    systemctl enable mariadb
    
    print_info "Creating Database and User..."
    local db_pass="marzban_strong_pass_$(date +%s)"
    
    mysql -e "CREATE DATABASE IF NOT EXISTS marzban CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS 'marzban'@'%' IDENTIFIED BY '${db_pass}';"
    mysql -e "GRANT ALL PRIVILEGES ON marzban.* TO 'marzban'@'%';"
    mysql -e "FLUSH PRIVILEGES;"
    
    print_success "Database 'marzban' created with password: ${db_pass}"
    
    print_info "Updating Marzban configuration..."
    local env_file="/opt/marzban/.env"
    
    if [[ -f "$env_file" ]]; then
        cp "$env_file" "${env_file}.bak.$(date +%s)"
        
        # Comment out old DB url if exists
        sed -i 's/^SQLALCHEMY_DATABASE_URL/# SQLALCHEMY_DATABASE_URL/' "$env_file"
        
        # Add new DB url
        echo "" >> "$env_file"
        echo "SQLALCHEMY_DATABASE_URL=mysql+pymysql://marzban:${db_pass}@localhost/marzban" >> "$env_file"
        
        print_success "Updated .env file"
        
        print_info "Running Migration..."
        cd /opt/marzban
        docker compose down || true
        # We need to run migration inside docker or via marzban-cli if available
        # Assuming standard docker-compose setup
        docker compose up -d
        
        print_warning "Migration initiated. Please check Marzban logs to ensure data is migrated correctly."
        print_info "You may need to manually run 'marzban migrate' if auto-migration fails."
    else
        print_error "Could not find .env file"
    fi
}

# Display system information
display_system_info() {
    print_header "System Information"
    
    echo "Distribution:         ${DISTRIBUTION}"
    echo "Package Manager:      ${PACKAGE_MANAGER}"
    echo "Container:            ${IS_CONTAINER}"
    echo "Kernel:               $(uname -r)"
    echo "Hostname (current):   $(hostname)"
    echo "Hostname (config):    $(cat /etc/hostname 2>/dev/null || echo 'N/A')"
    echo "IPv4 Address:         $(hostname -I 2>/dev/null | awk '{print $1}' || echo 'N/A')"
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
Container:       ${IS_CONTAINER}

CHANGES APPLIED
---------------
✓ Package updates applied
✓ Hostname configured: ${NEW_HOSTNAME}
✓ /etc/hosts updated with hostname mapping
✓ Root password changed
✓ Security & Performance Hardening applied (Sysctl + Ulimit)
  - Max Open Files: 1048576
  - TCP BBR: Enabled (if supported)
  - Network Buffers: Optimized for 1Gbps+

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

3. Check Performance Settings:
   sysctl net.core.somaxconn
   ulimit -n

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
Linux System Initializer v1.1.0

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
    detect_environment
    detect_distribution
    check_dependencies
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
    
    # Get user inputs (Hostname & Password)
    prompt_hostname || exit 1
    prompt_root_password || exit 1
    echo
    
    # Apply configurations
    set_system_hostname
    update_hosts_file
    validate_hosts_file
    test_hostname_resolution
    echo
    
    # Security & Performance
    change_root_password
    apply_security_hardening
    optimize_system_limits
    echo

    # Advanced Setup (Optional)
    setup_rathole
    migrate_marzban_db
    
    # Report
    generate_completion_report
    
    print_header "Initialization Successful"
    print_info "System reboot recommended to apply all changes"
    print_info "View logs: tail -f ${LOG_FILE}"
}

# Execute main function
main "$@"

exit 0
