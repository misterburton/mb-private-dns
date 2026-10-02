# Controls update verification

Verified on this Mac on October 2, 2026.

- Menu status uses DoH, including enabled, paused, and attention states.
- Details defines DNS over HTTPS, explains domain-name exposure when paused, and describes Cloudflare visibility and other privacy limits. Text fits the scrollable document, and refresh preserves the scroll position.
- Quit Private DNS restores network DNS before unloading the service and terminating the bundled resolver. Reopening the app starts the service and enables protection again. Quit Controls retains its previous behavior.
- A live stop/start check passed: the service was unloaded, the resolver was absent, system DNS no longer pointed to the local resolver, and example.com resolved through system DNS. Restart reported healthy DoH. The user's existing pause-until-restart state was restored afterward.
- All 13 existing policy and recovery checks passed, along with menu-state and text-layout checks.
- The updated Developer ID signed controls app was installed in /Applications and launched successfully. Its signature and lifecycle resource were verified. The previous app remains in /Library/Application Support/Private DNS/Controls backup-2026-10-02-0955.app.

Limitations: native UI automation timed out, so the appearance and menu clicks were not visually verified. An actual Mac reboot was not tested. The current local controls build is signed but has not been notarized; the local installer candidate is explicitly unsigned. The published v2.0 installer has not been replaced.
