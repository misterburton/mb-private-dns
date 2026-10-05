# Tailscale compatibility: 2.2 development candidate

## Diagnosis and scope

Version 2.1 examines only the first `nameserver[0]` line in `scutil --dns`. That can mistake a domain-specific resolver for the default resolver, overlook secondary nameservers, and classify Tailscale managing DNS as an app failure. These are supported code-level defects. The user's live connected failure has not been reproduced during this update.

Version 2.2 reads the complete snapshot, distinguishes default, domain-specific, multicast, and interface-scoped entries, and reports Tailscale ownership separately. Unknown or mixed defaults remain unverified. Engine failures and configuration conflicts still require attention. Snapshot interpretation is conservative; it is not a packet-level leak detector or a guarantee for applications using their own DNS.

No DNS provider, VPN settings, forwarding configuration, installation behavior, or pause policy changes are included. There is no automatic fallback provider. An App Store architecture migration is outside this update.

## Research

Reviewed October 4, 2026:

- [Tailscale MagicDNS](https://tailscale.com/docs/features/magicdns): device names resolve to Tailscale addresses, so users do not need to remember IP addresses.
- [DNS in Tailscale](https://tailscale.com/docs/reference/dns-in-tailscale): restricted nameservers serve particular domains; global nameservers can handle public lookups. Supported public resolvers can use DoH. Exit nodes normally handle DNS for all domains unless configured otherwise. Therefore Tailscale's presence alone does not establish the upstream provider or encryption for a particular device.
- [Tailscale resolver FAQ](https://tailscale.com/docs/reference/faq/dns-resolv-conf): the local virtual resolver uses `100.100.100.100` or `fd7a:115c:a1e0::53`.
- This Mac's macOS 27.0.1 `resolver(5)` manual: macOS supports multiple resolvers, with domain matching and search order. A single nameserver line cannot describe all DNS routing.

## Verification

`bash test.sh --live` passed the existing 13 policy/persistence checks, 24 routing cases, and the AppKit menu smoke test. Cases cover private-name routes, Tailscale default DNS over IPv4 and IPv6, mixed and missing defaults, interface-specific DNS, engine failures, preserved conflicts, pause, and a disconnect snapshot. The menu test loads the actual AppKit controls with synthetic service responses, without running startup hooks, opening windows, or changing DNS.

The live read-only snapshot classified this Mac's default resolver as Private DNS, with no separate domain or active foreign interface route. It did not contain Tailscale DNS, so it cannot validate the reported connected case.

The ARM64 application, helper, and uninstaller compiled successfully. The build verified their ad hoc signatures and generated the unsigned package; `pkgutil --payload-files` could read its expected payload. Packaging also emitted four `write: Permission denied` warnings despite returning success. Their cause is not established, and installation of this candidate has not been verified.

## Release gate

Before publishing or installing 2.2, verify an actual Tailscale connection with private-name resolution, public-name resolution, global DNS override, exit-node use, and disconnect recovery. Check system resolver behavior, not only `dig`, which does not follow all macOS resolver routing. Test menu state alongside lookup results. Do not change upstream providers without the user's explicit choice.

The installed app and published 2.1 artifacts are unchanged. The local 2.2 package is an unsigned development candidate in `Releases/Builds`, not a notarized distribution release.
