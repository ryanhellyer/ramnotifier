package main

import (
	"bufio"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/godbus/dbus/v5"
)

var lastAlertedThreshold int = 0

func configDir() string {
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		return filepath.Join(xdg, "ram-monitor")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "ram-monitor")
}

func configFilePath() string {
	return filepath.Join(configDir(), "threshold")
}

func readTopThreshold() int {
	data, err := os.ReadFile(configFilePath())
	if err != nil {
		return 1500
	}
	val, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil || val <= 0 {
		return 1500
	}
	return val
}

func getAvailableMemMB() (int, error) {
	file, err := os.Open("/proc/meminfo")
	if err != nil {
		return 0, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "MemAvailable:") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				kb, err := strconv.ParseUint(fields[1], 10, 64)
				if err != nil {
					return 0, err
				}
				return int(kb / 1024), nil
			}
		}
	}
	return 0, fmt.Errorf("MemAvailable not found")
}

func sendNotification(title, body string) {
	conn, err := dbus.SessionBus()
	if err != nil {
		fmt.Println("D-Bus connection error:", err)
		return
	}
	obj := conn.Object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
	obj.Call("org.freedesktop.Notifications.Notify", 0,
		"RAM-Monitor", uint32(0), "", title, body, []string{}, map[string]dbus.Variant{}, int32(-1),
	)
}

func main() {
	topThreshold := readTopThreshold()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGHUP)

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	fmt.Printf("Monitoring RAM (alert threshold: %d MB)...\n", topThreshold)

	for {
		select {
		case <-sigCh:
			newVal := readTopThreshold()
			if newVal != topThreshold {
				topThreshold = newVal
				lastAlertedThreshold = 0
				fmt.Printf("Config reloaded (alert threshold: %d MB)\n", topThreshold)
			}

		case <-ticker.C:
			availableMB, err := getAvailableMemMB()
			if err != nil {
				fmt.Println("Error:", err)
				continue
			}

			if availableMB <= 0 {
				sendNotification("System Critical", "Available RAM hit 0 MB. Goodbye!")
				os.Exit(1)
			}

			top := topThreshold
			step := top / 5
			if step < 1 {
				step = 1
			}

			var currentThreshold int = 0
			switch {
			case availableMB <= step:
				currentThreshold = step
			case availableMB <= step*2:
				currentThreshold = step * 2
			case availableMB <= step*3:
				currentThreshold = step * 3
			case availableMB <= step*4:
				currentThreshold = step * 4
			case availableMB <= top:
				currentThreshold = top
			}

			if currentThreshold > 0 {
				if lastAlertedThreshold == 0 || currentThreshold < lastAlertedThreshold {
					msg := fmt.Sprintf("Critical: Available RAM is down to %d MB!", availableMB)
					sendNotification("Low Memory Alert", msg)
					lastAlertedThreshold = currentThreshold
				}
			} else {
				lastAlertedThreshold = 0
			}
		}
	}
}
