package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
)

var lastAlertedThreshold int = 0

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
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	fmt.Println("Monitoring RAM with tiered alerts...")

	for range ticker.C {
		availableMB, err := getAvailableMemMB()
		if err != nil {
			fmt.Println("Error:", err)
			continue
		}

		if availableMB <= 0 {
			sendNotification("System Critical", "Available RAM hit 0 MB. Goodbye!")
			os.Exit(1)
		}

		var currentThreshold int = 0
		switch {
		case availableMB <= 300:
			currentThreshold = 300
		case availableMB <= 600:
			currentThreshold = 600
		case availableMB <= 900:
			currentThreshold = 900
		case availableMB <= 1200:
			currentThreshold = 1200
		case availableMB <= 1500:
			currentThreshold = 1500
		}

		if currentThreshold > 0 {
			// Only alert when entering a worse (lower-MB) threshold tier.
			// A larger currentThreshold value means less critical (e.g. 500 is safer than 100).
			// We alert when the tier we just entered has a LOWER number
			// (more critical) than the last one we alerted for.
			if lastAlertedThreshold == 0 || currentThreshold < lastAlertedThreshold {
				msg := fmt.Sprintf("Critical: Available RAM is down to %d MB!", availableMB)
				sendNotification("Low Memory Alert", msg)
				lastAlertedThreshold = currentThreshold
			}
		} else {
			// RAM recovered above 1500 MB, reset alert state
			lastAlertedThreshold = 0
		}
	}
}
