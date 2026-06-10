#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/ramnotifier/threshold"
mkdir -p "$(dirname "${CONFIG_FILE}")"

TOTAL_RAM=$(awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)

CURRENT=500
if [[ -f "${CONFIG_FILE}" ]]; then
	CURRENT=$(cat "${CONFIG_FILE}")
fi

TITLE="RAM Notifier"
PROMPT="Available RAM below this value (in MB) will trigger a notification"

# zenity is chosen as the primary GUI toolkit because it is pre-installed by
# default on GNOME (Ubuntu default), XFCE, Cinnamon, MATE, and Budgie,
# covering the vast majority of desktop Linux users with no extra dependencies.
# Use a symlink if available so the WM_CLASS matches our desktop entry.
if command -v ramnotifier-zenity &>/dev/null; then
	ZENITY_BIN="ramnotifier-zenity"
elif command -v zenity &>/dev/null; then
	ZENITY_BIN="zenity"
fi

if [[ -n "${ZENITY_BIN:-}" ]]; then
	ZENITY_OUTPUT=$("${ZENITY_BIN}" --scale --title="${TITLE}" \
		--text="${PROMPT}" \
		--min-value=100 --max-value="${TOTAL_RAM}" --step=100 \
		--value="${CURRENT}" 2>/dev/null)
	ZENITY_EXIT=$?
	NEW="${ZENITY_OUTPUT}"
	if [[ ${ZENITY_EXIT} -ne 0 ]] && [[ -z "${NEW}" ]]; then
		exit 0
	fi

# kdialog is used on KDE Plasma, which bundles it out of the box.
elif command -v kdialog &>/dev/null; then
	KD_OUTPUT=$(kdialog --title "${TITLE}" \
		--slider "${PROMPT}" 100 "${TOTAL_RAM}" 100 "${CURRENT}" 2>/dev/null)
	KD_EXIT=$?
	NEW="${KD_OUTPUT}"
	if [[ ${KD_EXIT} -ne 0 ]] && [[ -z "${NEW}" ]]; then
		exit 0
	fi

# Fallback: plain terminal input when no GUI dialog tool is available.
elif [[ -t 0 ]]; then
	printf "Alert threshold (MB) [%d]: " "${CURRENT}"
	read -r NEW
	NEW="${NEW:-${CURRENT}}"

else
	echo "No supported dialog tool found (zenity, kdialog, or terminal)." >&2
	exit 1
fi

if [[ -n "${NEW}" ]] && [[ "${NEW}" =~ ^[0-9]+$ ]] && [[ "${NEW}" -ge 100 ]]; then
	echo "${NEW}" > "${CONFIG_FILE}"
	systemctl --user kill -s HUP ramnotifier 2>/dev/null || true
	echo "Threshold set to ${NEW} MB."
else
	echo "Invalid or cancelled input." >&2
	exit 1
fi
