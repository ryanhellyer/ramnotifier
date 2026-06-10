# RAM Monitor

A lightweight Linux desktop RAM monitor that sends tiered desktop notifications when available memory drops below configurable thresholds.

## Install

```bash
curl -sSL https://raw.githubusercontent.com/you/ram-monitor/main/install.sh | bash
```

This downloads the binary, installs it to `~/.local/bin`, and starts it as a background systemd user service. Auto-starts on login. No terminal window needed.

To pin a specific version:

```bash
curl -sSL https://raw.githubusercontent.com/you/ram-monitor/main/install.sh | bash -s v1.0.0
```

### What gets installed

| Path | Purpose |
|------|---------|
| `~/.local/bin/ram-monitor` | Go binary (background service) |
| `~/.local/bin/ram-monitor-settings` | Settings UI script |
| `~/.local/share/applications/ram-monitor-settings.desktop` | Desktop entry (appears in system menu as "RAM Monitor Settings") |
| `~/.local/share/icons/hicolor/48x48/apps/ram-monitor.png` | App icon |
| `~/.config/systemd/user/ram-monitor.service` | systemd user unit (auto-starts on login) |
| `~/.config/ram-monitor/threshold` | Config file: top alert threshold in MB (default 1500) |

## Configure

**Via GUI:** launch "RAM Monitor Settings" from your system menu. Opens a slider dialog — no terminal needed. Changes take effect immediately.

**Or manually:** edit the config file, then reload the service.

```bash
echo 2000 > ~/.config/ram-monitor/threshold
systemctl --user reload-or-restart ram-monitor
```

The five alert tiers auto-scale from your top threshold. For example, at 1500 MB the tiers are 1500 / 1200 / 900 / 600 / 300. At 2000 MB they become 2000 / 1600 / 1200 / 800 / 400.

## How it works

Polls `/proc/meminfo` every 5 seconds. Sends a desktop notification each time available RAM crosses into a worse (lower) threshold tier:

| Threshold | Alert |
|-----------|-------|
| Top tier   | Low Memory Alert |
| Top × 80%  | Low Memory Alert |
| Top × 60%  | Low Memory Alert |
| Top × 40%  | Low Memory Alert |
| Top × 20%  | Low Memory Alert |
| 0 MB      | System Critical (exits) |

Alerts only fire once per threshold tier and reset when RAM recovers above the configured threshold.

## Manage

```bash
systemctl --user status ram-monitor   # check status
systemctl --user stop ram-monitor     # stop temporarily
systemctl --user disable ram-monitor  # stop permanently
journalctl --user -u ram-monitor -f   # follow logs
```

## Uninstall

```bash
curl -sSL https://raw.githubusercontent.com/you/ram-monitor/main/install.sh | bash -s -- --uninstall
```

Or manually:

```bash
systemctl --user disable --now ram-monitor
rm ~/.local/bin/ram-monitor ~/.local/bin/ram-monitor-settings
rm ~/.local/share/applications/ram-monitor-settings.desktop
rm ~/.local/share/icons/hicolor/48x48/apps/ram-monitor.png
rm ~/.config/systemd/user/ram-monitor.service
rm ~/.config/ram-monitor/threshold
systemctl --user daemon-reload
```

## Build from source

Requires Go 1.26+.

```bash
git clone https://github.com/you/ram-monitor.git
cd ram-monitor
make install
```

## Changelog

### v2.1.0

- Settings UI via desktop entry (system menu → "RAM Monitor Settings").
- Configurable top threshold stored at `~/.config/ram-monitor/threshold`.
- Five alert tiers auto-scale from the configured top threshold.
- SIGHUP reload — changing the config file takes effect immediately without restart.
- Multiple dialog fallbacks: zenity (GNOME/XFCE) → kdialog (KDE) → terminal.

### v2.0.0

- Rewritten in Go. No external dependencies beyond a Linux desktop with D-Bus.
- Runs as a background systemd user service — no terminal window needed.
- Tiered threshold alerts (1500 / 1200 / 900 / 600 / 300 / 0 MB).
- Alerts only fire when RAM gets worse; don't re-fire on recovery.
- Cross-compiled binaries for linux/amd64 and linux/arm64 via GitHub Actions.
- One-line install script with `--uninstall` support.

### v1.0.0

- Bash script packaged as a `.deb` for Ubuntu.
- Single-threshold alert when RAM dropped below 1000 MB.
- Required manual terminal execution and .deb installation via `dpkg`.
