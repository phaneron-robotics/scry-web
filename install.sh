#!/usr/bin/env bash
# scry-connect — one-line installer for a ROS 2 robot.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/phaneron-robotics/scry-web/master/install.sh | bash
#
# Or, with explicit mode selection:
#   curl -fsSL .../install.sh | SCRY_INSTALL_MODE=docker bash
#   curl -fsSL .../install.sh | SCRY_INSTALL_MODE=pip bash
#
# Flags via env var:
#   SCRY_INSTALL_MODE  = auto | docker | pip       (default: auto)
#   ROS_DISTRO         = humble | jazzy | …        (auto-detected if unset)
#   SCRY_PORT          = 5339                       (default)
#   SCRY_AUTH_MODE     = open | token | mtls        (default: open)
#   SCRY_NO_SYSTEMD    = 1                          (skip the unit install)
#
# What it does:
#   1. Detects ROS distro from $ROS_DISTRO or /opt/ros/*/setup.bash.
#   2. Picks an install mode:
#        - docker → pulls ghcr.io/phaneron-robotics/scry-connect:$ROS_DISTRO,
#                   writes a systemd unit that runs the container with the
#                   right --network/--ipc/--pid flags, starts it.
#        - pip    → installs scry-connect into ~/.local/bin via pip,
#                   writes a systemd user unit that sources ROS and execs
#                   scry-connect, starts it.
#   3. Prints the pairing QR.
#
# Idempotent: re-running upgrades in place.

set -euo pipefail

INFO=$'\033[1;36m[scry]\033[0m'
WARN=$'\033[1;33m[warn]\033[0m'
FAIL=$'\033[1;31m[fail]\033[0m'
OK=$'\033[1;32m[ ok ]\033[0m'

# ─── helpers ────────────────────────────────────────────────────────────

info() { echo -e "$INFO $*"; }
warn() { echo -e "$WARN $*" >&2; }
fail() { echo -e "$FAIL $*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

# Detect the ROS distro the user has installed. Returns the distro name
# on stdout, or empty string if none found. Honours ROS_DISTRO env var.
detect_ros_distro() {
    if [ -n "${ROS_DISTRO:-}" ] && [ -d "/opt/ros/${ROS_DISTRO}" ]; then
        echo "$ROS_DISTRO"
        return
    fi
    # Pick the most recent distro alphabetically (rolling > lyrical > kilted
    # > jazzy > iron > humble) so a multi-install host gets the newer one.
    # Users can pin via $ROS_DISTRO.
    local newest=""
    local candidate
    for candidate in humble iron jazzy kilted lyrical rolling; do
        if [ -f "/opt/ros/${candidate}/setup.bash" ]; then
            newest="$candidate"
        fi
    done
    echo "$newest"
}

# Pick an install mode: docker if available unless the user pinned to pip.
choose_mode() {
    local requested="${SCRY_INSTALL_MODE:-auto}"
    case "$requested" in
        docker|pip) echo "$requested"; return ;;
        auto)
            if has docker; then echo "docker"; else echo "pip"; fi
            ;;
        *)
            fail "unknown SCRY_INSTALL_MODE=$requested (expected: auto|docker|pip)"
            ;;
    esac
}

# Print the LAN IP for the pairing message.
host_ip() {
    hostname -I 2>/dev/null | awk '{print $1}' || hostname
}

# ─── mode implementations ───────────────────────────────────────────────

install_docker() {
    local distro="$1"
    local port="${SCRY_PORT:-5339}"
    local image="ghcr.io/phaneron-robotics/scry-connect:${distro}"

    info "Mode: docker (image: $image)"

    if ! docker info >/dev/null 2>&1; then
        fail "docker daemon is not reachable. Start it (\`sudo systemctl start docker\`) or run with SCRY_INSTALL_MODE=pip."
    fi

    info "Pulling image (this may take a couple of minutes on first run)…"
    docker pull "$image"

    if [ "${SCRY_NO_SYSTEMD:-0}" = "1" ]; then
        info "Skipping systemd unit (SCRY_NO_SYSTEMD=1)."
        info "Start manually with:"
        echo "    docker run -d --restart=unless-stopped --network=host --ipc=host --pid=host \\"
        echo "      -e ROS_DOMAIN_ID=\$ROS_DOMAIN_ID --name scry-connect $image"
        return
    fi

    local unit_dir="${HOME}/.config/systemd/user"
    mkdir -p "$unit_dir"
    local unit_path="${unit_dir}/scry-connect.service"

    cat > "$unit_path" <<EOF
[Unit]
Description=Scry Connect (Docker sidecar)
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=simple
ExecStartPre=-/usr/bin/docker rm -f scry-connect
ExecStart=/usr/bin/docker run --rm --name scry-connect \\
    --network=host --ipc=host --pid=host \\
    -e ROS_DOMAIN_ID=\${ROS_DOMAIN_ID:-0} \\
    -e SCRY_PORT=${port} \\
    -e SCRY_AUTH_MODE=\${SCRY_AUTH_MODE:-${SCRY_AUTH_MODE:-open}} \\
    -e SCRY_TOKEN=\${SCRY_TOKEN:-} \\
    -v scry_config:/home/scry/.config/scry \\
    -v scry_audit:/var/log/scry \\
    ${image}
ExecStop=/usr/bin/docker stop scry-connect
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    info "Installed systemd user unit: $unit_path"

    if has systemctl; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now scry-connect.service || \
            warn "systemctl --user enable failed (loginctl enable-linger may be required for headless boot)"
    fi

    # Give the container a moment to bind, then print the QR.
    sleep 3
    info "Pairing QR (scan with the Scry Android app):"
    docker exec scry-connect scry-connect --print-qr || \
        warn "Container not ready yet — try \`docker exec scry-connect scry-connect --print-qr\` shortly."
}

