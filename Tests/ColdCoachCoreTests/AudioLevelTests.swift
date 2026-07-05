import XCTest
@testable import ColdCoachCore

final class AudioLevelTests: XCTestCase {
    func testRMS() {
        XCTAssertEqual(AudioLevel.rms([]), 0)
        XCTAssertEqual(AudioLevel.rms([0, 0, 0]), 0)
        XCTAssertEqual(AudioLevel.rms([1, 1, 1]), 1, accuracy: 1e-6)
        XCTAssertEqual(AudioLevel.rms([0.5, -0.5]), 0.5, accuracy: 1e-6)
    }

    func testMeterClampsToUnitRange() {
        XCTAssertEqual(AudioLevel.meter(rms: 0), 0)
        XCTAssertEqual(AudioLevel.meter(rms: 1), 1, accuracy: 1e-6)          // 0 dB is above the ceiling -> 1
        XCTAssertEqual(AudioLevel.meter(rms: 1e-9), 0, accuracy: 1e-6)       // far below the floor -> 0
        let mid = AudioLevel.meter(rms: 0.05)
        XCTAssertTrue(mid > 0 && mid < 1)
    }

    func testIsSilent() {
        XCTAssertTrue(AudioLevel.isSilent(rms: 0))
        XCTAssertTrue(AudioLevel.isSilent(rms: 0.001))
        XCTAssertFalse(AudioLevel.isSilent(rms: 0.1))
    }
}
