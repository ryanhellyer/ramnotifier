# RAM Notifier

A lightweight Linux desktop RAM notifier that sends tiered desktop notifications when available memory drops below configurable thresholds.

Requires a systemd-based Linux desktop with a D-Bus notification daemon (Ubuntu, Fedora, Debian, Arch, openSUSE, Bluefin, etc.).

## Install

```bash
curl -sSL https://raw.githubusercontent.com/ryanhellyer/ramnotifier/master/install.sh | bash
```

Downloads the binary to `~/.local/bin`, starts a background systemd user service, and auto-starts on login. No terminal window needed.

## Configure

Launch "RAM Notifier" from your system menu. Opens a slider dialog — no terminal needed. Changes take effect immediately.

## How it works

Polls `/proc/meminfo` every 5 seconds. Fires a desktop notification only when available RAM drops into a lower of 5 equal tiers derived from your threshold. Resets when RAM recovers above the threshold.

## Uninstall

```bash
curl -sSL https://raw.githubusercontent.com/ryanhellyer/ramnotifier/master/install.sh | bash -s -- --uninstall
```

## Build from source

Requires Go 1.26+.

```bash
git clone https://github.com/ryanhellyer/ramnotifier.git
cd ramnotifier
make install
```

## Changelog

### v2.0.1

- Fixed settings UI not writing config when launched from `.desktop` on Wayland.
- Fixed dock/taskbar showing "zenity" instead of "RAM Notifier" icon and name.
- Replaced `systemctl reload-or-restart` with `SIGHUP` for reliable config reload from desktop context.
- Migrated config path from `~/.config/ram-monitor` to `~/.config/ramnotifier`.

### v2.0

- Rewritten in Go. No external dependencies beyond a Linux desktop with D-Bus.
- Runs as a background systemd user service — no terminal window needed.
- Configurable top threshold stored at `~/.config/ramnotifier/threshold`.
- Settings UI via desktop entry (system menu → "RAM Notifier"), with fallbacks: zenity → kdialog → terminal.
- Five alert tiers auto-scale from the configured top threshold.
- Alerts only fire when RAM gets worse; don't re-fire on recovery.
- SIGHUP reload — changing the config file takes effect immediately without restart.
- Cross-compiled binaries for linux/amd64 and linux/arm64 via GitHub Actions.
- One-line install script with `--uninstall` support.
- Fixed annoying bugs causing non-stop notifications in some situations

### v1.0

- Bash script packaged as a `.deb` for Ubuntu.
- Single-threshold alert when RAM dropped below 1000 MB.
- Required manual terminal execution and .deb installation via `dpkg`.
