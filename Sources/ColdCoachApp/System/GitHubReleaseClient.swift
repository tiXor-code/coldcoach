import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ColdCoachCore

/// Fetches the latest GitHub release for the update check. Read-only. It reports a
/// `FetchOutcome` so the caller can tell "could not check" (offline, timeout, rate
/// limit, 5xx) apart from "checked, no release" (404) -- parsing/decision live in the
/// pure `ReleaseCheck` (Core); this only does the network and maps the HTTP status.
struct GitHubReleaseClient {
    static let latestURL = URL(string: "https://api.github.com/repos/tiXor-code/coldcoach/releases/latest")!

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func fetchLatest() async -> FetchOutcome {
        var req = URLRequest(url: Self.latestURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ColdCoach", forHTTPHeaderField: "User-Agent") // GitHub requires a UA
        req.timeoutInterval = 12
        guard let (data, response) = try? await session.data(for: req),
              let http = response as? HTTPURLResponse else { return .unavailable } // transport failure
        switch http.statusCode {
        case 404:
            return .noRelease // no releases published yet -> a definitive "no update"
        case 200..<300:
            if let info = ReleaseCheck.parseLatestRelease(data) { return .release(info) }
            return .unavailable // 2xx but unparseable is ambiguous; do not clobber known state
        default:
            return .unavailable // 403 rate limit, 429, 5xx, etc. -> could not verify
        }
    }
}
