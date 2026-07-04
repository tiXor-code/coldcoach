# Contributing to ColdCoach

Thanks for your interest. ColdCoach is MIT-licensed and contributions are welcome.

## Architecture in one minute

- `ColdCoachCore` is pure Swift with **no UI, audio, or network hard dependencies**. It holds the
  LLM providers, playbook generation + weighting, intent classification, the coaching
  trigger/debounce logic, the transcript store, role assignment, and JSON persistence. Keep it that
  way: anything that imports SwiftUI/AVFoundation/WhisperKit belongs in `ColdCoachApp`.
- `ColdCoachApp` wires the real macOS implementations (WhisperKit, AVAudioEngine, ScreenCaptureKit,
  Keychain, the `NSPanel` overlay, SwiftUI) onto the core protocols.

This split is deliberate: the hard logic stays testable without a Mac GUI or a network.

## Building and testing

```sh
swift run coldcoach-selftest   # dependency-free core check (works with just Command Line Tools)
swift test                     # full XCTest suite (needs Xcode; also runs in CI)
make bundle                    # compile + assemble ColdCoach.app (pulls WhisperKit)
```

Note: Apple's Command Line Tools do not ship `XCTest`, so `swift test` needs full Xcode. The
`coldcoach-selftest` executable mirrors the suite so the core can be verified without it.

## Guidelines

- Put new business logic in `ColdCoachCore` with a test (add to both the XCTest suite and, ideally,
  the self-test runner so contributors without Xcode can verify).
- The coaching engine debounces on transcript timestamps, not wall-clock time — keep it
  deterministic so it stays testable.
- Match the existing style: small, single-purpose files behind clear protocols.
- Run `swift run coldcoach-selftest` before opening a PR.

## Good first issues

- SpeakerKit-based diarization for Mode A (behind the existing `DiarizationService` protocol).
- Streaming transcription via WhisperKit's `AudioStreamTranscriber`.
- An Ollama `LLMProvider` for a fully local, key-free option.
- The v2 Practice Range (rehearse against an AI prospect using the same `CoachingEngine`).
