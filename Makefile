PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
APPDIR = $(HOME)/.local/share/applications
ICONDIR = $(HOME)/.local/share/icons/hicolor/48x48/apps
SERVICEDIR = $(HOME)/.config/systemd/user
CONFIGDIR = $(HOME)/.config/ramnotifier

.PHONY: build build-all install uninstall

build:
	go build -o ram-monitor .

build-all:
	GOOS=linux GOARCH=amd64 go build -o ram-monitor-linux-amd64 .
	GOOS=linux GOARCH=arm64 go build -o ram-monitor-linux-arm64 .

install: build
	systemctl --user stop ramnotifier 2>/dev/null || true
	systemctl --user stop ram-monitor 2>/dev/null || true
	mkdir -p $(BINDIR)
	cp ram-monitor $(BINDIR)/ramnotifier
	cp ram-monitor-settings.sh $(BINDIR)/ramnotifier-settings
	chmod +x $(BINDIR)/ramnotifier-settings
	ln -sf /usr/bin/zenity $(BINDIR)/ramnotifier-zenity
	mkdir -p $(APPDIR)
	sed 's|__BINDIR__|$(BINDIR)|g' ram-monitor-settings.desktop > $(APPDIR)/ramnotifier-settings.desktop
	mkdir -p $(ICONDIR)
	cp ram-monitor.png $(ICONDIR)/ramnotifier.png
	mkdir -p $(CONFIGDIR)
	[ -f $(CONFIGDIR)/threshold ] || echo 500 > $(CONFIGDIR)/threshold
	mkdir -p $(SERVICEDIR)
	sed 's|ExecStart=.*|ExecStart=$(BINDIR)/ramnotifier|' ram-monitor.service > $(SERVICEDIR)/ramnotifier.service
	rm -f $(SERVICEDIR)/ram-monitor.service
	systemctl --user daemon-reload
	systemctl --user enable --now ramnotifier

uninstall:
	systemctl --user disable --now ramnotifier 2>/dev/null || true
	systemctl --user disable --now ram-monitor 2>/dev/null || true
	rm -f $(BINDIR)/ramnotifier
	rm -f $(BINDIR)/ramnotifier-settings
	rm -f $(BINDIR)/ramnotifier-zenity
	rm -f $(APPDIR)/ramnotifier-settings.desktop
	rm -f $(ICONDIR)/ramnotifier.png
	rm -f $(SERVICEDIR)/ramnotifier.service
	rm -f $(SERVICEDIR)/ram-monitor.service
	rm -f $(CONFIGDIR)/threshold
	systemctl --user daemon-reload
