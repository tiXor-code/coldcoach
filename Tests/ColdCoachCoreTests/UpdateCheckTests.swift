import XCTest
@testable import ColdCoachCore

final class UpdateCheckTests: XCTestCase {
    // MARK: - SemVer

    func testSemVerParsesWithAndWithoutVPrefix() {
        XCTAssertEqual(SemVer("v1.2.3"), SemVer(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(SemVer("1.2.3"), SemVer(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(SemVer("2"), SemVer(major: 2, minor: 0, patch: 0))
        XCTAssertEqual(SemVer("1.4"), SemVer(major: 1, minor: 4, patch: 0))
        XCTAssertEqual(SemVer("v0.0.1-beta.2"), SemVer(major: 0, minor: 0, patch: 1))
    }

    func testSemVerRejectsGarbage() {
        XCTAssertNil(SemVer("banana"))
        XCTAssertNil(SemVer(""))
        XCTAssertNil(SemVer("v"))
    }

    func testSemVerOrdersNumericallyNotLexically() {
        XCTAssertTrue(SemVer("1.10.0")! > SemVer("1.9.0")!)
        XCTAssertTrue(SemVer("2.0.0")! > SemVer("1.9.9")!)
        XCTAssertTrue(SemVer("0.0.2")! > SemVer("0.0.1")!)
        XCTAssertEqual(SemVer("1.0.0")!, SemVer("v1.0.0")!)
    }

    // MARK: - Release parsing

    func testParseLatestReleasePicksTagAndDmgAsset() {
        let json = """
        {"tag_name":"v0.0.2","html_url":"https://github.com/tiXor-code/coldcoach/releases/tag/v0.0.2",
         "assets":[{"name":"notes.txt","browser_download_url":"https://x/notes.txt"},
                   {"name":"ColdCoach.dmg","browser_download_url":"https://x/ColdCoach.dmg"}]}
        """
        let info = ReleaseCheck.parseLatestRelease(Data(json.utf8))
        XCTAssertEqual(info?.version, SemVer(major: 0, minor: 0, patch: 2))
        XCTAssertEqual(info?.tag, "v0.0.2")
        XCTAssertEqual(info?.dmgURL, "https://x/ColdCoach.dmg")
        XCTAssertEqual(info?.releaseURL, "https://github.com/tiXor-code/coldcoach/releases/tag/v0.0.2")
    }

    func testParseLatestReleaseNilOnBadTag() {
        XCTAssertNil(ReleaseCheck.parseLatestRelease(Data(#"{"tag_name":"nightly","assets":[]}"#.utf8)))
        XCTAssertNil(ReleaseCheck.parseLatestRelease(Data("not json".utf8)))
    }

    // MARK: - Update decision

    func testUpdateDecisionAvailableOnlyWhenNewer() {
        let release = ReleaseInfo(tag: "v0.0.2", version: SemVer(major: 0, minor: 0, patch: 2),
                                  releaseURL: "https://r", dmgURL: "https://d.dmg")
        guard case let .available(version, _, dmg) = ReleaseCheck.updateDecision(current: SemVer(major: 0, minor: 0, patch: 1), release: release) else {
            return XCTFail("expected available")
        }
        XCTAssertEqual(version, SemVer(major: 0, minor: 0, patch: 2))
        XCTAssertEqual(dmg, "https://d.dmg")
        XCTAssertEqual(ReleaseCheck.updateDecision(current: SemVer(major: 0, minor: 0, patch: 2), release: release), .upToDate)
        XCTAssertEqual(ReleaseCheck.updateDecision(current: SemVer(major: 0, minor: 1, patch: 0), release: release), .upToDate)
    }

    // MARK: - Evaluate (could-not-check vs no-release vs available)

    func testEvaluateUnavailableIsUnchanged() {
        // A failed fetch must not clear a known update or stamp the check timestamp.
        XCTAssertEqual(ReleaseCheck.evaluate(fetch: .unavailable, current: SemVer(major: 0, minor: 0, patch: 1)), .unchanged)
    }

    func testEvaluateNoReleaseIsUpToDate() {
        XCTAssertEqual(ReleaseCheck.evaluate(fetch: .noRelease, current: SemVer(major: 0, minor: 0, patch: 1)), .upToDate)
    }

    func testEvaluateNewerReleaseIsAvailable() {
        let info = ReleaseInfo(tag: "v0.0.2", version: SemVer(major: 0, minor: 0, patch: 2), releaseURL: "https://r", dmgURL: "https://d.dmg")
        XCTAssertEqual(
            ReleaseCheck.evaluate(fetch: .release(info), current: SemVer(major: 0, minor: 0, patch: 1)),
            .updateAvailable(version: SemVer(major: 0, minor: 0, patch: 2), releaseURL: "https://r", dmgURL: "https://d.dmg")
        )
    }

    func testEvaluateOlderReleaseIsUpToDate() {
        let info = ReleaseInfo(tag: "v0.0.2", version: SemVer(major: 0, minor: 0, patch: 2), releaseURL: "https://r", dmgURL: nil)
        XCTAssertEqual(ReleaseCheck.evaluate(fetch: .release(info), current: SemVer(major: 0, minor: 1, patch: 0)), .upToDate)
    }

    // MARK: - Install channel

    func testInstallChannelClassification() {
        XCTAssertEqual(ReleaseCheck.installChannel(bundlePath: "/opt/homebrew/Caskroom/coldcoach/0.0.1/ColdCoach.app", caskroomExists: true), .brew)
        XCTAssertEqual(ReleaseCheck.installChannel(bundlePath: "/Users/x/repos/coldcoach/build/ColdCoach.app", caskroomExists: false), .source)
        XCTAssertEqual(ReleaseCheck.installChannel(bundlePath: "/Users/x/repos/coldcoach/.build/release/ColdCoach.app", caskroomExists: false), .source)
        XCTAssertEqual(ReleaseCheck.installChannel(bundlePath: "/Applications/ColdCoach.app", caskroomExists: true), .brew)
        XCTAssertEqual(ReleaseCheck.installChannel(bundlePath: "/Applications/ColdCoach.app", caskroomExists: false), .dmg)
    }

    // MARK: - Settings gains update fields

    func testAppSettingsUpdateFieldDefaultsAndRoundTrip() throws {
        XCTAssertTrue(AppSettings.default.autoUpdateEnabled)
        XCTAssertNil(AppSettings.default.lastUpdateCheck)
        var s = AppSettings.default
        s.autoUpdateEnabled = false
        s.lastUpdateCheck = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(back, s)
        XCTAssertFalse(back.autoUpdateEnabled)
        XCTAssertEqual(back.lastUpdateCheck, Date(timeIntervalSince1970: 1_700_000_000))
    }
}
