PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
APPDIR = $(HOME)/.local/share/applications
ICONDIR = $(HOME)/.local/share/icons/hicolor/48x48/apps
SERVICEDIR = $(HOME)/.config/systemd/user
CONFIGDIR = $(HOME)/.config/ram-monitor

.PHONY: build build-all install uninstall

build:
	go build -o ram-monitor .

build-all:
	GOOS=linux GOARCH=amd64 go build -o ram-monitor-linux-amd64 .
	GOOS=linux GOARCH=arm64 go build -o ram-monitor-linux-arm64 .

install: build
	systemctl --user stop ram-monitor 2>/dev/null || true
	mkdir -p $(BINDIR)
	cp ram-monitor $(BINDIR)/ram-monitor
	cp ram-monitor-settings.sh $(BINDIR)/ram-monitor-settings
	chmod +x $(BINDIR)/ram-monitor-settings
	mkdir -p $(APPDIR)
	sed 's|__BINDIR__|$(BINDIR)|g' ram-monitor-settings.desktop > $(APPDIR)/ram-monitor-settings.desktop
	mkdir -p $(ICONDIR)
	cp ram-monitor.png $(ICONDIR)/ram-monitor.png
	mkdir -p $(CONFIGDIR)
	[ -f $(CONFIGDIR)/threshold ] || echo 500 > $(CONFIGDIR)/threshold
	mkdir -p $(SERVICEDIR)
	sed 's|ExecStart=.*|ExecStart=$(BINDIR)/ram-monitor|' ram-monitor.service > $(SERVICEDIR)/ram-monitor.service
	systemctl --user daemon-reload
	systemctl --user enable --now ram-monitor

uninstall:
	systemctl --user disable --now ram-monitor 2>/dev/null || true
	rm -f $(BINDIR)/ram-monitor
	rm -f $(BINDIR)/ram-monitor-settings
	rm -f $(APPDIR)/ram-monitor-settings.desktop
	rm -f $(ICONDIR)/ram-monitor.png
	rm -f $(SERVICEDIR)/ram-monitor.service
	rm -f $(CONFIGDIR)/threshold
	systemctl --user daemon-reload
