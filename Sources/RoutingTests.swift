import Foundation

@main struct RoutingTests {
    static func main() {
        func check(_ condition: Bool, _ label: String) {
            precondition(condition, label); print("PASS: " + label)
        }
        func parse(_ text: String, _ succeeded: Bool = true) -> DNSRouting {
            DNSRouting(output: text, succeeded: succeeded)
        }
        let local = """
        DNS configuration
        resolver #1
          nameserver[0] : 127.0.0.1
          flags : Request A records, Request AAAA records
          reach : 0x00030002 (Reachable,Local Address,Directly Reachable Address)
        """
        let tail = local.replacingOccurrences(of: "127.0.0.1", with: "100.100.100.100")
        let split = """
        resolver #8
          domain : studio.example.ts.net
          nameserver[0] : 100.100.100.100
          flags : Supplemental, Request A records, Request AAAA records
        """
        let multicast = """
        resolver #9
          domain : local
          options : mdns
          reach : 0x00000000 (Not Reachable)
        """
        let scoped = """
        DNS configuration (for scoped queries)
        resolver #1
          nameserver[0] : 100.100.100.100
          flags : Scoped, Request A records
          reach : 0x00000002 (Reachable)
        """
        func mode(_ routing: DNSRouting, enabled: Bool = true, healthy: Bool = true,
                  conflicts: [String] = [], error: String = "") -> String {
            routing.mode(enabled: enabled, healthy: healthy, conflicts: conflicts, error: error)
        }
        check(mode(parse(local)) == "on", "ordinary Cloudflare route stays on")
        check(mode(parse(local + "\n" + multicast)) == "on", "mDNS does not create a conflict")
        let coexist = parse("DNS configuration\n" + split + "\n" + local)
        check(coexist.owner == "private-dns" && coexist.splitDNS && coexist.tailscalePresent,
              "Tailscale domain resolver appearing first is not a global override")
        check(mode(coexist) == "on", "split DNS coexists with the default DoH resolver")
        check(mode(parse(tail)) == "managed", "Tailscale default is managed, not protected or broken")
        check(mode(parse(tail.replacingOccurrences(of: "100.100.100.100", with: "fd7a:115c:a1e0::53"))) == "managed",
              "Tailscale IPv6 virtual resolver is recognized")
        check(mode(parse(tail + "\n" + scoped)) == "managed", "Tailscale scoped duplicate does not hide default ownership")
        check(mode(parse(local + "\n" + scoped)) == "on" && parse(local + "\n" + scoped).tailscaleCoexistence,
              "known Tailscale interface coexists with the default DoH resolver")
        let foreignScoped = scoped.replacingOccurrences(of: "100.100.100.100", with: "192.0.2.53")
        check(mode(parse(local + "\n" + foreignScoped)) == "attention", "unknown active scoped DNS still warns")
        check(mode(parse(local + "\n" + scoped + "\n" + foreignScoped)) == "attention",
              "Tailscale presence cannot conceal another active interface resolver")
        let scopedCoexist = parse(local + "\n" + scoped)
        check(mode(scopedCoexist, healthy: false) == "attention", "coexistence cannot conceal a failed resolver")
        check(mode(scopedCoexist, error: "read failed") == "attention", "coexistence cannot conceal a service error")
        check(mode(scopedCoexist, conflicts: ["Wi-Fi"]) == "attention", "coexistence cannot conceal a configuration conflict")
        check(mode(scopedCoexist, enabled: false) == "paused", "coexistence respects user pause")
        check(mode(parse(local + "\n" + scoped.replacingOccurrences(of: "(Reachable)", with: "(Not Reachable)"))) == "on",
              "unreachable scoped resolver does not produce a false conflict")
        check(parse(scoped).owner == "unknown", "scoped-only configuration is not a default")
        check(parse("DNS configuration\n" + split).owner == "unknown", "private names alone do not prove public DNS protection")
        check(parse(local + "\n  nameserver[1] : 192.0.2.53").owner == "mixed", "secondary DNS cannot hide behind loopback first")
        check(parse(local + "\n" + tail).owner == "mixed", "competing defaults are reported conservatively")
        check(parse(local + "\n  port : 5353").owner == "mixed", "different loopback port is not our resolver")
        check(parse(local.replacingOccurrences(of: "127.0.0.1", with: "192.0.2.53")).owner == "other", "other VPN DNS is not attributed to Tailscale")
        check(parse("DNS configuration\nresolver #1\n domain : .\n nameserver[0] : 100.100.100.100\n flags : Supplemental").owner == "tailscale",
              "root-domain route can handle all DNS")
        check(parse("").owner == "unknown" && parse("scutil failed", false).owner == "unknown", "missing and failed snapshots fail conservatively")
        check(parse(local, false).owner == "unknown", "failed command with partial output is not trusted")
        check(parse("DNS configuration\nresolver #1\n flags : Request A records").owner == "unknown", "empty resolver is not protection")
        check(mode(parse(tail), healthy: false) == "attention", "Tailscale does not hide failed standby resolver")
        check(mode(parse(tail), conflicts: ["Wi-Fi"]) == "attention", "Tailscale does not hide configuration conflict")
        check(mode(parse(tail), error: "read failed") == "attention", "Tailscale does not hide service errors")
        check(mode(parse(tail), enabled: false) == "paused", "user pause remains authoritative")
        check(mode(parse(local)) == "on", "disconnect snapshot returns to on without a persistent managed flag")
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/tailscale-coexistence.txt")
        let connected = parse(try! String(contentsOf: fixtureURL, encoding: .utf8))
        check(connected.owner == "private-dns" && connected.splitDNS && connected.scopedDNS
              && connected.tailscaleCoexistence && mode(connected) == "on",
              "captured macOS Tailscale connection is informational, including dual-stack scoped and supplemental entries")
        if CommandLine.arguments.contains("--live") {
            let result = run("/usr/sbin/scutil", ["--dns"])
            let routing = parse(result.text, result.code == 0)
            print("LIVE: default=\(routing.owner), split=\(routing.splitDNS), scoped=\(routing.scopedDNS), coexistence=\(routing.tailscaleCoexistence), healthyMode=\(mode(routing))")
        }
    }
}
