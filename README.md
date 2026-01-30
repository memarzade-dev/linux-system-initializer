# Linux System Initializer

**Production-Grade System Initialization & Hostname Configuration for Linux Servers**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash: 4.0+](https://img.shields.io/badge/Bash-4.0+-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Ubuntu: 18.04+](https://img.shields.io/badge/Ubuntu-18.04%2B-orange.svg)](https://ubuntu.com/)

> **Automated system initialization, secure hostname configuration, and root security hardening for Linux servers with zero data loss and comprehensive audit trails.**

---

## 🚀 Quick Start

### Installation & Execution (Single Command)

```bash
# Using curl
curl -fsSL https://gist.github.com/memarzade-dev/30fea70654259f2b3b21252e8a782123/raw | sudo bash

# Using wget
wget -qO- https://gist.github.com/memarzade-dev/30fea70654259f2b3b21252e8a782123/raw | sudo bash
```

### Or: Manual Installation

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/memarzade-dev/linux-system-initializer/main/linux-system-initializer-main.sh -o initialize.sh

# Make executable
chmod +x initialize.sh

# Execute with root privileges
sudo bash initialize.sh
```

---

## ✨ Features

### 🔧 System Optimization
- **Automatic Package Updates**: Distribution-agnostic (APT/YUM)
- **Intelligent Cleanup**: Remove obsolete packages with autoremove
- **Kernel Updates**: Seamless upgrade to latest stable kernel
- **Zero Downtime**: Changes applied without service interruption

### 🏠 Hostname Configuration
- **Validation & Safety**: Regex-based hostname format validation
- **Atomic Updates**: Simultaneous updates to:
  - `/etc/hostname`
  - `/etc/hosts` (127.0.1.1 mapping)
  - systemd hostnamectl
- **Resolution Testing**: Verify hostname resolves correctly
- **Idempotent**: Safe to run multiple times

### 🔐 Root Security Hardening
- **Strong Password Enforcement**: 
  - Minimum 12 characters
  - Uppercase + lowercase + numbers + special characters
  - Real-time validation feedback
- **Secure Password Management**:
  - No credentials logged to history/files
  - Encrypted shadow file operations
  - chpasswd for atomic updates
- **Multiple Verification Attempts**: 3 attempts per prompt

### 📦 System Hardening
- **Kernel Security Parameters**:
  - IP forwarding restrictions
  - Source route filtering
  - ICMP redirect protection
  - Bad error message protection
  - Reverse path filtering
- **File System Security**:
  - Core dump restrictions
  - SysRq key disabled
  - Kernel module loading restrictions
- **Network Security**:
  - Suspicious packet logging
  - SYN backlog optimization
  - dmesg access restrictions

### 💾 Data Protection
- **Automatic Backups**:
  - `/etc/hosts`
  - `/etc/hostname`
  - `/etc/shadow` (read-only backup)
  - Timestamped backup directory: `/var/backups/system-initializer/`
- **Backup Integrity**: All critical files backed up before any modifications
- **Recovery Capability**: Full rollback possible from backup directory

### 📋 Audit & Logging
- **Comprehensive Logging**:
  - Location: `/var/log/system-initializer.log`
  - All operations logged with timestamps
  - Error tracking and recovery notes
- **Completion Report**:
  - Verification steps
  - Change summary
  - Backup locations
  - Security recommendations
- **Read-Only Audit Trail**: Cannot be modified after creation

---

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 18.04+, Debian 10+, CentOS 7+, RHEL 7+
- **User**: Root or sudo privileges
- **Network**: Internet connectivity for package updates
- **Disk**: 100MB minimum free space
- **Memory**: 512MB minimum RAM

### Required Commands
- `bash` (4.0+)
- `sudo` or root shell
- `curl` or `wget` (for installation)
- `hostnamectl`, `sed`, `grep`, `apt`/`yum`

### Optional Enhancements
- SSH key-based authentication (for remote access)
- Firewall configuration (`ufw` or `firewalld`)

---

## 📖 Usage

### Basic Initialization (Recommended)

```bash
sudo bash linux-system-initializer-main.sh
```

**Interactive prompts:**
1. Current system information review
2. Hostname: Enter new hostname (validated)
3. Root Password: Strong password with confirmation
4. Review summary before applying

**Output:**
- Real-time progress with color-coded status
- Completion report with verification steps
- Log file location for audit trail

### Skip Package Updates

```bash
sudo bash linux-system-initializer-main.sh --skip-update
```

Use when packages already updated to avoid redundant apt/yum operations.

### Skip Obsolete Package Removal

```bash
sudo bash linux-system-initializer-main.sh --skip-packages
```

Use to keep older package versions (advanced scenarios).

### Combined Options

```bash
sudo bash linux-system-initializer-main.sh --skip-update --skip-packages
```

Only performs hostname configuration and security hardening.

---

## 🔍 Detailed Workflow

### Phase 1: Pre-Execution Setup
1. ✓ Root privilege verification
2. ✓ Distribution detection (Ubuntu/Debian/CentOS/RHEL)
3. ✓ Package manager auto-selection (APT/YUM)
4. ✓ Backup directory creation: `/var/backups/system-initializer/`
5. ✓ Logging initialization: `/var/log/system-initializer.log`

### Phase 2: System Updates
1. ✓ APT/YUM package list update
2. ✓ Full system upgrade (all packages)
3. ✓ Orphaned package removal (autoremove)
4. ✓ Kernel update if available
5. ✓ Progress reporting at each step

### Phase 3: User Input & Validation
1. ✓ Hostname prompt (with format validation)
2. ✓ Root password prompt (with strength validation)
3. ✓ Password confirmation prompt
4. ✓ Summary review before execution

### Phase 4: Critical System Changes
1. ✓ Critical file backup (atomic, timestamped)
2. ✓ Hostname configuration in `/etc/hostname`
3. ✓ Hostname registration with systemd
4. ✓ `/etc/hosts` file update with IP mapping
5. ✓ Old entries cleanup (remove orphaned hostnames)
6. ✓ Hosts file validation (syntax check)
7. ✓ Hostname resolution testing

### Phase 5: Security Hardening
1. ✓ Root password change (via chpasswd)
2. ✓ Shadow file update verification
3. ✓ Sysctl security parameters application
4. ✓ Kernel hardening options loaded

### Phase 6: Post-Execution
1. ✓ System information report
2. ✓ Completion report generation
3. ✓ Backup locations documented
4. ✓ Verification step instructions provided
5. ✓ Security recommendations displayed

---

## 📊 System Information Displayed

```
Distribution:         ubuntu (or debian/centos/rhel)
Package Manager:      apt (or yum)
Kernel:               5.15.0-84-generic
Hostname (current):   old-hostname
Hostname (config):    new-hostname
IPv4 Loopback:        127.0.0.1
Disk Usage:           23%
Memory Usage:         512M / 2G
```

---

## 🔐 Security Considerations

### Password Requirements
- **Minimum Length**: 12 characters
- **Character Types**: MUST include:
  - ✓ At least one uppercase letter (A-Z)
  - ✓ At least one lowercase letter (a-z)
  - ✓ At least one number (0-9)
  - ✓ At least one special character (!@#$%^&*...)

### Hostname Validation Rules
```
Valid:     web-server-01, ubuntu-prod, db01
Invalid:   web_server, -hostname, hostname-, 123, web--server
```
- Alphanumeric and hyphens only
- Cannot start/end with hyphen
- 1-63 characters maximum
- No spaces or special characters

### System Hardening Applied
- **Network**: IP forwarding disabled, redirects blocked
- **Kernel**: ICMP restrictions, sysrq disabled, core dumps restricted
- **Logging**: Suspicious packets logged, dmesg access limited
- **Modules**: Kernel module loading restrictions enabled

### What This Script Does NOT Do
- ❌ Open firewall ports (use `ufw` or `firewalld` separately)
- ❌ Configure SSH keys (configure separately)
- ❌ Install additional software
- ❌ Disable sudo access
- ❌ Lock root account

---

## 📁 File Locations

### Critical Backup Directory
```
/var/backups/system-initializer/backup_20240130_143022/
├── hosts.bak              # Previous /etc/hosts
├── hostname.bak           # Previous /etc/hostname
└── shadow.bak             # Previous /etc/shadow (chmod 0000)
```

### Log Files
```
/var/log/system-initializer.log           # Complete execution log
/var/log/system-initializer-report.txt    # Completion report
```

### Installation Directory (if installed)
```
/opt/linux-system-initializer/
└── linux-system-initializer-main.sh
```

### Symlink (if installed)
```
/usr/local/bin/linux-system-initializer -> /opt/linux-system-initializer/linux-system-initializer-main.sh
```

---

## ✅ Verification Steps

### After Script Execution

#### 1. Verify Hostname Change
```bash
# Check current hostname
hostname

# Check hostname configuration file
cat /etc/hostname

# Check hosts file mapping
grep "127.0.1.1" /etc/hosts
```

**Expected Output:**
```
toronto
toronto
127.0.1.1    toronto
```

#### 2. Test Hostname Resolution
```bash
# Test DNS resolution
getent hosts toronto

# Test with ping (localhost)
ping -c 1 toronto
```

#### 3. Test Root Access
```bash
# Verify new password works
sudo ls

# View sudo log
sudo tail -n 5 /var/log/auth.log
```

#### 4. Review Security Changes
```bash
# Check sysctl configuration
sysctl -p /etc/sysctl.d/99-system-initializer.conf | head -20

# Verify hostname service
systemctl status systemd-hostnamed
```

#### 5. Check Backup Integrity
```bash
# List backups
ls -lah /var/backups/system-initializer/

# View backup contents
cat /var/backups/system-initializer/backup_*/hosts.bak | head -5
```

#### 6. Verify Logs
```bash
# View execution log
tail -50 /var/log/system-initializer.log

# View completion report
cat /var/log/system-initializer-report.txt
```

---

## 🚨 Troubleshooting

### Issue: "sudo: unable to resolve host"

**Cause**: Hostname mapping missing from `/etc/hosts`

**Solution**:
```bash
# Check current hostname
hostname

# Check /etc/hosts
grep "127.0.1.1" /etc/hosts

# If missing, add manually
echo "127.0.1.1 $(hostname)" >> /etc/hosts
```

### Issue: Password Change Fails

**Cause**: Incorrect password strength or permissions

**Solution**:
```bash
# Check if shadow file is writable
ls -la /etc/shadow

# Try password change manually
sudo passwd root

# View log for details
sudo tail -50 /var/log/system-initializer.log
```

### Issue: Hostname Resolution Still Fails

**Cause**: systemd-hostnamed service not restarted

**Solution**:
```bash
# Restart hostname service
systemctl restart systemd-hostnamed

# Reload NSS caches
systemctl restart nscd 2>/dev/null || true

# Test resolution again
getent hosts $(hostname)
```

### Issue: APT/YUM Package Updates Fail

**Cause**: Network connectivity or repository issues

**Solution**:
```bash
# Check network connectivity
ping -c 1 8.8.8.8

# Check APT sources (Ubuntu/Debian)
apt-cache policy | head -10

# Try manual update
apt-get update -qq

# View detailed error
sudo cat /var/log/system-initializer.log | grep -i error
```

### Issue: Script Fails at Security Hardening

**Cause**: System kernel doesn't support specific sysctl parameters

**Solution**:
```bash
# This is non-critical - some parameters may not apply
# Check which parameters are supported
sysctl -a | grep "net.ipv4.ip_forward"

# View which failed
sudo grep "WARN" /var/log/system-initializer.log
```

---

## 📋 Rollback Instructions

### Restore Previous Hostname
```bash
# Find latest backup
BACKUP_DIR=$(ls -d /var/backups/system-initializer/backup_* | tail -1)

# Restore hostname
cp ${BACKUP_DIR}/hostname.bak /etc/hostname
systemctl restart systemd-hostnamed

# Restore /etc/hosts
cp ${BACKUP_DIR}/hosts.bak /etc/hosts
```

### Restore Root Password from Backup
⚠️ **Note**: Shadow file backup is read-only for security. To recover:
1. Boot into recovery mode
2. Mount filesystem as read-write
3. Manual password reset using `passwd` command

---

## 📦 Supported Distributions

| Distribution | Version | Package Manager | Status |
|---|---|---|---|
| Ubuntu | 18.04 LTS+ | APT | ✓ Tested |
| Ubuntu | 20.04 LTS+ | APT | ✓ Tested |
| Ubuntu | 22.04 LTS+ | APT | ✓ Tested |
| Debian | 10+ | APT | ✓ Tested |
| Debian | 11+ | APT | ✓ Tested |
| CentOS | 7+ | YUM | ✓ Supported |
| RHEL | 7+ | YUM | ✓ Supported |
| Rocky Linux | 8+ | DNF | ✓ Supported |

---

## 🔄 Update Log

### v1.0.0 (2024-01-30)
- **Initial Release**
  - ✓ Hostname configuration with validation
  - ✓ Root password security hardening
  - ✓ System package updates (APT/YUM)
  - ✓ Comprehensive audit logging
  - ✓ Automatic backup system
  - ✓ Sysctl security hardening
  - ✓ Installation wrapper (Gist support)
  - ✓ Complete documentation

---

## 📄 License

**MIT License** - See [LICENSE](LICENSE) file for details

```
Copyright (c) 2024 memarzade-dev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

### Report Issues
- **Security Issues**: Email [security contact] (Do NOT open public issue)
- **Bugs**: Include OS version, bash version, and full error output
- **Features**: Describe use case and expected behavior

### Submit Changes
1. Fork repository
2. Create feature branch: `git checkout -b feature/your-feature`
3. Commit with clear messages: `git commit -m "feat: description"`
4. Push to branch: `git push origin feature/your-feature`
5. Open pull request with description

### Code Style
- Bash 4.0+ compatible
- Shellcheck compliant: `shellcheck linux-system-initializer-main.sh`
- 80-character line limit (where practical)
- Comprehensive comments for complex logic

---

## 📞 Support

### Documentation
- **README**: This file (comprehensive guide)
- **Logs**: `/var/log/system-initializer.log` (execution details)
- **Report**: `/var/log/system-initializer-report.txt` (summary)

### Getting Help
1. Check [Troubleshooting](#-troubleshooting) section
2. Review logs: `sudo tail -100 /var/log/system-initializer.log`
3. Check supported distributions and requirements
4. Open GitHub issue with:
   - OS and version
   - Bash version: `bash --version`
   - Full error output
   - Log file contents

### Community
- **GitHub Issues**: https://github.com/memarzade-dev/linux-system-initializer/issues
- **GitHub Discussions**: https://github.com/memarzade-dev/linux-system-initializer/discussions

---

## 🎯 Use Cases

### Production Server Setup
```bash
# Initialize new production server
sudo bash linux-system-initializer-main.sh
# - Updates all packages
# - Sets production hostname
# - Hardens security
# - Creates audit trail
```

### Post-Installation Configuration
```bash
# For servers already running (skip updates if applied)
sudo bash linux-system-initializer-main.sh --skip-update
```

### Hostname-Only Configuration
```bash
# For servers with custom package management
sudo bash linux-system-initializer-main.sh --skip-update --skip-packages
```

### Rapid Deployment (Gist)
```bash
# Single command installation + execution
curl -fsSL https://gist.github.com/memarzade-dev/[ID]/raw | sudo bash
```

---

## ⚖️ Liability & Warranty

**THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND**

- ✓ Comprehensive backups created before changes
- ✓ Rollback instructions provided
- ✓ Full audit trail maintained
- ⚠️ Always test in non-production first
- ⚠️ Keep backup drives accessible

---

## 🔗 Related Resources

- [Bash Strict Mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
- [Linux Security Hardening](https://wiki.debian.org/Hardening)
- [sysctl Configuration Guide](https://linux-kernel-labs.github.io/master/labs/networking_drivers/)
- [Hostname Management](https://wiki.archlinux.org/title/Hostname)
- [Shadow File Format](https://linux.die.net/man/5/shadow)

---

**Made with ❤️ by [memarzade-dev](https://github.com/memarzade-dev)**

Last Updated: 2024-01-30
