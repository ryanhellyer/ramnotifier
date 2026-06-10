# RAM Notifier

A lightweight Linux desktop RAM monitor that sends tiered desktop notifications when available memory drops below configurable thresholds.

Requires a systemd-based Linux desktop with a D-Bus notification daemon (Ubuntu, Fedora, Debian, Arch, openSUSE, Bluefin, etc.).

## Install

```bash
curl -sSL https://raw.githubusercontent.com/you/ram-monitor/main/install.sh | bash
```

Downloads the binary to `~/.local/bin`, starts a background systemd user service, and auto-starts on login. No terminal window needed.

## Configure

Launch "RAM Monitor Settings" from your system menu. Opens a slider dialog — no terminal needed. Changes take effect immediately.

## How it works

Polls `/proc/meminfo` every 5 seconds. Fires a desktop notification only when available RAM drops into a lower of 5 equal tiers derived from your threshold. Resets when RAM recovers above the threshold.

## Uninstall

```bash
curl -sSL https://raw.githubusercontent.com/you/ram-monitor/main/install.sh | bash -s -- --uninstall
```

## Build from source

Requires Go 1.26+.

```bash
git clone https://github.com/you/ram-monitor.git
cd ram-monitor
make install
```

## Changelog

### v2

- Rewritten in Go. No external dependencies beyond a Linux desktop with D-Bus.
- Runs as a background systemd user service — no terminal window needed.
- Configurable top threshold stored at `~/.config/ram-monitor/threshold`.
- Settings UI via desktop entry (system menu → "RAM Monitor Settings"), with fallbacks: zenity → kdialog → terminal.
- Five alert tiers auto-scale from the configured top threshold.
- Alerts only fire when RAM gets worse; don't re-fire on recovery.
- SIGHUP reload — changing the config file takes effect immediately without restart.
- Cross-compiled binaries for linux/amd64 and linux/arm64 via GitHub Actions.
- One-line install script with `--uninstall` support.
- Fixed annoying bugs causing non-stop notifications in some situations

### v1

- Bash script packaged as a `.deb` for Ubuntu.
- Single-threshold alert when RAM dropped below 1000 MB.
- Required manual terminal execution and .deb installation via `dpkg`.
