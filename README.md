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

## How it works

Polls `/proc/meminfo` every 5 seconds. Sends a desktop notification each time available RAM crosses into a worse (lower) threshold tier:

| Threshold | Alert |
|-----------|-------|
| 1500 MB   | Low Memory Alert |
| 1200 MB   | Low Memory Alert |
| 900 MB    | Low Memory Alert |
| 600 MB    | Low Memory Alert |
| 300 MB    | Low Memory Alert |
| 0 MB      | System Critical (exits) |

Alerts only fire once per threshold tier and reset when RAM recovers above 1500 MB.

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
rm ~/.local/bin/ram-monitor
rm ~/.config/systemd/user/ram-monitor.service
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
