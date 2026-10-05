import Foundation
import CryptoKit

@main struct UpdateTests {
    static func main() async throws {
        func check(_ condition: Bool, _ label: String) { precondition(condition, label); print("PASS: " + label) }
        func rejects(_ label: String, _ operation: () throws -> Void) {
            do { try operation(); preconditionFailure(label) } catch { print("PASS: " + label) }
        }
        let data = Data("installer fixture".utf8)
        let hash = "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        func release(tag: String = "v2.10", draft: Bool = false, prerelease: Bool = false,
                     url: String? = nil, digest: String? = nil, size: Int? = nil) -> UpdateRelease {
            let name = "Private-DNS-\(tag.dropFirst())-Apple-Silicon.pkg"
            return UpdateRelease(tag_name: tag, draft: draft, prerelease: prerelease, assets: [
                .init(name: name, browser_download_url: url ?? "https://github.com/misterburton/mb-private-dns/releases/download/\(tag)/\(name)", size: size ?? data.count, digest: digest ?? hash)
            ])
        }
        check(UpdateVersion("2.10")! > UpdateVersion("2.9")!, "numeric version comparison")
        check(UpdateVersion("2.2") == UpdateVersion("2.2.0"), "equivalent versions do not trigger updates")
        check(UpdateVersion("2.2-beta") == nil && UpdateVersion("../../etc") == nil, "reject malformed versions")
        check(try release(tag: "v2.1").candidate(after: "2.2") == nil, "never offer downgrade")
        check(try release(draft: true).candidate(after: "2.2") == nil, "ignore draft releases")
        check(try release(prerelease: true).candidate(after: "2.2") == nil, "ignore prereleases")
        rejects("reject installer from another repository") { _ = try release(url: "https://github.com/other/repo/file.pkg").candidate(after: "2.2") }
        rejects("reject missing checksum") { _ = try release(digest: "").candidate(after: "2.2") }
        rejects("reject excessive declared size") { _ = try release(size: 100_000_001).candidate(after: "2.2") }
        let candidate = try release().candidate(after: "2.2")!
        try candidate.validate(data); print("PASS: matching installer size and checksum")
        rejects("reject corrupt installer") { try candidate.validate(Data("corrupt installer".utf8)) }
        check(!UpdateRedirects.allowed(URL(string: "http://github.com/file")), "reject plaintext redirect")
        check(!UpdateRedirects.allowed(URL(string: "https://github.com.evil.example/file")), "reject foreign redirect")
        check(UpdateRedirects.allowed(URL(string: "https://release-assets.githubusercontent.com/file")), "allow GitHub release CDN")
        for status in [403, 404, 429, 500] {
            rejects("handle HTTP \(status)") { try Updates.validateResponse(HTTPURLResponse(url: Updates.endpoint, statusCode: status, httpVersion: nil, headerFields: nil)!) }
        }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("PrivateDNS-invalid-" + UUID().uuidString + ".pkg")
        try data.write(to: temp); defer { try? FileManager.default.removeItem(at: temp) }
        rejects("reject unsigned package") { try Updates.verifySignature(temp) }
        if CommandLine.arguments.contains("--download-live") {
            guard let update = try await Updates.check(current: "0.0") else { throw error("Expected a public release") }
            let path = try await Updates.download(update)
            defer { try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
            print("PASS: anonymous GitHub check, download, checksum, developer signature and Gatekeeper verification for " + update.version)
            check(try await Updates.check(current: update.version) == nil, "live current version is up to date")
        }
    }
}
