# Testing & Quality Assurance Guide

Production-grade testing strategy für Linux System Initializer.

---

## 📋 Testing Categories

### 1. Static Analysis

#### ShellCheck Compliance

```bash
# Full analysis
shellcheck linux-system-initializer-main.sh

# Specific checks
shellcheck -x linux-system-initializer-main.sh    # Follow sources
shellcheck -S error linux-system-initializer-main.sh  # Treat warnings as errors

# Output should be: OK
```

**Required Checks:**
- SC2086: Proper quoting of variables
- SC2181: Exit code verification
- SC2119: Function arguments
- SC1090: Source file resolution

#### Bash Syntax Validation

```bash
# Syntax check (no execution)
bash -n linux-system-initializer-main.sh

# Parse only
bash --norc -n linux-system-initializer-main.sh

# Check all scripts
for script in *.sh; do
    bash -n "$script" || echo "FAIL: $script"
done
```

#### Code Quality Metrics

```bash
# Line count
wc -l linux-system-initializer-main.sh

# Function count
grep -c "^[a-z_]*() {" linux-system-initializer-main.sh

# Comment ratio
echo "scale=2; $(grep -c "^\s*#" linux-system-initializer-main.sh) * 100 / $(wc -l < linux-system-initializer-main.sh)" | bc
```

---

### 2. Unit Testing

#### Variable Scoping Tests

```bash
# Check for unintended globals
grep "^\s*[A-Z_]*=" linux-system-initializer-main.sh | grep -v "readonly"

# Expected: Only readonly constants or no matches
```

#### Function Independence Tests

```bash
# Test individual functions
source linux-system-initializer-main.sh

# Test password validation
validate_password_strength "Short1!" 12        # Should fail
validate_password_strength "Secure@Pass123" 12 # Should pass

# Test hostname validation  
validate_hostname "valid-hostname"             # Should pass
validate_hostname "invalid_hostname"           # Should fail
validate_hostname "-invalid"                   # Should fail
```

#### Error Handling Tests

```bash
# Test error conditions
bash -x linux-system-initializer-main.sh 2>&1 | grep -i error | head -5

# Test with invalid input (non-interactive)
echo | bash linux-system-initializer-main.sh 2>&1 | grep -i "empty"
```

---

### 3. Functional Testing

#### Prerequisites Check

```bash
# Distribution detection
source linux-system-initializer-main.sh
detect_distribution
echo "Distribution: $DISTRIBUTION, Manager: $PACKAGE_MANAGER"
```

#### File Operations Testing

```bash
# Test on non-production system only
# Create test environment
mkdir -p /tmp/test-system-init/{etc,var/log,var/backups}
touch /tmp/test-system-init/etc/hosts
touch /tmp/test-system-init/etc/hostname

# Validate file handling
ls -la /tmp/test-system-init/

# Cleanup
rm -rf /tmp/test-system-init
```

#### Integration Tests

```bash
# Dry run tests (check logic without root)
bash linux-system-initializer-main.sh --help
bash linux-system-initializer-main.sh --version

# Check flag parsing
bash -x linux-system-initializer-main.sh --skip-update 2>&1 | grep "SKIP_UPDATE"
```

---

### 4. System Integration Testing

#### Pre-Execution Checklist

```bash
# Verify no conflicting processes
ps aux | grep -i "apt\|yum\|dnf" | grep -v grep

# Check disk space
df -h / | awk 'NR==2 {if ($4 !~ /G/) print "WARNING: Less than 1GB free"}'

# Check network connectivity
ping -c 1 8.8.8.8 > /dev/null 2>&1 && echo "Network OK" || echo "Network FAIL"
```

#### Full System Execution (Test VM Only)

```bash
# Preparation
sudo su -
cd /home/user/linux-system-initializer

# Execute
sudo bash linux-system-initializer-main.sh <<EOF
test-hostname
TestPass123!@#
TestPass123!@#
EOF

# Verification
echo "Exit code: $?"
tail -50 /var/log/system-initializer.log
cat /var/log/system-initializer-report.txt
```

#### Verification After Execution