install_pip() {
    local distro="$1"
    local port="${SCRY_PORT:-5339}"

    info "Mode: pip (bare-metal, systemd user unit)"

    if ! has python3; then
        fail "python3 not found. Install it first (sudo apt install python3 python3-pip)."
    fi

    local pyver
    pyver=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    info "python3 ${pyver} detected"

    if ! has pip3; then
        fail "pip3 not found. Install it first (sudo apt install python3-pip)."
    fi

    # We install --user so we don't need sudo. The systemd user unit will
    # find scry-connect on ~/.local/bin/PATH.
    #
    # On Ubuntu 24.04+ (jazzy / kilted / rolling) and Ubuntu 26.04 (lyrical),
    # the system Python is PEP 668 externally-managed and pip refuses to
    # touch it without --break-system-packages. Detect support for that
    # flag and pass it through; older pip (Ubuntu 22.04 / humble) doesn't
    # know the flag and would error out if we passed it unconditionally.
    info "Installing scry-connect from PyPI…"
    local pip_args=("install" "--user" "--upgrade" "scry-connect")
    if pip3 install --help 2>/dev/null | grep -q break-system-packages; then
        pip_args=("install" "--user" "--break-system-packages" "--upgrade" "scry-connect")
    fi
    pip3 "${pip_args[@]}"

    # Make sure ~/.local/bin is on PATH for current shell hints.
    if ! echo ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
        warn "$HOME/.local/bin is not on \$PATH. Add to your shell rc:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi

    if [ "${SCRY_NO_SYSTEMD:-0}" = "1" ]; then
        info "Skipping systemd unit (SCRY_NO_SYSTEMD=1)."
        info "Start manually with:"
        echo "    source /opt/ros/${distro}/setup.bash"
        echo "    scry-connect --port ${port}"
        return
    fi

    local unit_dir="${HOME}/.config/systemd/user"
    mkdir -p "$unit_dir"
    local unit_path="${unit_dir}/scry-connect.service"

    cat > "$unit_path" <<EOF
[Unit]
Description=Scry Connect (MCP server for ROS 2)
After=network-online.target

[Service]
Type=simple
Environment="ROS_DISTRO=${distro}"
Environment="SCRY_PORT=${port}"
ExecStart=/bin/bash -lc 'source /opt/ros/\${ROS_DISTRO}/setup.bash && exec \$HOME/.local/bin/scry-connect'
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
    info "Installed systemd user unit: $unit_path"

    if has systemctl; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now scry-connect.service || \
            warn "systemctl --user enable failed (try \`loginctl enable-linger \$USER\` for headless boot)"
    fi

    sleep 2
    info "Pairing QR (scan with the Scry Android app):"
    "$HOME/.local/bin/scry-connect" --print-qr || \
        warn "scry-connect not started yet — run \`scry-connect --print-qr\` after sourcing your ROS setup.bash."
}

# ─── main ───────────────────────────────────────────────────────────────

info "scry-connect installer starting"

distro="$(detect_ros_distro)"
if [ -z "$distro" ]; then
    fail "No ROS 2 install detected under /opt/ros/. Install ROS 2 first:
       https://docs.ros.org/en/jazzy/Installation.html
       Then re-run this installer."
fi
info "ROS distro: ${distro}"

mode="$(choose_mode)"

case "$mode" in
    docker) install_docker "$distro" ;;
    pip)    install_pip "$distro" ;;
esac

ip="$(host_ip)"
port="${SCRY_PORT:-5339}"

echo
echo -e "$OK Install complete."
echo
echo "    Open the Scry Android app → Add robot → Scan QR"
echo "    or paste:  ${ip}:${port}"
echo
echo "Logs:"
case "$mode" in
    docker) echo "    docker logs -f scry-connect" ;;
    pip)    echo "    journalctl --user -fu scry-connect" ;;
esac
echo
