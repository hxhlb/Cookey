//go:build !windows

package config

import (
	"os"
	"os/exec"
	"runtime"
	"strings"
)

func currentOSVersionString() string {
	if runtime.GOOS == "darwin" {
		productVersion, errVersion := exec.Command("sw_vers", "-productVersion").Output()
		buildVersion, errBuild := exec.Command("sw_vers", "-buildVersion").Output()
		if errVersion == nil && errBuild == nil {
			return "Version " + strings.TrimSpace(string(productVersion)) + " (Build " + strings.TrimSpace(string(buildVersion)) + ")"
		}
	}

	return runtime.GOOS
}

func machineIdentifier() string {
	for _, candidate := range []string{"/etc/machine-id", "/var/lib/dbus/machine-id"} {
		data, err := os.ReadFile(candidate)
		if err != nil {
			continue
		}

		value := strings.TrimSpace(string(data))
		if value != "" {
			return value
		}
	}

	return ""
}
