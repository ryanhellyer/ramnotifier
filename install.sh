#!/usr/bin/env bash
set -euo pipefail

# ---- config: change these to match your repo ----
OWNER="${GITHUB_OWNER:-ryanhellyer}"
REPO="${GITHUB_REPO:-ramnotifier}"
# -------------------------------------------------

BINDIR="${HOME}/.local/bin"
APPDIR="${HOME}/.local/share/applications"
ICONDIR="${HOME}/.local/share/icons/hicolor/48x48/apps"
SERVICEDIR="${HOME}/.config/systemd/user"
CONFIG_FILE="${HOME}/.config/ram-monitor/threshold"
SERVICE_NAME="ram-monitor"

err() { echo "ERROR: $*" >&2; exit 1; }

if [[ "${1:-}" == "--uninstall" ]]; then
    systemctl --user disable --now "${SERVICE_NAME}" 2>/dev/null || true
    rm -f "${BINDIR}/ram-monitor"
    rm -f "${BINDIR}/ram-monitor-settings"
    rm -f "${APPDIR}/ram-monitor-settings.desktop"
    rm -f "${ICONDIR}/ram-monitor.png"
    rm -f "${SERVICEDIR}/${SERVICE_NAME}.service"
    rm -f "${CONFIG_FILE}"
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
SETTINGS_URL="https://raw.githubusercontent.com/${OWNER}/${REPO}/${VERSION}/ram-monitor-settings.sh"
DESKTOP_URL="https://raw.githubusercontent.com/${OWNER}/${REPO}/${VERSION}/ram-monitor-settings.desktop"
ICON_URL="https://raw.githubusercontent.com/${OWNER}/${REPO}/${VERSION}/ram-monitor.png"

echo "Installing ${REPO} ${VERSION} (${ARCH})..."
echo "  Downloading ${URL}"

mkdir -p "${BINDIR}"
curl -sSLf "${URL}" -o "${BINDIR}/ram-monitor" || err "Download failed"
chmod +x "${BINDIR}/ram-monitor"

# install settings script
echo "  Downloading settings script"
curl -sSLf "${SETTINGS_URL}" -o "${BINDIR}/ram-monitor-settings" || true
chmod +x "${BINDIR}/ram-monitor-settings" 2>/dev/null || true

# install desktop entry
echo "  Installing desktop entry"
mkdir -p "${APPDIR}"
curl -sSLf "${DESKTOP_URL}" -o /tmp/ram-monitor-settings.desktop.tmp 2>/dev/null && {
    sed "s|__BINDIR__|${BINDIR}|g" /tmp/ram-monitor-settings.desktop.tmp > "${APPDIR}/ram-monitor-settings.desktop"
    rm -f /tmp/ram-monitor-settings.desktop.tmp
} || true

# install icon
echo "  Installing icon"
mkdir -p "${ICONDIR}"
curl -sSLf "${ICON_URL}" -o "${ICONDIR}/ram-monitor.png" 2>/dev/null || true

# default config file
mkdir -p "$(dirname "${CONFIG_FILE}")"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "1500" > "${CONFIG_FILE}"
fi

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
