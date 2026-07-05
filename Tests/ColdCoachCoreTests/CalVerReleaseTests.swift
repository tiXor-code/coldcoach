import XCTest
@testable import ColdCoachCore

/// Locks in the daily CalVer scheme (`vYY.MM.DD`, zero-padded). The updater parses
/// release tags through `SemVer` and offers an update when `release > current`, so
/// the zero-padded date MUST parse (26.07.05 -> 26.7.5) and order correctly, or an
/// updated install would keep reporting an older version and nag forever. If SemVer
/// is ever refactored to reject zero-padded components, this fails loudly.
final class CalVerReleaseTests: XCTestCase {
    func testCalVerTagParsesZeroPaddedDate() {
        XCTAssertEqual(SemVer("v26.07.05"), SemVer(major: 26, minor: 7, patch: 5))
        XCTAssertEqual(SemVer("v26.12.31"), SemVer(major: 26, minor: 12, patch: 31))
        XCTAssertEqual(SemVer("v26.01.09"), SemVer(major: 26, minor: 1, patch: 9))
    }

    func testCalVerIsNewerThanLegacySemver() {
        XCTAssertTrue(SemVer("v26.07.05")! > SemVer("0.0.1")!)
    }

    func testLaterDaysAreNewer() {
        XCTAssertTrue(SemVer("v26.07.06")! > SemVer("v26.07.05")!)
        XCTAssertTrue(SemVer("v26.08.01")! > SemVer("v26.07.31")!)
        XCTAssertTrue(SemVer("v27.01.01")! > SemVer("v26.12.31")!)
    }
}
