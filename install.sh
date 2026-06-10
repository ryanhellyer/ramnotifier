#!/usr/bin/env bash
set -euo pipefail

# ---- config: change these to match your repo ----
OWNER="${GITHUB_OWNER:-you}"
REPO="${GITHUB_REPO:-ram-monitor}"
# -------------------------------------------------

BINDIR="${HOME}/.local/bin"
SERVICEDIR="${HOME}/.config/systemd/user"
SERVICE_NAME="ram-monitor"

err() { echo "ERROR: $*" >&2; exit 1; }

if [[ "${1:-}" == "--uninstall" ]]; then
    systemctl --user disable --now "${SERVICE_NAME}" 2>/dev/null || true
    rm -f "${BINDIR}/ram-monitor"
    rm -f "${SERVICEDIR}/${SERVICE_NAME}.service"
    systemctl --user daemon-reload
    echo "Uninstalled."
    exit 0
fi

# detect version: use args, then env, then latest release
if [[ -n "${1:-}" ]]; then
    VERSION="$1"
elif [[ -n "${GITHUB_VERSION:-}" ]]; then
    VERSION="${GITHUB_VERSION}"
else
    echo "Fetching latest release..."
    VERSION=$(curl -sSLf "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest" \
        | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/') \
        || err "Could not determine latest release version"
fi

# detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *)       err "Unsupported architecture: $ARCH" ;;
esac

BINARY="ram-monitor-linux-${ARCH}"
URL="https://github.com/${OWNER}/${REPO}/releases/download/${VERSION}/${BINARY}"

echo "Installing ${REPO} ${VERSION} (${ARCH})..."
echo "  Downloading ${URL}"

mkdir -p "${BINDIR}"
curl -sSLf "${URL}" -o "${BINDIR}/ram-monitor" || err "Download failed"
chmod +x "${BINDIR}/ram-monitor"

# install systemd user service
mkdir -p "${SERVICEDIR}"
cat > "${SERVICEDIR}/${SERVICE_NAME}.service" << SYSTEMD
[Unit]
Description=RAM monitor with desktop notifications

[Service]
ExecStart=${BINDIR}/ram-monitor
Restart=on-failure

[Install]
WantedBy=default.target
SYSTEMD

systemctl --user daemon-reload
systemctl --user enable --now "${SERVICE_NAME}"

echo "Done. Check status: systemctl --user status ${SERVICE_NAME}"