```bash
# 1. Hostname verification
hostname
cat /etc/hostname
grep "127.0.1.1" /etc/hosts

# 2. Resolution testing
getent hosts $(hostname)
ping -c 1 $(hostname)

# 3. Backup verification
ls -la /var/backups/system-initializer/
stat /var/log/system-initializer.log

# 4. Security hardening
sysctl net.ipv4.ip_forward
sysctl kernel.sysrq

# 5. Root access test
sudo whoami
```

---

### 5. Regression Testing

#### Multi-Execution Test

```bash
# Execute twice to verify idempotency
HOSTNAME_TEST="regression-test"

# First run
sudo bash linux-system-initializer-main.sh --skip-update <<EOF
${HOSTNAME_TEST}
Pass123!@#abc
Pass123!@#abc
EOF

# Verify first run
hostname | grep "$HOSTNAME_TEST"

# Second run (should complete without errors)
sudo bash linux-system-initializer-main.sh --skip-update <<EOF
${HOSTNAME_TEST}
Pass123!@#abc
Pass123!@#abc
EOF

# Verify second run (hostname unchanged)
hostname | grep "$HOSTNAME_TEST"
```

#### Backward Compatibility Tests

```bash
# Test with older-style /etc/hosts
cat > /tmp/old_hosts << 'EOF'
127.0.0.1   localhost
127.0.1.1   old-hostname.localdomain old-hostname
::1         localhost ip6-localhost ip6-loopback
EOF

# Verify script handles correctly
grep -v "^127.0.1.1" /tmp/old_hosts | wc -l
```

---

### 6. Distribution-Specific Testing

#### Ubuntu 20.04 LTS Testing

```bash
# Version check
lsb_release -a
cat /etc/os-release | grep "VERSION="

# Execute
sudo bash linux-system-initializer-main.sh --skip-update

# Verify
hostname
apt-get --version
```

#### Ubuntu 22.04 LTS Testing

```bash
# Similar to 20.04
# Verify systemd version
systemctl --version
```

#### Debian 11 Testing

```bash
# Version check
cat /etc/debian_version

# APT behavior may differ
apt --version

# Execute and verify
sudo bash linux-system-initializer-main.sh --skip-update
```

#### CentOS/RHEL Testing

```bash
# Version check
cat /etc/redhat-release

# YUM path verification
which yum
yum --version

# Execute
sudo bash linux-system-initializer-main.sh --skip-update

# Verify
hostname
yum list updates
```

---

### 7. Security Testing

#### Input Validation Testing

```bash
# Hostname validation edge cases
test_hostnames=(
    "valid-name"           # Valid
    "123"                  # Valid
    "name-with-123"        # Valid
    "-invalid"             # Invalid (starts with hyphen)
    "invalid-"             # Invalid (ends with hyphen)
    "invalid_name"         # Invalid (underscore)
    "invalid@name"         # Invalid (special char)
    "very-long-hostname-exceeding-63-character-limit-should-fail-validation" # Invalid
    ""                     # Invalid (empty)
)

source linux-system-initializer-main.sh

for hostname in "${test_hostnames[@]}"; do
    if validate_hostname "$hostname"; then
        echo "✓ Valid: $hostname"
    else
        echo "✗ Invalid: $hostname"
    fi
done
```

#### Password Strength Testing

```bash
source linux-system-initializer-main.sh

test_passwords=(
    "short"                        # Fail (too short)
    "NoSpecial123"                 # Fail (no special char)
    "NoNumbers!@#"                 # Fail (no numbers)
    "nouppercase123!@#"            # Fail (no uppercase)
    "NOLOWERCASE123!@#"            # Fail (no lowercase)
    "ValidPass123!@#"              # Pass
    "C0mpl3x!P@ssw0rd"             # Pass
)

for password in "${test_passwords[@]}"; do
    if validate_password_strength "$password" 12; then
        echo "✓ Strong: $password"
    else
        echo "✗ Weak: $password"
    fi
done
```

#### Permission Testing

