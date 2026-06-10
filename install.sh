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
CONFIG_FILE="${HOME}/.config/ramnotifier/threshold"
SERVICE_NAME="ramnotifier"

OLD_SERVICE_NAME="ram-monitor"
OLD_CONFIG_DIR="${HOME}/.config/ram-monitor"

err() { echo "ERROR: $*" >&2; exit 1; }

if [[ "${1:-}" == "--uninstall" ]]; then
    systemctl --user disable --now "${SERVICE_NAME}" 2>/dev/null || true
    rm -f "${BINDIR}/ramnotifier"
    rm -f "${BINDIR}/ramnotifier-settings"
    rm -f "${BINDIR}/ramnotifier-zenity"
    rm -f "${APPDIR}/ramnotifier-settings.desktop"
    rm -f "${ICONDIR}/ramnotifier.png"
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

# clean up old install
if systemctl --user is-active "${OLD_SERVICE_NAME}" &>/dev/null; then
    echo "  Removing previous ram-monitor service"
    systemctl --user disable --now "${OLD_SERVICE_NAME}" 2>/dev/null || true
fi
rm -f "${SERVICEDIR}/${OLD_SERVICE_NAME}.service"

# stop existing service before overwriting the binary
systemctl --user stop "${SERVICE_NAME}" 2>/dev/null || true

echo "Installing ${REPO} ${VERSION} (${ARCH})..."
echo "  Downloading ${URL}"

mkdir -p "${BINDIR}"
rm -f "${BINDIR}/ramnotifier"
curl -sSLf "${URL}" -o "${BINDIR}/ramnotifier" || err "Download failed (curl exit $?)"
chmod +x "${BINDIR}/ramnotifier"

# install settings script
echo "  Downloading settings script"
curl -sSLf "${SETTINGS_URL}" -o "${BINDIR}/ramnotifier-settings" || true
chmod +x "${BINDIR}/ramnotifier-settings" 2>/dev/null || true

# symlink so GTK uses our WM_CLASS instead of "zenity"
ln -sf /usr/bin/zenity "${BINDIR}/ramnotifier-zenity" 2>/dev/null || true

# install desktop entry
echo "  Installing desktop entry"
mkdir -p "${APPDIR}"
curl -sSLf "${DESKTOP_URL}" -o /tmp/ramnotifier-settings.desktop.tmp 2>/dev/null && {
    sed "s|__BINDIR__|${BINDIR}|g" /tmp/ramnotifier-settings.desktop.tmp > "${APPDIR}/ramnotifier-settings.desktop"
    rm -f /tmp/ramnotifier-settings.desktop.tmp
} || true

# install icon
echo "  Installing icon"
mkdir -p "${ICONDIR}"
curl -sSLf "${ICON_URL}" -o "${ICONDIR}/ramnotifier.png" 2>/dev/null || true

# migrate config file from old path
if [[ -f "${OLD_CONFIG_DIR}/threshold" ]] && [[ ! -f "${CONFIG_FILE}" ]]; then
    mkdir -p "$(dirname "${CONFIG_FILE}")"
    cp "${OLD_CONFIG_DIR}/threshold" "${CONFIG_FILE}"
fi

# default config file
mkdir -p "$(dirname "${CONFIG_FILE}")"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "500" > "${CONFIG_FILE}"
fi

# install systemd user service
mkdir -p "${SERVICEDIR}"
cat > "${SERVICEDIR}/${SERVICE_NAME}.service" << SYSTEMD
[Unit]
Description=RAM notifier with desktop notifications

[Service]
ExecStart=${BINDIR}/ramnotifier
Restart=on-failure

[Install]
WantedBy=default.target
SYSTEMD

systemctl --user daemon-reload
systemctl --user enable --now "${SERVICE_NAME}"

echo "Done. Check status: systemctl --user status ${SERVICE_NAME}"
