#!/usr/bin/env bash
#===============================================================================
#  Universal Server Setup Script for Debian 12/13
#  
#  Features:
#  - Interactive Git repository deployment with Docker
#  - nginx-proxy + auto Let's Encrypt SSL certificates
#  - Configurable services: PostgreSQL, Redis, etc.
#  - Node.js 22 + pnpm (for non-Docker builds)
#  - Kernel & network optimizations for high traffic
#  - UFW firewall + Fail2Ban security
#  - Automatic security updates
#  - Dockhand auto-configuration for Git autodeploy
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
SWAP_SIZE="2G"
DEPLOY_DIR="/var/www"
DOCKER_NETWORK="proxy-net"

#-------------------------------------------------------------------------------
# Hacker-Style UI & Colors
#-------------------------------------------------------------------------------
# Bold Neon Colors
RESET='\033[0m'
BOLD='\033[1m'
NEON_CYAN='\033[1;36m'
NEON_GREEN='\033[1;32m'
NEON_PURPLE='\033[1;35m'
NEON_RED='\033[1;31m'
NEON_YELLOW='\033[1;33m'
NEON_BLUE='\033[1;34m'

# Backgrounds
BG_RED='\033[41m'

# Icons
ICON_SUCCESS="${NEON_GREEN}✔${RESET}"
ICON_FAIL="${NEON_RED}✘${RESET}"
ICON_WARN="${NEON_YELLOW}⚠${RESET}"
ICON_INFO="${NEON_CYAN}ℹ${RESET}"
ICON_SEC="${NEON_RED}🛡${RESET}"
ICON_GEAR="${NEON_PURPLE}⚙${RESET}"

# Spinners
SPINNER_CHARS='⣾⣽⣻⢿⡿⣟⣯⣷'

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr=$SPINNER_CHARS
    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    tput cnorm
}

print_centered() {
    local text="$1"
    local color="${2:-$RESET}"
    local width=$(tput cols)
    local len=${#text}
    local pad=$(( (width - len) / 2 ))
    printf "%s%*s%s%s\n" "$color" $pad "" "$text" "$RESET"
}

print_divider() {
    local char="${1:-═}"
    local color="${2:-$NEON_PURPLE}"
    local width=$(tput cols)
    printf "$color"
    printf "%0.s$char" $(seq 1 $width)
    printf "$RESET\n"
}

log_header() {
    echo ""
    print_divider "═" "$NEON_PURPLE"
    print_centered "$1" "$NEON_CYAN"
    print_divider "═" "$NEON_PURPLE"
    echo ""
}

log_info() { echo -e "  ${ICON_INFO}  ${NEON_BLUE}$1${RESET}"; }
log_success() { echo -e "  ${ICON_SUCCESS}  ${NEON_GREEN}$1${RESET}"; }
log_warn() { echo -e "  ${ICON_WARN}  ${NEON_YELLOW}$1${RESET}"; }
log_error() { echo -e "  ${ICON_FAIL}  ${NEON_RED}$1${RESET}"; }
log_step() { echo -e "  ${ICON_GEAR}  ${NEON_PURPLE}$1${RESET}"; }
log_sec_warn() {
    echo ""
    echo -e "  ${BG_RED}${BOLD} SECURITY WARNING ${RESET} ${NEON_RED}$1${RESET}"
    echo ""
}

#-------------------------------------------------------------------------------
# Root Check
#-------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    log_error "This script requires root privileges. Try: sudo $0"
    exit 1
fi

#-------------------------------------------------------------------------------
# Interactive Prompts
#-------------------------------------------------------------------------------
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local answer
    
    if [ "$default" = "y" ]; then
        read -rp "$(echo -e "  ${NEON_CYAN}[?] $prompt ${NEON_PURPLE}[Y/n]${RESET}: ")" answer
        answer="${answer:-y}"
    else
        read -rp "$(echo -e "  ${NEON_CYAN}[?] $prompt ${NEON_PURPLE}[y/N]${RESET}: ")" answer
        answer="${answer:-n}"
    fi
    
    [[ "$answer" =~ ^[Yy]$ ]]
}

