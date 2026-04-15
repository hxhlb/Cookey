//go:build !windows

package daemon

import (
	"os"
	"os/exec"
	"syscall"
)

func configureDetachedProcess(command *exec.Cmd) (*os.File, error) {
	devNull, err := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	if err != nil {
		return nil, err
	}

	command.Stdin = devNull
	command.Stdout = devNull
	command.Stderr = devNull
	command.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return devNull, nil
}
