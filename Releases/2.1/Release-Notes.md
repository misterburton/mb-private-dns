Private DNS 2.1 makes encrypted DNS status clear and adds a full quit action.

- The menu says **DoH On**, **DoH Paused**, or **DoH !**.
- Details explains DNS over HTTPS, domain-name visibility when paused, and privacy limits.
- **Quit Private DNS** restores network DNS and stops the app, service, and resolver. Reopening the app enables protection again. **Quit Controls** retains its previous behavior.
- The Apple Silicon installer, standalone controls app, and uninstaller are Developer ID signed, notarized by Apple, and supplied with stapled tickets.

Requires Apple Silicon and macOS 13 or later. Install `Private-DNS-2.1-Apple-Silicon.pkg`. Full quit and restart require macOS administrator authorization.

Policy, recovery, menu-state, and text-layout checks passed. Native UI automation timed out, so menu appearance and clicks were not visually verified. An actual Mac reboot and airplane Wi-Fi were not tested.