ask_input() {
    local prompt="$1"
    local default="${2:-}"
    local answer
    
    if [ -n "$default" ]; then
        read -rp "$(echo -e "  ${NEON_CYAN}[?] $prompt ${NEON_PURPLE}[$default]${RESET}: ")" answer
        echo "${answer:-$default}"
    else
        read -rp "$(echo -e "  ${NEON_CYAN}[?] $prompt${RESET}: ")" answer
        echo "$answer"
    fi
}

ask_password() {
    local prompt="$1"
    local answer
    read -rsp "$(echo -e "  ${NEON_CYAN}[?] $prompt${RESET}: ")" answer
    echo
    echo "$answer"
}

#-------------------------------------------------------------------------------
# Hacker Banner
#-------------------------------------------------------------------------------
clear
print_divider "═" "$NEON_PURPLE"
echo -e "${NEON_CYAN}"
cat << 'BANNER'
  _____              _       _____                               
 |  ___| __ ___  ___| |__   / _ \ \/ /
 | |_ | '__/ _ \/ __| '_ \ | | | \  / 
 |  _|| | |  __/\__ \ | | || |_| /  \ 
 |_|  |_|  \___||___/_| |_(_)___/_/\_\ -- INITIALIZED
                                       
        SERVER DEPLOYMENT SEQUENCE
BANNER
echo -e "${RESET}"
print_centered "CREDITS: SCRIPT BY ADMINISTRAT0R" "$NEON_PURPLE"
print_divider "═" "$NEON_PURPLE"
echo ""

#-------------------------------------------------------------------------------
# Gather Information
#-------------------------------------------------------------------------------
log_header "DEPLOYMENT CONFIGURATION"

DEPLOY_GIT="n"
GIT_URL=""
GIT_TOKEN=""
GIT_USER=""
APP_NAME=""
APP_DOMAINS=""
APP_EMAIL=""
INCLUDE_POSTGRES="n"
INCLUDE_REDIS="n"
INCLUDE_DOCKHAND="n"
DOCKHAND_DOMAIN=""
POSTGRES_PASSWORD=""
REDIS_PASSWORD=""

if ask_yes_no "Do you want to deploy a Git repository?" "n"; then
    DEPLOY_GIT="y"
    
    GIT_URL=$(ask_input "Git repository URL (e.g., https://github.com/user/repo.git)")
    
    if ask_yes_no "Is this a private repository?" "n"; then
        GIT_USER=$(ask_input "Git username")
        GIT_TOKEN=$(ask_password "Personal access token")
    fi
    
    APP_NAME=$(ask_input "Application name (used for container/folder)" "myapp")
    APP_DOMAINS=$(ask_input "Domain(s) for SSL (comma-separated, e.g., example.com,www.example.com)")
    APP_EMAIL=$(ask_input "Email for Let's Encrypt notifications" "admin@${APP_DOMAINS%%,*}")
    
    echo ""
    log_step "Select services to include in Docker Compose:"
    
    if ask_yes_no "Include PostgreSQL database?" "y"; then
        INCLUDE_POSTGRES="y"
        POSTGRES_PASSWORD=$(openssl rand -hex 24)
        log_info "Generated PostgreSQL password"
    fi
    
    if ask_yes_no "Include Redis cache?" "y"; then
        INCLUDE_REDIS="y"
        REDIS_PASSWORD=$(openssl rand -hex 24)
        log_info "Generated Redis password"
    fi
    
    if ask_yes_no "Include Dockhand (Docker management UI)?" "n"; then
        INCLUDE_DOCKHAND="y"
        DOCKHAND_DOMAIN=$(ask_input "Dockhand domain" "dockhand.${APP_DOMAINS%%,*}")
    fi
fi

echo ""
echo ""
log_step "Configuration complete. Starting automated setup..."
echo ""
echo ""

