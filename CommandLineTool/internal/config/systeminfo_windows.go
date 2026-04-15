//go:build windows

package config

import (
	"fmt"
	"runtime"
	"strings"

	"golang.org/x/sys/windows/registry"
)

func currentOSVersionString() string {
	key, err := registry.OpenKey(registry.LOCAL_MACHINE, `SOFTWARE\Microsoft\Windows NT\CurrentVersion`, registry.QUERY_VALUE)
	if err != nil {
		return runtime.GOOS
	}
	defer key.Close()

	productName, _, _ := key.GetStringValue("ProductName")
	displayVersion, _, _ := key.GetStringValue("DisplayVersion")
	if displayVersion == "" {
		displayVersion, _, _ = key.GetStringValue("ReleaseId")
	}
	buildNumber, _, _ := key.GetStringValue("CurrentBuildNumber")

	parts := make([]string, 0, 3)
	if value := strings.TrimSpace(productName); value != "" {
		parts = append(parts, value)
	}
	if value := strings.TrimSpace(displayVersion); value != "" {
		parts = append(parts, value)
	}
	if value := strings.TrimSpace(buildNumber); value != "" {
		parts = append(parts, fmt.Sprintf("Build %s", value))
	}
	if len(parts) == 0 {
		return runtime.GOOS
	}

	return strings.Join(parts, " ")
}

func machineIdentifier() string {
	key, err := registry.OpenKey(registry.LOCAL_MACHINE, `SOFTWARE\Microsoft\Cryptography`, registry.QUERY_VALUE)
	if err != nil {
		return ""
	}
	defer key.Close()

	value, _, err := key.GetStringValue("MachineGuid")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(value)
}
