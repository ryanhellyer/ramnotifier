PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
SERVICEDIR = $(HOME)/.config/systemd/user

.PHONY: build build-all install uninstall

build:
	go build -o ram-monitor .

build-all:
	GOOS=linux GOARCH=amd64 go build -o ram-monitor-linux-amd64 .
	GOOS=linux GOARCH=arm64 go build -o ram-monitor-linux-arm64 .

install: build
	mkdir -p $(BINDIR)
	cp ram-monitor $(BINDIR)/ram-monitor
	mkdir -p $(SERVICEDIR)
	sed 's|ExecStart=.*|ExecStart=$(BINDIR)/ram-monitor|' ram-monitor.service > $(SERVICEDIR)/ram-monitor.service
	systemctl --user daemon-reload
	systemctl --user enable --now ram-monitor

uninstall:
	systemctl --user disable --now ram-monitor 2>/dev/null || true
	rm -f $(BINDIR)/ram-monitor
	rm -f $(SERVICEDIR)/ram-monitor.service
	systemctl --user daemon-reload