#-------------------------------------------------------------------------------
# System Update
#-------------------------------------------------------------------------------
log_header "SYSTEM UPDATE"
log_step "Updating system repositories & packages..."
export DEBIAN_FRONTEND=noninteractive
(apt update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold") > /dev/null 2>&1 &
show_spinner $!
log_success "System updated successfully"

#-------------------------------------------------------------------------------
# Base Packages & Security Tools
#-------------------------------------------------------------------------------
log_header "DEPENDENCY INSTALLATION"
log_step "Installing base tools & security packages..."
(apt install -y \
    curl ca-certificates gnupg lsb-release \
    build-essential git \
    ufw fail2ban \
    auditd acct \
    python3 python3-pip \
    unattended-upgrades \
    logrotate \
    htop iotop iftop \
    jq \
    net-tools dnsutils unzip wget) > /dev/null 2>&1 &
show_spinner $!

log_step "Enabling audit services..."
systemctl enable --now auditd acct > /dev/null 2>&1
log_success "Base packages & Audit tools installed"

#-------------------------------------------------------------------------------
# Docker Installation
#-------------------------------------------------------------------------------
log_header "DOCKER RUNTIME"
if ! command -v docker &>/dev/null; then
    log_step "Installing Docker Engine & Compose..."
    
    (install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt update -y
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin) > /dev/null 2>&1 &
    show_spinner $!
    
    systemctl enable docker > /dev/null 2>&1
    systemctl start docker > /dev/null 2>&1
    log_success "Docker installed & active"
else
    log_info "Docker is already installed"
fi

#-------------------------------------------------------------------------------
# Node.js 22 + pnpm (for local builds if needed)
#-------------------------------------------------------------------------------
log_header "NODE ENVIRONMENT"
if ! command -v node &>/dev/null; then
    log_step "Installing Node.js 22..."
    (curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt install -y nodejs) > /dev/null 2>&1 &
    show_spinner $!
fi

log_step "Enabling Corepack & pnpm..."
corepack enable
corepack prepare pnpm@latest --activate 2>/dev/null || true
log_success "Node.js environment ready"

#-------------------------------------------------------------------------------
# SSH Configuration
#-------------------------------------------------------------------------------
log_header "SSH SECURITY"
log_sec_warn "Hardening SSH configuration."

SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    # Basic hardening
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG" # Keeping 'yes' as per original script, change to 'no' for stricter security if keys are used
    sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"
    sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD_CONFIG"
    sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSHD_CONFIG"
    
    systemctl restart ssh
    log_success "SSH configuration secured"
fi

#-------------------------------------------------------------------------------
# Firewall (UFW)
#-------------------------------------------------------------------------------
log_header "FIREWALL SETUP"
log_step "Configuring UFW rules..."
(ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw limit ssh comment 'SSH rate limited'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 443/udp comment 'HTTP/3 QUIC'
ufw --force enable) > /dev/null 2>&1
log_success "Firewall enabled"

#-------------------------------------------------------------------------------
# Fail2Ban
#-------------------------------------------------------------------------------
log_header "INTRUSION PREVENTION"
log_step "Configuring Fail2Ban jails..."
cat >/etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 2h
EOF

systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban > /dev/null 2>&1
log_success "Fail2Ban active"

#-------------------------------------------------------------------------------
# Swap Configuration
#-------------------------------------------------------------------------------
if ! swapon --show | grep -q swapfile; then
    log_step "Creating ${SWAP_SIZE} swap file..."
    fallocate -l $SWAP_SIZE /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

#-------------------------------------------------------------------------------
# Kernel & Network Optimizations
#-------------------------------------------------------------------------------
log_header "SYSTEM HARDENING & OPTIMIZATION"
log_step "Applying rigorous kernel optimizations..."

cat >/etc/sysctl.d/99-server-optimizations.conf <<'EOF'
# Memory & Swap
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Filesystem & Handles
fs.file-max = 2097152
fs.suid_dumpable = 0
fs.inotify.max_user_watches = 1048576

# Kernel Security
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.sysrq = 0

# Network Core
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_max = 6291456
net.core.wmem_max = 6291456
net.core.default_qdisc = fq

# TCP Optimization
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rmem = 4096 87380 6291456
net.ipv4.tcp_wmem = 4096 87380 6291456
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_window_scaling = 1

# Network Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
EOF

sysctl --system > /dev/null 2>&1
log_success "Kernel optimizations applied"

#-------------------------------------------------------------------------------
# Deploy Git Repository with Docker
#-------------------------------------------------------------------------------
if [ "$DEPLOY_GIT" = "y" ]; then
    log_step "Deploying application: $APP_NAME"
    
    APP_DIR="$DEPLOY_DIR/$APP_NAME"
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    
    # Clone repository
    log_info "Cloning repository..."
    if [ -n "$GIT_TOKEN" ]; then
        AUTH_URL=$(echo "$GIT_URL" | sed "s|https://|https://${GIT_TOKEN}@|")
        # Use shallow clone for faster deployment
        git clone --depth 1 "$AUTH_URL" . || git pull origin main
    else
        # Use shallow clone for faster deployment
        git clone --depth 1 "$GIT_URL" . || git pull origin main
    fi
    
    # Generate secrets
    NEXTAUTH_SECRET=$(openssl rand -base64 32)
    
    # Create .env file
    log_info "Creating .env file..."
    cat >"$APP_DIR/.env" <<EOF
NODE_ENV=production
NEXTAUTH_SECRET=$NEXTAUTH_SECRET
NEXTAUTH_URL=https://${APP_DOMAINS%%,*}
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/${APP_NAME}
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
EOF
    
    # Create docker-compose.yml
    cat >"$APP_DIR/docker-compose.yml" <<EOF
services:
  nginx-proxy:
    image: nginxproxy/nginx-proxy:1.6-alpine
    container_name: nginx-proxy
    restart: always
    ports: ["80:80", "443:443"]
    volumes:
      - certs:/etc/nginx/certs:ro
      - html:/usr/share/nginx/html
      - vhost:/etc/nginx/vhost.d
      - /var/run/docker.sock:/tmp/docker.sock:ro
    networks: [${DOCKER_NETWORK}]

  acme-companion:
    image: nginxproxy/acme-companion:2.4
    container_name: nginx-proxy-acme
    restart: always
    volumes_from: [nginx-proxy]
    volumes:
      - certs:/etc/nginx/certs:rw
      - acme:/etc/acme.sh
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment: [DEFAULT_EMAIL=${APP_EMAIL}]
    networks: [${DOCKER_NETWORK}]

  app:
    build: .
    container_name: ${APP_NAME}_app
    restart: always
    expose: ["3000"]
    env_file: [.env]
    environment:
      VIRTUAL_HOST: ${APP_DOMAINS}
      VIRTUAL_PORT: 3000
      LETSENCRYPT_HOST: ${APP_DOMAINS}
    networks: [${DOCKER_NETWORK}, backend]
EOF

    if [ "$INCLUDE_POSTGRES" = "y" ]; then
        cat >>"$APP_DIR/docker-compose.yml" <<EOF
  db:
    image: postgres:16-alpine
    container_name: ${APP_NAME}_db
    restart: always
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: ${APP_NAME}
    volumes: [db_data:/var/lib/postgresql/data]
    networks: [backend]
EOF
    fi

    if [ "$INCLUDE_REDIS" = "y" ]; then
        cat >>"$APP_DIR/docker-compose.yml" <<EOF
  redis:
    image: redis:7-alpine
    container_name: ${APP_NAME}_redis
    restart: always
    command: redis-server --requirepass \${REDIS_PASSWORD}
    volumes: [redis_data:/data]
    networks: [backend]
EOF
    fi

    cat >>"$APP_DIR/docker-compose.yml" <<EOF
volumes:
  certs:
  html:
  vhost:
  acme:
EOF
    [ "$INCLUDE_POSTGRES" = "y" ] && echo "  db_data:" >> "$APP_DIR/docker-compose.yml"
    [ "$INCLUDE_REDIS" = "y" ] && echo "  redis_data:" >> "$APP_DIR/docker-compose.yml"

    cat >>"$APP_DIR/docker-compose.yml" <<EOF
networks:
  ${DOCKER_NETWORK}: { name: ${DOCKER_NETWORK} }
  backend: { name: ${APP_NAME}-backend }
EOF

    # Dockhand Config
    if [ "$INCLUDE_DOCKHAND" = "y" ]; then
        DOCKHAND_PW=$(openssl rand -hex 16)
        cat >"$APP_DIR/docker-compose.dockhand.yml" <<EOF
services:
  dockhand-db:
    image: postgres:16-alpine
    container_name: dockhand_db
    restart: always
    environment:
      POSTGRES_USER: dockhand
      POSTGRES_PASSWORD: ${DOCKHAND_PW}
      POSTGRES_DB: dockhand
    volumes: [dockhand_db:/var/lib/postgresql/data]
    networks: [dockhand-internal]

  dockhand:
    image: fnsys/dockhand:latest
    container_name: dockhand_app
    restart: always
    expose: ["3000"]
    environment:
      DATABASE_URL: postgres://dockhand:${DOCKHAND_PW}@dockhand-db:5432/dockhand
      VIRTUAL_HOST: ${DOCKHAND_DOMAIN}
      VIRTUAL_PORT: 3000
      LETSENCRYPT_HOST: ${DOCKHAND_DOMAIN}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - dockhand_data:/app/data
    networks: [dockhand-internal, ${DOCKER_NETWORK}]

volumes: { dockhand_db: , dockhand_data: }
networks:
  dockhand-internal:
  ${DOCKER_NETWORK}: { external: true }
EOF
    fi

    # Start
    docker compose up -d --build
    [ "$INCLUDE_DOCKHAND" = "y" ] && docker compose -f docker-compose.dockhand.yml up -d

    # AUTOMATE DOCKHAND DB CONFIG (PRIVATE REPO)
    if [ "$INCLUDE_DOCKHAND" = "y" ] && [ -n "$GIT_TOKEN" ]; then
        log_info "Automating Dockhand configuration for private repo..."
        sleep 10
        WEB_SECRET=$(openssl rand -hex 12)
        docker exec -i dockhand_postgres psql -U dockhand -d dockhand -c \
            "INSERT INTO git_credentials (name, auth_type, username, password) VALUES ('$GIT_USER', 'password', '$GIT_USER', '$GIT_TOKEN') ON CONFLICT DO NOTHING;"
        CRED_ID=$(docker exec -i dockhand_postgres psql -U dockhand -d dockhand -t -c "SELECT id FROM git_credentials WHERE name='$GIT_USER';")
        docker exec -i dockhand_postgres psql -U dockhand -d dockhand -c \
            "INSERT INTO git_repositories (name, url, branch, credential_id, environment_id, webhook_enabled, auto_update) VALUES ('$APP_NAME', '$GIT_URL', 'main', ${CRED_ID// /}, 1, true, true) ON CONFLICT DO NOTHING;"
        REPO_ID=$(docker exec -i dockhand_postgres psql -U dockhand -d dockhand -t -c "SELECT id FROM git_repositories WHERE name='$APP_NAME';")
        docker exec -i dockhand_postgres psql -U dockhand -d dockhand -c \
            "INSERT INTO git_stacks (stack_name, environment_id, repository_id, compose_path, auto_update, webhook_enabled, webhook_secret, env_file_path) VALUES ('$APP_NAME', 1, ${REPO_ID// /}, 'docker-compose.yml', true, true, '$WEB_SECRET', '.env') ON CONFLICT DO NOTHING;"
        STACK_ID=$(docker exec -i dockhand_postgres psql -U dockhand -d dockhand -t -c "SELECT id FROM git_stacks WHERE stack_name='$APP_NAME';")
        
        log_info "Dockhand configured! Webhook URL: https://${DOCKHAND_DOMAIN}/api/git/stacks/${STACK_ID// /}/webhook"
        log_info "Webhook Secret: $WEB_SECRET"
    fi
fi

log_header "DEPLOYMENT SUCCESSFUL"
echo -e "  ${NEON_GREEN}Server initialization complete. System is hardened and ready.${RESET}"
echo -e "  ${NEON_BLUE}Access your applications at the configured domains.${RESET}"
print_divider "═" "$NEON_PURPLE"
echo ""
