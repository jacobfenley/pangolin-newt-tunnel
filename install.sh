#!/bin/bash
set -e

# ============================================================
# Pangolin Newt — Full Server Setup
# ============================================================
# Installs Docker (if needed), configures boot persistence,
# runs the credential wizard, and starts the tunnel.
# Target: Debian/Ubuntu (Hetzner VPS or compatible)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_JSON="/etc/docker/daemon.json"

# ---- Helpers ------------------------------------------------

info() { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

# ---- Root check ---------------------------------------------

if [ "$EUID" -ne 0 ] && [ "$(id -u)" -ne 0 ]; then
    die "This script must be run as root or with sudo. Re-run: sudo ./install.sh"
fi

# ---- OS check -----------------------------------------------

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_ID_LIKE="${ID_LIKE:-}"
else
    die "Cannot determine OS. /etc/os-release not found. This script targets Debian/Ubuntu."
fi

is_debian_based() {
    case "$OS_ID" in
        debian|ubuntu|linuxmint|pop) return 0 ;;
    esac
    case "$OS_ID_LIKE" in
        *debian*|*ubuntu*) return 0 ;;
    esac
    return 1
}

if ! is_debian_based; then
    die "Unsupported OS: $OS_ID. This script targets Debian/Ubuntu. Exiting."
fi

info "Detected OS: $PRETTY_NAME"

# ---- Docker install -----------------------------------------

install_docker() {
    info "Installing Docker from the official Docker apt repository..."

    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${OS_ID} \
$(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    info "Docker installed successfully."
}

if command -v docker &>/dev/null; then
    info "Docker is already installed: $(docker --version)"
else
    install_docker
fi

# ---- Enable and start Docker --------------------------------

info "Enabling Docker to start on boot..."
systemctl enable docker

info "Starting Docker service..."
systemctl start docker

# ---- Verify Docker is running -------------------------------

if ! systemctl is-active --quiet docker; then
    die "Docker service failed to start. Check: systemctl status docker"
fi
info "Docker service is running."

# ---- Write daemon.json --------------------------------------

if [ -f "$DAEMON_JSON" ]; then
    warn "$DAEMON_JSON already exists — skipping write. Ensure 'live-restore: true' is set manually if needed."
else
    info "Writing $DAEMON_JSON with live-restore enabled..."
    cat > "$DAEMON_JSON" <<'EOF'
{
  "live-restore": true
}
EOF
    info "$DAEMON_JSON written."
fi

# ---- Run credential wizard ----------------------------------

SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"

if [ ! -f "$SETUP_SCRIPT" ]; then
    die "setup.sh not found in $SCRIPT_DIR. Ensure setup.sh is in the same directory as install.sh."
fi

if [ ! -x "$SETUP_SCRIPT" ]; then
    chmod +x "$SETUP_SCRIPT"
fi

info "Running credential wizard..."
echo ""
"$SETUP_SCRIPT"

# Verify wizard produced the env file
if [ ! -f "$SCRIPT_DIR/newt.env" ]; then
    die "setup.sh did not produce newt.env. Cannot start the tunnel."
fi

# ---- Start tunnel -------------------------------------------

info "Starting Newt tunnel..."
cd "$SCRIPT_DIR"
docker compose up -d

# ---- Verify containers are running --------------------------

echo ""
info "Checking container status..."
docker compose ps

# ---- Final status block -------------------------------------

echo ""
echo "========================================"
echo "  Newt tunnel is running."
echo ""
echo "  Logs:"
echo "    docker compose logs -f newt"
echo ""
echo "  Status:"
echo "    docker compose ps"
echo ""
echo "  Tunnel will start automatically on every reboot."
echo "  To stop: docker compose down"
echo "  To bounce: docker compose restart"
echo "  To update: ./update.sh"
echo "========================================"
echo ""
