import Foundation
import CryptoKit

struct UpdateVersion: Comparable {
    let parts: [Int]
    init?(_ value: String) {
        let fields = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(fields.count), fields.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              fields.allSatisfy({ Int($0) != nil }) else { return nil }
        parts = fields.map { Int($0)! } + Array(repeating: 0, count: 3 - fields.count)
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}
struct UpdateRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: String
        let size: Int
        let digest: String?
    }
    let tag_name: String
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
    func candidate(after current: String) throws -> UpdateCandidate? {
        guard let installed = UpdateVersion(current), tag_name.hasPrefix("v"),
              let available = UpdateVersion(String(tag_name.dropFirst())) else {
            throw error("The update version could not be verified.")
        }
        guard !draft && !prerelease && available > installed else { return nil }
        let version = String(tag_name.dropFirst())
        let filename = "Private-DNS-\(version)-Apple-Silicon.pkg"
        let matches = assets.filter { $0.name == filename }
        guard matches.count == 1, let asset = matches.first,
              asset.browser_download_url == "https://github.com/misterburton/mb-private-dns/releases/download/\(tag_name)/\(filename)",
              (1...100_000_000).contains(asset.size),
              let digest = asset.digest, digest.hasPrefix("sha256:"), digest.count == 71,
              digest.dropFirst(7).allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw error("This release has no verifiable Apple Silicon installer. Try again after the release is complete.")
        }
        return UpdateCandidate(version: version, asset: asset)
    }
}
struct UpdateCandidate {
    let version: String
    let asset: UpdateRelease.Asset
    func validate(_ data: Data) throws {
        let digest = "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == asset.size && digest == asset.digest else {
            throw error("The downloaded installer failed its integrity check. Nothing was installed.")
        }
    }
}

// Never send credentials or cookies; only follow HTTPS redirects on GitHub's
// API, download host, and release asset CDN.
final class UpdateRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static func allowed(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        return ["api.github.com", "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains(url.host ?? "")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(Self.allowed(request.url) ? request : nil)
    }
}
enum Updates {
    static let endpoint = URL(string: "https://api.github.com/repos/misterburton/mb-private-dns/releases/latest")!
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration, delegate: UpdateRedirects(), delegateQueue: nil)
    }
    static func check(current: String) async throws -> UpdateCandidate? {
        let session = session(); defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(UpdateRelease.self, from: data).candidate(after: current)
    }
    static func validateResponse(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else { throw error("GitHub returned an invalid response.") }
        guard response.statusCode == 200 else {
            if response.statusCode == 403 || response.statusCode == 429 { throw error("GitHub's request limit was reached. Try again later.") }
            throw error("The update could not be retrieved from GitHub (HTTP \(response.statusCode)). Try again later.")
        }
    }
    static func download(_ candidate: UpdateCandidate) async throws -> URL {
        let session = session(); defer { session.finishTasksAndInvalidate() }
        let (temporary, response) = try await session.download(from: URL(string: candidate.asset.browser_download_url)!)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try validateResponse(response)
        let attributes = try FileManager.default.attributesOfItem(atPath: temporary.path)
        guard (attributes[.size] as? NSNumber)?.intValue == candidate.asset.size else { throw error("The installer download was incomplete.") }
        try candidate.validate(Data(contentsOf: temporary, options: .mappedIfSafe))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Private-DNS-Update-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let package = folder.appendingPathComponent(candidate.asset.name)
        do {
            try FileManager.default.moveItem(at: temporary, to: package)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: package.path)
            try verifySignature(package)
            return package
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
    static func verifySignature(_ package: URL) throws {
        let signature = run("/usr/sbin/pkgutil", ["--check-signature", package.path])
        guard signature.code == 0,
              signature.text.components(separatedBy: .newlines).contains(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "1. Developer ID Installer: BURTON RAST (4L34HDN35D)"
              }) else { throw error("The installer is not signed by Private DNS's expected developer. Nothing was installed.") }
        let assessment = run("/usr/sbin/spctl", ["--assess", "--type", "install", package.path])
        guard assessment.code == 0 else { throw error("macOS could not approve this installer. Check your connection and try again. Nothing was installed.") }
    }
}

// A fresh controls process checks at launch. Missed checks after sleep coalesce
// into one attempt; failures also wait a day instead of retrying every tick.
struct UpdateSchedule {
    private(set) var nextCheck = Date.distantPast
    func isDue(now: Date) -> Bool { now >= nextCheck }
    mutating func recordAttempt(now: Date) { nextCheck = now.addingTimeInterval(24 * 60 * 60) }
}
