import Foundation

/// Parsed subset of a GitHub "latest release" that the updater needs.
public struct ReleaseInfo: Equatable, Sendable {
    public let tag: String
    public let version: SemVer
    public let releaseURL: String
    public let dmgURL: String?

    public init(tag: String, version: SemVer, releaseURL: String, dmgURL: String?) {
        self.tag = tag
        self.version = version
        self.releaseURL = releaseURL
        self.dmgURL = dmgURL
    }
}

public enum UpdateDecision: Equatable, Sendable {
    case upToDate
    case available(version: SemVer, releaseURL: String, dmgURL: String?)
}

/// How this copy of the app was installed. Determines the assisted-update call to action.
public enum InstallChannel: String, Equatable, Sendable {
    case brew    // Homebrew cask -> tell the user to `brew upgrade`
    case dmg     // downloaded .dmg -> open the release page to grab the new one
    case source  // built from source -> open the release page (informational)
}

/// Pure update logic: parse the GitHub release JSON, decide if an update exists, and
/// classify the install channel. No network or filesystem here (the app layer feeds
/// the raw JSON and filesystem facts in), so all of this is unit-testable offline.
public enum ReleaseCheck {
    private struct WireRelease: Decodable {
        struct Asset: Decodable { let name: String?; let browser_download_url: String? }
        let tag_name: String?
        let html_url: String?
        let assets: [Asset]?
    }

    /// Returns the parsed release, or nil if there is no valid semver tag.
    public static func parseLatestRelease(_ data: Data) -> ReleaseInfo? {
        guard let wire = try? JSONDecoder().decode(WireRelease.self, from: data),
              let tag = wire.tag_name,
              let version = SemVer(tag) else { return nil }
        let dmg = (wire.assets ?? [])
            .first { ($0.name ?? "").lowercased().hasSuffix(".dmg") }?
            .browser_download_url
        let releaseURL = wire.html_url ?? "https://github.com/tiXor-code/coldcoach/releases/latest"
        return ReleaseInfo(tag: tag, version: version, releaseURL: releaseURL, dmgURL: dmg)
    }

    public static func updateDecision(current: SemVer, release: ReleaseInfo) -> UpdateDecision {
        release.version > current
            ? .available(version: release.version, releaseURL: release.releaseURL, dmgURL: release.dmgURL)
            : .upToDate
    }

    /// Classify the install channel from the bundle path plus whether a Homebrew
    /// caskroom for coldcoach exists (the app layer supplies both facts).
    public static func installChannel(bundlePath: String, caskroomExists: Bool) -> InstallChannel {
        if bundlePath.contains("/Caskroom/") { return .brew }
        if bundlePath.contains("/.build/") || bundlePath.contains("/build/") { return .source }
        if caskroomExists { return .brew }
        return .dmg
    }
}
