// swift-tools-version: 6.0
import PackageDescription
import Foundation

// ColdCoach is a pure-SwiftPM project (no .xcodeproj required).
//
//   swift test                       -> builds & tests ColdCoachCore only (offline, no external deps)
//   COLDCOACH_BUILD_APP=1 swift build -> also builds the ColdCoach.app executable (pulls WhisperKit)
//
// The WhisperKit/SpeakerKit dependency is gated behind COLDCOACH_BUILD_APP so the
// testable "brain" (ColdCoachCore) resolves and tests without any network access.
// `make app` / `make bundle` set the flag for you (see dist/Makefile).

let buildApp = ProcessInfo.processInfo.environment["COLDCOACH_BUILD_APP"] == "1"

var packageDependencies: [Package.Dependency] = []

var targets: [Target] = [
    .target(
        name: "ColdCoachCore",
        path: "Sources/ColdCoachCore",
        swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(
        name: "ColdCoachCoreTests",
        dependencies: ["ColdCoachCore"],
        path: "Tests/ColdCoachCoreTests",
        resources: [.copy("Fixtures")],
        swiftSettings: [.swiftLanguageMode(.v5)]
    ),
]

var products: [Product] = [
    .library(name: "ColdCoachCore", targets: ["ColdCoachCore"]),
]

// A dependency-free assertion runner so the core can be verified without Xcode/XCTest
// (Apple's Command Line Tools do not ship XCTest). CI with full Xcode runs `swift test`;
// everyone else can run `swift run coldcoach-selftest`.
targets.append(
    .executableTarget(
        name: "ColdCoachSelfTest",
        dependencies: ["ColdCoachCore"],
        path: "Sources/ColdCoachSelfTest",
        swiftSettings: [.swiftLanguageMode(.v5)]
    )
)
products.append(.executable(name: "coldcoach-selftest", targets: ["ColdCoachSelfTest"]))

if buildApp {
    // argmax-oss-swift bundles WhisperKit (STT), SpeakerKit (diarization) and TTSKit.
    packageDependencies.append(
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", branch: "main")
    )
    targets.append(
        .executableTarget(
            name: "ColdCoachApp",
            dependencies: [
                "ColdCoachCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                // SpeakerKit (diarization) is a documented Mode-A upgrade; v1 uses the
                // tested RoleAssigner heuristic + LLM role inference, so it is not required.
            ],
            path: "Sources/ColdCoachApp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    )
    products.append(.executable(name: "ColdCoach", targets: ["ColdCoachApp"]))
}

let package = Package(
    name: "ColdCoach",
    platforms: [.macOS(.v14)],
    products: products,
    dependencies: packageDependencies,
    targets: targets
)
