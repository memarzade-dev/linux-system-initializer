# Linux System Initializer - Gist Installation

**One-liner Deployment for Production Servers**

## ⚡ Quick Deploy

```bash
curl -fsSL https://gist.github.com/memarzade-dev/30fea70654259f2b3b21252e8a782123/raw | sudo bash
```

or

```bash
wget -qO- https://gist.github.com/memarzade-dev/30fea70654259f2b3b21252e8a782123/raw | sudo bash
```

---

## 📋 What This Does

1. ✓ Updates all system packages (apt/yum)
2. ✓ Configures hostname with validation
3. ✓ Updates /etc/hosts for DNS resolution
4. ✓ Changes root password securely
5. ✓ Applies security hardening
6. ✓ Creates automatic backups

---

## 🔐 Requirements

- Linux server (Ubuntu 18.04+, Debian 10+, CentOS 7+)
- Root or sudo access
- Internet connectivity
- 100MB free disk space

---

## 💪 Password Requirements

- Minimum 12 characters
- Must include: UPPERCASE + lowercase + numbers + special chars
- Examples: `SecurePass123!@#`, `MyServ@Pass2024`

---

## ✅ After Installation

Verify success:

```bash
hostname                    # Check new hostname
grep "127.0.1.1" /etc/hosts # Verify hosts entry
sudo ls                     # Test new password
tail /var/log/system-initializer.log  # View audit log
```

---

## 📁 Backups Created

```
/var/backups/system-initializer/backup_[timestamp]/
├── hosts.bak
├── hostname.bak
└── shadow.bak
```

All changes can be rolled back using these backups.

---

## 🆘 Troubleshooting

### Sudo not working after password change?

```bash
# Emergency: Boot into recovery mode
# Or use:
su - root
# Then fix /etc/hosts manually if needed
```

### Hostname resolution fails?

```bash
# Verify /etc/hosts
cat /etc/hosts | grep 127.0.1.1

# Should show: 127.0.1.1 [your-hostname]
```

### Check what went wrong?

```bash
sudo tail -100 /var/log/system-initializer.log
cat /var/log/system-initializer-report.txt
```

---

## 📖 Full Documentation

For complete documentation, visit:

https://github.com/memarzade-dev/linux-system-initializer

---

**Made by memarzade-dev** | MIT License
