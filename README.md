# 🚀 Fresh Server Init

<div align="center">

![Debian](https://img.shields.io/badge/Debian-12%2F13-blue?style=for-the-badge&logo=debian)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Bash](https://img.shields.io/badge/Shell-Bash-important?style=for-the-badge&logo=gnu-bash)
![Security](https://img.shields.io/badge/Security-Hardened-red?style=for-the-badge&logo=security)

**Production-ready server initialization with enterprise-grade security hardening.**

[✨ Features](#-features) • [🚀 Quick Start](#-quick-start) • [🔧 Usage](#-usage) • [🤝 Contributing](#-contributing)

</div>

---

## 📋 Overview

**Fresh Server Init** is a comprehensive bash script designed for rapid, secure, and professional server deployment on Debian 12/13 systems. It transforms a bare-metal server into a production-ready fortress with a single command.

### 🎯 What It Does

- **Automates server initialization** from fresh install to production-ready.
- **Implements security best practices** (firewall, fail2ban, SSH hardening).
- **Deploys modern development stacks** (Docker, Node.js, auto-SSL).
- **Optimizes system performance** (kernel, network, swap).
- **Provides visual feedback** with a hacker-style terminal UI.

---

## 🚀 Quick Start

### ⚡ One-Command Setup

Run the following command on your fresh Debian 12/13 server:

```bash
curl -sSL https://raw.githubusercontent.com/administrakt0r/new-server-init/main/setup.sh | sudo bash
```

### 📋 Interactive Menu

The script will launch an interactive menu where you can choose your deployment path:

1.  **Initialize GitHub repository & deploy** (Full Stack)
2.  **Server optimization only** (Hardening & Base Tools)
3.  **Exit**

---

## ⚡ Features

### 🛡️ Security Hardening
- **UFW Firewall**: Deny-by-default policy with rate limiting.
- **Fail2Ban**: Brute-force protection for SSH and other services.
- **SSH Hardening**: Disables root login, enforces key auth (optional), and secures configs.
- **Kernel Tuning**: Sysctl optimizations for security and network performance.
- **Intrusion Detection**: Native auditd rules and log monitoring.

### 🐳 Full Stack Deployment
- **Docker & Compose**: Latest stable versions.
- **Reverse Proxy**: Nginx-proxy with automated Let's Encrypt SSL.
- **Database/Cache**: Option to include PostgreSQL and Redis with generated secrets.
- **Git Integration**: Auto-deploy from public or private repositories.
- **Dockhand**: Optional simple Docker management UI.

### 🔧 System Optimizations
- **Memory**: Optimized swap configurations (zram/swapfile).
- **Network**: BBR congestion control and increased connection limits.
- **Tools**: Pre-installs essential tools (`htop`, `iotop`, `cur`, `git`, `vim`, etc.).

---

## 🔧 Usage Guide

### Prerequisites
- **OS**: Debian 12 or 13 (Fresh installation recommended).
- **User**: Root privileges (use `sudo` if not running as root).
- **Network**: Internet access for package downloads.

### Interactive Configuration
The script will prompt you for:
- **System Updates**: Automatically performs `apt update && apt upgrade`.
- **User Creation**: Creates a secure sudo user (default: `admin` or custom).
- **SSH Keys**: Option to add your public SSH key.
- **Stack Options**: (If deploying an app) Domain names, repo URLs, and service selections.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Created and maintained by [administrakt0r](https://github.com/administrakt0r)**

</div>
