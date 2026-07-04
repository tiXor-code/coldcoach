import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ColdCoachCore

/// Fetches the latest GitHub release for the update check. Read-only, and treats any
/// failure (no releases yet / 404, rate limit, offline) as "no update" rather than an
/// error. Parsing lives in the pure `ReleaseCheck` (Core); this only does the network.
struct GitHubReleaseClient {
    static let latestURL = URL(string: "https://api.github.com/repos/tiXor-code/coldcoach/releases/latest")!

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func fetchLatest() async -> ReleaseInfo? {
        var req = URLRequest(url: Self.latestURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ColdCoach", forHTTPHeaderField: "User-Agent") // GitHub requires a UA
        req.timeoutInterval = 12
        guard let (data, response) = try? await session.data(for: req),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return nil }
        return ReleaseCheck.parseLatestRelease(data)
    }
}
