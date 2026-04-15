//go:build !windows

package config

import (
	"errors"
	"syscall"
)

func IsProcessAlive(pid int32) bool {
	if pid <= 0 {
		return false
	}

	err := syscall.Kill(int(pid), 0)
	return err == nil || errors.Is(err, syscall.EPERM)
}
