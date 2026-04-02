# Cookey

Cookey is a CLI-first way to move a logged-in mobile browser session back to your terminal as Playwright-compatible `storageState` JSON.

## Pairing Flow

1. Run `cookey request start <target_url>`
2. The CLI prints a pair key like `SM8N-D67N (api.cookey.sh)`
3. The QR/deep link uses `cookey://SM8ND67N?host=api.cookey.sh`
4. The iPhone app resolves the rest of the request metadata from the relay over HTTPS
