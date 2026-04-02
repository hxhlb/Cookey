package fileutil

import (
	"os"
	"path/filepath"
)

// WriteFileAtomically writes data to path using a temp file, fsync, and rename.
func WriteFileAtomically(path string, data []byte, permissions os.FileMode) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}

	tempFile, err := os.CreateTemp(dir, "."+filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}

	tempPath := tempFile.Name()
	cleanup := func() {
		_ = tempFile.Close()
		_ = os.Remove(tempPath)
	}

	if _, err := tempFile.Write(data); err != nil {
		cleanup()
		return err
	}
	if err := tempFile.Sync(); err != nil {
		cleanup()
		return err
	}
	if err := tempFile.Chmod(permissions); err != nil {
		cleanup()
		return err
	}
	if err := tempFile.Close(); err != nil {
		_ = os.Remove(tempPath)
		return err
	}

	if err := os.Rename(tempPath, path); err != nil {
		_ = os.Remove(tempPath)
		return err
	}

	return nil
}
