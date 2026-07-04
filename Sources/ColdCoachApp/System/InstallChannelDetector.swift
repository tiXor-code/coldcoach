import Foundation
import ColdCoachCore

/// Supplies the filesystem facts the pure `ReleaseCheck.installChannel` classifier needs,
/// so the classification logic itself stays testable in the Core.
enum InstallChannelDetector {
    static func detect() -> InstallChannel {
        let caskroom = FileManager.default.fileExists(atPath: "/opt/homebrew/Caskroom/coldcoach")
            || FileManager.default.fileExists(atPath: "/usr/local/Caskroom/coldcoach")
        return ReleaseCheck.installChannel(bundlePath: Bundle.main.bundlePath, caskroomExists: caskroom)
    }
}
