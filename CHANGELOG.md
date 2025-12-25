# 📜 Change Log

All notable changes to this project will be documented in this file.

## [v3.0.0] - 2025-12-25
### 🚀 Major Changes
- **Traefik v3 Upgrade**: Updated core stack to Traefik v3 (latest).
  - Resolves `client version 1.24 is too old` error on Docker Engine v27+.
  - Fully compatible with Docker API 1.44.
- **Authelia Stability Fixes**:
  - **Fixed 500 Internal Server Error**: Resolved YAML corruption issues caused by unescaped environment variables (`tr -d '"'`).
  - **Permission Hardening**: Added automated `chown 1000:1000` for Authelia data directory to ensure SQLite database creation.
  - **CRLF Auto-Correction**: The deployment script now automatically sanitizes Windows line endings on remote execution.

### 🛠️ Improvements
- **Pre-flight Checks**: Added SSL certificate verification in `instalar_traefik.sh`.
- **System Updates**: Included non-interactive `apt-get upgrade` to ensure host security.
- **Diagnostics**: Enhanced `diagnose.sh` for better log capture and configuration inspection.

## [v2.0.0] - 2025-12-23
### Added
- **Authelia Integration**: Replaced Basic Auth with Authelia for 2FA and SSO.
- **Remote Deployment**: Introduced `deploy.sh` for SSH-based remote installation.
- **Backup Rotation**: implemented automatic backup rotation for configuration files.

## [v1.0.0] - Initial Release
### Features
- Basic Traefik v2 setup.
- Let's Encrypt SSL automation.
- Dashboard with Basic Auth protection.
