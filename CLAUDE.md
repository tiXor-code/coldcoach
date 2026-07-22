<!-- SEC-RULES v1 START -->
**Security gate.** Every change made in this workspace must comply with the Secure Development Rules Reference: `docs/security/RULES-INDEX.md` (in this repo). Before completing any task, check the work against those rules and flag every breach with its SEC ID and severity. CRITICAL breaches block completion -- fix or escalate before proceeding. For security-relevant changes (auth, secrets, input handling, dependencies, agent/MCP/hook/skill config), read the matching rule section first.
<!-- SEC-RULES v1 END -->

# ColdCoach — guide for AI agents (reviewer, fixer, contributors)

ColdCoach is a local-first macOS cold-call coach. `ColdCoachCore` is a pure-Swift,
dependency-free "brain"; `ColdCoachApp` is a thin SwiftUI / WhisperKit / ScreenCaptureKit
shell over it. This file is the standard both the automated reviewer and the `@claude`
fixer must follow.

## Build & test (Command Line Tools, no Xcode required)

- `swift run coldcoach-selftest` — dependency-free assertion runner; the local gate.
- `swift test` — the XCTest suite (CI runs this on macOS with Xcode).
- `COLDCOACH_BUILD_APP=1 swift build` — compiles the app target (pulls WhisperKit).

## Rules new code must follow (and reviewers must enforce)

1. **Tests in both suites.** New business logic goes in `ColdCoachCore` and is covered by
   tests in BOTH `Tests/ColdCoachCoreTests/` (XCTest) and `Sources/ColdCoachSelfTest/main.swift`
   (the self-test runner). They intentionally mirror each other; update both.
2. **Keep the core pure.** No UI, audio, network, or filesystem in `ColdCoachCore`. URLSession,
   Keychain, `Bundle`, `FileManager`, and anything platform-specific live in `ColdCoachApp`.
3. **Key stays in the Keychain.** The API key lives only in `KeychainStore`, never in
   `AppSettings`, on disk, or in logs.
4. **Determinism.** The coaching engine debounces on transcript timestamps, not wall-clock
   time. Do not introduce wall-clock timing into core logic; it must stay testable offline.
5. **Small, single-purpose files behind protocols.** Match the surrounding style and comment
   density. No unrequested features.
6. **Toolchain.** `Package.swift` uses Swift tools 6.0; CI runs on `macos-15`. Do not lower the
   tools version or add dependencies to `ColdCoachCore`.

## Reviewer contract

CI (build + self-test + XCTest) is the objective gate and passes before you review. Take a
fresh look at the whole diff vs `main`; judge correctness, quality, and how accurately the
change implements the PR description. Approve and squash-merge only clean work. Otherwise
request specific, actionable changes and tag `@claude` to fix. After ~3 unresolved rounds,
escalate to a human (`needs-human` label) instead of looping.
