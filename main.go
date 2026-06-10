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

// dbusConn is opened once at startup and reused for all notifications,
// avoiding the overhead of a new session bus connection per alert.
var dbusConn *dbus.Conn

// lastNotifID stores the ID returned by the notification daemon on the most
// recent Notify call.  It is passed as replaces_id so subsequent alerts
// update the existing notification in-place instead of piling up new ones.
// Reset to 0 on SIGHUP (config reload) so the next alert spawns a fresh notification.
var lastNotifID uint32 = 0

func configDir() string {
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		return filepath.Join(xdg, "ramnotifier")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "ramnotifier")
}

func configFilePath() string {
	return filepath.Join(configDir(), "threshold")
}

func readTopThreshold() int {
	data, err := os.ReadFile(configFilePath())
	if err != nil {
		return 500
	}
	val, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil || val <= 0 {
		return 500
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
				// Convert kB to MB (integer division).
				kb, err := strconv.ParseUint(fields[1], 10, 64)
				if err != nil {
					return 0, err
				}
				return int(kb / 1024), nil
			}
		}
	}
	// Distinguish a scanner error from the line simply being absent.
	if err := scanner.Err(); err != nil {
		return 0, err
	}
	return 0, fmt.Errorf("MemAvailable not found")
}

func sendNotification(title, body string) {
	if dbusConn == nil {
		return
	}
	obj := dbusConn.Object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
	call := obj.Call("org.freedesktop.Notifications.Notify", 0,
		"RAM-Notifier", lastNotifID, "", title, body, []string{}, map[string]dbus.Variant{}, int32(-1),
	)
	if call.Err != nil {
		fmt.Println("Notification error:", call.Err)
		return
	}
	call.Store(&lastNotifID)
}

func main() {
	// Open a single D-Bus session connection for the lifetime of the process.
	// If the session bus is unavailable (headless / no desktop), dbusConn
	// stays nil and notifications are silently skipped.
	var err error
	dbusConn, err = dbus.SessionBus()
	if err != nil {
		fmt.Println("D-Bus connection error:", err)
	} else {
		defer dbusConn.Close()
	}

	topThreshold := readTopThreshold()

	// SIGHUP is used to trigger a config reload without restarting the service.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGHUP)

	// Poll /proc/meminfo every 5 seconds.  This is pure kernel-memory I/O
	// (no disk access) so the overhead is negligible.
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
				lastNotifID = 0
				fmt.Printf("Config reloaded (alert threshold: %d MB)\n", topThreshold)
			}

		case <-ticker.C:
			availableMB, err := getAvailableMemMB()
			if err != nil {
				fmt.Println("Error:", err)
				continue
			}

			// If available RAM hits 0 the system is effectively frozen;
			// send one last notification, pause briefly so D-Bus can
			// deliver it, then exit.
			if availableMB <= 0 {
				sendNotification("System Critical", "Available RAM hit 0 MB. Goodbye!")
				time.Sleep(100 * time.Millisecond)
				os.Exit(1)
			}

			top := topThreshold
			step := top / 5
			if step < 1 {
				step = 1
			}

			var currentThreshold int
			for t := step; t <= top; t += step {
				if availableMB <= t {
					currentThreshold = t
					break
				}
			}

			if currentThreshold > 0 {
				// Fire only on first entry into a tier, or when crossing
				// into a lower (worse) tier than the one we last alerted for.
				if lastAlertedThreshold == 0 || currentThreshold < lastAlertedThreshold {
					msg := fmt.Sprintf("Critical: Available RAM is down to %d MB!", availableMB)
					sendNotification("Low Memory Alert", msg)
					lastAlertedThreshold = currentThreshold
				}
			} else {
				// RAM recovered above the top threshold — reset alert state.
				lastAlertedThreshold = 0
			}
		}
	}
}
