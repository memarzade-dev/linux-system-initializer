# Contributing to Linux System Initializer

Danke für das Interesse, zum Linux System Initializer beizutragen! Dieses Dokument enthält Richtlinien und Anweisungen für Entwickler und Kontribuenten.

---

## 📋 Inhaltsverzeichnis

1. [Code of Conduct](#code-of-conduct)
2. [Erste Schritte](#erste-schritte)
3. [Development Setup](#development-setup)
4. [Coding Standards](#coding-standards)
5. [Submission Process](#submission-process)
6. [Testing Guidelines](#testing-guidelines)
7. [Security Considerations](#security-considerations)
8. [Commit Message Format](#commit-message-format)
9. [Pull Request Process](#pull-request-process)

---

## Code of Conduct

### Standards

Wir erwarten von allen Kontributoren:

- **Respekt**: Behandeln Sie alle Beteiligten mit Respekt und Fairness
- **Inklusion**: Akzeptieren Sie unterschiedliche Sichtweisen und Hintergründe
- **Sicherheit**: Berichten Sie Sicherheitsprobleme verantwortungsvoll
- **Professionalismus**: Kommunizieren Sie konstruktiv und sachlich
- **Transparenz**: Seien Sie offen über Motivationen und Änderungen

### Akzeptables Verhalten

- ✓ Hilfreiche Kommentare und Feedback
- ✓ Respekt für andere Meinungen
- ✓ Fokus auf das Beste für die Community
- ✓ Empathie gegenüber anderen Community-Mitgliedern
- ✓ Konstruktive Kritik und sachliche Diskussionen

### Inakzeptables Verhalten

- ✗ Beleidigungen, rassistische oder sexistische Kommentare
- ✗ Mobbing, Einschüchterung oder persönliche Angriffe
- ✗ Unwillkommene sexuelle Anmerkungen oder Aufmerksamkeit
- ✗ Trolling oder absichtliche Störungen
- ✗ Veröffentlichung privater Informationen ohne Zustimmung

---

## Erste Schritte

### Projektstruktur Verstehen

```
linux-system-initializer/
├── linux-system-initializer-main.sh    # Hauptskript (Kernlogik)
├── install.sh                           # Installations-Wrapper (Gist)
├── README.md                            # Dokumentation
├── CHANGELOG.md                         # Versionsgeschichte
├── LICENSE                              # MIT Lizenz
├── CONTRIBUTING.md                      # Dieses Dokument
└── .gitignore                           # Git-Ausschlüsse
```

### Fork & Clone

```bash
# Fork auf GitHub
# https://github.com/memarzade-dev/linux-system-initializer/fork

# Clone lokal
git clone https://github.com/YOUR-USERNAME/linux-system-initializer.git
cd linux-system-initializer

# Upstream-Remote hinzufügen (für Aktualisierungen)
git remote add upstream https://github.com/memarzade-dev/linux-system-initializer.git
```

---

## Development Setup

### Anforderungen

- **Bash**: 4.0+
- **ShellCheck**: Code-Analyse
- **Git**: Versionskontrolle
- **Linux/WSL2**: Für lokale Tests

### Installation Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y bash shellcheck git

# CentOS/RHEL
sudo yum install -y bash shellcheck git

# macOS (mit Homebrew)
brew install shellcheck
```

### Lokal Klonen und Testen

```bash
# Lokale Kopie in Test-VM vorbereiten
git clone YOUR-FORK
cd linux-system-initializer

# Bash-Syntax prüfen
bash -n linux-system-initializer-main.sh

# Mit ShellCheck analysieren
shellcheck linux-system-initializer-main.sh

# Test durchführen (in VM)
sudo bash linux-system-initializer-main.sh --help
```

---

## Coding Standards

### Bash Style Guide

#### Variablen
```bash
# Immer readonly für Konstanten
readonly CONFIG_FILE="/etc/config"
readonly VERSION="1.0.0"

# UPPERCASE für globale Konstanten
readonly MAX_ATTEMPTS=3
readonly LOG_FILE="/var/log/system.log"

# lowercase mit Unterstrich für Funktionsvariablen
local new_hostname=""
local password_strength=0
```

#### Funktionen
```bash
# Klare Benennung mit Präfix oder Suffix
validate_hostname() {
    local hostname="$1"
    # Validierungslogik
}

print_error() {
    echo "ERROR: $*" >&2
}

check_dependencies() {
    # Dependency-Prüfung
}
```

#### Fehlerbehandlung
```bash
# Bash Strict Mode (immer am Anfang)
set -euo pipefail
IFS=$'\n\t'

# Funktionen mit expliziten Rückgabewerten
validate_input() {
    [[ -n "$1" ]] && return 0 || return 1
}

# Try-catch ähnliche Struktur
if ! command "$arg"; then
    print_error "Command failed: $arg"
    return 1
fi
```

#### Kommentare
```bash
# Sektion Header
# ============================================================================
# SECTION NAME
# ============================================================================

# Inline-Kommentare für komplexe Logik
# Remove old 127.0.1.1 entries (sed with compatibility for macOS)
sed -i.bak "/^127\.0\.1\.1/d" "$file"

# TODO/FIXME mit Erklärung
# TODO: Add IPv6 support for dual-stack environments
```

#### Zeilenlänge
- **Zielwert**: 80 Zeichen
- **Maximum**: 120 Zeichen (bei Notwendigkeit)
- **Strings**: Können länger sein, wenn Umbruch unlesbar macht

### ShellCheck Compliance

Alle Scripts müssen ShellCheck-konform sein:

```bash
# Code muss erfolgreich prüfen
shellcheck linux-system-initializer-main.sh

# Keine Warnungen außer explizit deaktiviert
# shellcheck disable=SC2086  # Nur wenn notwendig
```

### Wichtige ShellCheck Richtlinien

| Code | Bedeutung | Aktion |
|------|---|---|
| SC2086 | Unquoted variable | Immer fixen |
| SC2181 | Exit code checking | Immer fixen |
| SC1090 | Source not found | Wenn lokal, fixen |
| SC2119 | Functions not called | Verhindern |

---

## Submission Process

### Issues Erstellen

#### Bug Reports

```markdown
**Beschreibung**:
Kurze Zusammenfassung des Problems

**Reproduktionsschritte**:
1. Befehl ausführen
2. Fehler beobachten

**Erwartetes Verhalten**:
Was sollte passieren

**Aktuelles Verhalten**:
Was tatsächlich passiert

**Umgebung**:
- OS: Ubuntu 20.04
- Bash: 5.0.17
- Git: Gist URL oder lokaler Test

**Logs**:
```bash
tail -20 /var/log/system-initializer.log
```
```

#### Feature Requests

```markdown
**Beschreibung**:
Was ist gewünscht und warum?

**Aktuelles Verhalten**:
Wie funktioniert es jetzt?

**Vorgeschlagene Lösung**:
Wie sollte es funktionieren?

**Alternativen**:
Andere Lösungsmöglichkeiten

**Zusätzlicher Kontext**:
Links, Referenzen, Beispiele
```

### Branches Erstellen

Verwenden Sie aussagekräftige Branch-Namen:

```bash
# Feature-Branch
git checkout -b feature/hostname-validation-ipv6

# Bug-Fix Branch
git checkout -b fix/sudo-hostname-resolution

# Documentation
git checkout -b docs/update-troubleshooting

# Refactoring
git checkout -b refactor/simplify-password-validation
```

---

## Testing Guidelines

### Lokale Tests

```bash
# Syntax-Prüfung
bash -n linux-system-initializer-main.sh

# ShellCheck
shellcheck linux-system-initializer-main.sh

# Trocken-Test (Variablen prüfen)
bash -x linux-system-initializer-main.sh 2>&1 | head -20

# Hilfe-Text
bash linux-system-initializer-main.sh --help
bash linux-system-initializer-main.sh --version
```

### VM-Tests (erforderlich vor PR)

```bash
# Test auf Ubuntu 20.04 LTS
# Test auf Debian 11
# Test auf CentOS 8 (YUM-Pfad)

# Checkliste:
# [ ] Hostname-Änderung funktioniert
# [ ] /etc/hosts korrekt aktualisiert
# [ ] Passwort-Validation funktioniert
# [ ] Backups erstellt
# [ ] Logs geschrieben
# [ ] sudo funktioniert nach Passwort-Änderung
```

### Regression Testing

```bash
# Zwei Mal hintereinander ausführen
sudo bash linux-system-initializer-main.sh --skip-update
sudo bash linux-system-initializer-main.sh --skip-update

# Überprüfen:
# [ ] Kein Fehler beim zweiten Durchlauf
# [ ] Hostname bleibt konsistent
# [ ] Logs richtig geschrieben
```

---

## Security Considerations

### Niemals in Commits

❌ **Nicht committed werden:**
- API Keys oder Tokens
- Passwörter oder Hashes
- Private SSH-Schlüssel
- Konfigurationsdateien mit Secrets
- Backup-Dateien (`.bak`, `.backup`)

✓ **Stattdessen:**
- `.gitignore` verwenden
- Beispieldateien mit `EXAMPLE_` Präfix
- Dokumentation für Konfiguration

### Sicherheitlich-Kritische Änderungen

Bei Änderungen in:
- Passwort-Validierung
- Datei-Berechtigungen
- Sudo-Verhalten
- Sicherheitsparameter

**Maßnahmen:**
1. Ausführliche Code-Review in PR
2. Sicherheitstesting dokumentieren
3. Changelogeinträge markieren `[SECURITY]`
4. Breaking-Change dokumentieren wenn nötig

### Sensitive Information Handling

```bash
# ✓ SICHER: Passwörter in Speicher, nicht in Variablen
read -rsp "Password: " password_var
echo "root:${password_var}" | chpasswd
unset password_var

# ❌ UNSICHER: Passwörter in Logs oder History
echo "Password: $password_var" >> /var/log/file.log
password_var="actual_password"
```

---

## Commit Message Format

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type

- `feat`: Neue Funktion
- `fix`: Bugfix
- `docs`: Dokumentation
- `style`: Code-Stil (keine Logik-Änderung)
- `refactor`: Code-Umstrukturierung
- `perf`: Performance-Optimierung
- `test`: Test-Hinzufügung/Änderung
- `chore`: Maintenance/Dependencies

### Beispiele

```
feat(password): Add complexity validation for special characters

- Require at least one special character
- Add visual feedback for requirements
- Update documentation with new requirements

Fixes #42
```

```
fix(hostname): Resolve localhost mapping in /etc/hosts

The script was not checking for existing localhost entries
before adding new 127.0.1.1 mapping.

- Add grep check for localhost entry
- Only add if not present
- Add test case for edge case

Fixes #38
```

```
docs: Update troubleshooting section with IPv6 guidance

Adds explanation and steps for IPv6 environments.
```

---

## Pull Request Process

### Vor Submission

1. **Branch auf dem neuesten Stand**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Commits bereinigen**:
   ```bash
   # Rebase mit Squash bei mehreren kleinen Commits
   git rebase -i upstream/main
   ```

3. **Tests durchführen**:
   - ShellCheck: `shellcheck linux-system-initializer-main.sh`
   - Bash-Syntax: `bash -n linux-system-initializer-main.sh`
   - Funktionale Tests auf echter VM
   - Regression-Tests

4. **Dokumentation aktualisieren**:
   - README.md wenn notwendig
   - CHANGELOG.md (unter [Unreleased])
   - Code-Kommentare

### PR-Vorlage

```markdown
## Beschreibung
Kurze Zusammenfassung der Änderungen.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests passed
- [ ] Manual testing on Ubuntu 20.04
- [ ] Manual testing on Debian 11
- [ ] Manual testing on CentOS 8
- [ ] Regression testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings in ShellCheck
- [ ] Commits are meaningful and squashed

## Fixes
Closes #[issue number]
```

### Review Prozess

**Durchschnittliche Review-Zeit**: 2-5 Tage

**Review-Kriterien**:
1. ✓ Code-Qualität und Stil
2. ✓ Sicherheitsauswirkungen
3. ✓ Vollständigkeit und Klarheit
4. ✓ Tests und Dokumentation
5. ✓ Abwärtskompatibilität

---

## Release Process

**Für Maintainer**:

```bash
# Versionierung aktualisieren
VERSION="1.1.0"

# CHANGELOG aktualisieren
# Version [1.1.0] hinzufügen mit Release-Datum

# Tag erstellen
git tag -a v1.1.0 -m "Release v1.1.0: Description"

# Push
git push origin main
git push origin v1.1.0

# GitHub Release erstellen
# CHANGELOG-Eintrag in Release-Notes verwenden
```

---

## Zusätzliche Ressourcen

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck Wiki](https://www.shellcheck.net/)
- [Bash Strict Mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

## Kontakt

- **Issues & Bugs**: GitHub Issues
- **Sicherheit**: Privat via Email (Details im SECURITY.md wenn vorhanden)
- **Fragen**: GitHub Discussions oder Issues

---

**Vielen Dank für Beiträge zu diesem Projekt!** 🙏

Made with ❤️ by the Linux System Initializer Community
