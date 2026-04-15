//go:build windows

package daemon

import (
	"os"
	"os/exec"
	"syscall"
)

const (
	windowsCreateNewProcessGroup = 0x00000200
	windowsDetachedProcess       = 0x00000008
)

func configureDetachedProcess(command *exec.Cmd) (*os.File, error) {
	devNull, err := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	if err != nil {
		return nil, err
	}

	command.Stdin = devNull
	command.Stdout = devNull
	command.Stderr = devNull
	command.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: windowsCreateNewProcessGroup | windowsDetachedProcess,
		HideWindow:    true,
	}
	return devNull, nil
}