```bash
# After execution:
stat -c "%a %u:%g" /var/log/system-initializer.log
# Should be: 600 root:root

stat -c "%a %u:%g" /var/backups/system-initializer
# Should be: 700 root:root

stat -c "%a %u:%g" /var/backups/system-initializer/backup_*/shadow.bak
# Should be: 000 root:root
```

---

### 8. Performance Testing

#### Execution Time Measurement

```bash
# Time full execution
time sudo bash linux-system-initializer-main.sh --skip-update <<EOF
perf-test-host
Pass123!@#abc
Pass123!@#abc
EOF

# Expected time: 15-30 seconds on modern hardware
```

#### Resource Usage

```bash
# Monitor during execution
watch -n 1 "ps aux | grep [l]inux-system-initializer"
watch -n 1 "free -h"
watch -n 1 "df -h /"
```

#### Log File Size

```bash
# After execution
du -h /var/log/system-initializer.log
du -h /var/backups/system-initializer/

# Expected log size: < 100KB
# Expected backup size: < 1MB
```

---

### 9. Log & Audit Testing

#### Log File Validation

```bash
# Check log exists and is readable
ls -la /var/log/system-initializer.log
file /var/log/system-initializer.log

# Verify no sensitive data in logs
grep -i "password\|secret\|token" /var/log/system-initializer.log
# Should return: nothing

# Check timestamp format
grep "^\[" /var/log/system-initializer.log | head -3
```

#### Audit Trail Completeness

```bash
# Verify all operations logged
grep "\[INFO\]" /var/log/system-initializer.log | wc -l
# Should have entries for:
# - Distribution detection
# - Backup creation
# - Hostname configuration
# - Password change
# - Security hardening

# Check error handling
grep "\[ERROR\]" /var/log/system-initializer.log
# Should be empty if execution successful
```

---

### 10. Documentation Testing

#### README Verification

```bash
# Check all sections exist
grep "^##" README.md

# Required sections:
# - Quick Start
# - Features
# - Prerequisites
# - Usage
# - Troubleshooting
# - Verification Steps
# - Rollback Instructions
```

#### Code Comments Testing

```bash
# Verify complex logic has comments
grep -B 1 "sed -i" linux-system-initializer-main.sh | grep "#"

# Check function documentation
grep -A 1 "^[a-z_]*() {" linux-system-initializer-main.sh | head -20
```

---

## Test Execution Matrix

| Component | Type | Distribution | Status |
|-----------|------|---|---|
| Syntax | Static | All | Required |
| ShellCheck | Static | All | Required |
| Hostname Validation | Unit | All | Required |
| Password Validation | Unit | All | Required |
| Ubuntu 20.04 | Integration | Ubuntu 20.04 | Required |
| Debian 11 | Integration | Debian 11 | Required |
| CentOS 8 | Integration | CentOS 8 | Required |
| Regression | Functional | Primary | Required |
| Security | Penetration | Primary | Required |
| Performance | Load | Primary | Optional |

---

## Test Result Documentation

### Pass Criteria

- ✓ All ShellCheck warnings resolved
- ✓ Bash syntax validation passes
- ✓ All unit tests pass
- ✓ Functional tests on 3 distributions pass
- ✓ No regressions on repeated execution
- ✓ All security tests pass
- ✓ Documentation complete and accurate
- ✓ No performance degradation

### Failure Handling

If any test fails:
1. Document failure with exact error
2. Analyze root cause
3. Implement fix
4. Re-run all related tests
5. Update CHANGELOG.md
6. Do not merge without resolution

---

## Continuous Testing (CI/CD)

### Planned GitHub Actions

```yaml
name: Quality Assurance

on: [push, pull_request]

jobs:
  static-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: sudo apt install shellcheck
      - run: shellcheck linux-system-initializer-main.sh
      - run: bash -n linux-system-initializer-main.sh

  functional-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: bash linux-system-initializer-main.sh --help
      - run: bash linux-system-initializer-main.sh --version
```

---

## Test Maintenance

- Review tests quarterly
- Update for new distributions
- Add tests for reported bugs
- Remove obsolete test cases
- Document all test changes

---

**Rigorous testing ensures production reliability.** 🧪
