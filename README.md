# ColdCoach

**Local, open-source live coaching for cold calls. Call better, not more.**

ColdCoach is a native macOS app that listens to your call on-device, transcribes it with
WhisperKit, and drops a coaching card in your ear the moment the prospect raises an objection,
asks a question, or shows a buying signal. It generates a signal-based playbook from a one-sentence
description of your offer, and improves that playbook from the outcomes you log. Everything runs on
your Mac with your own AI key — no hosted backend, no subscription.

It is a self-hostable, single-user reimagining of the valuable core of paid tools like Deals
Machine, distilled to the two pillars that actually move calls: a **Playbook** brain and a **Live
Cockpit**.

---

## What it does

- **Playbook** — describe your offer in one sentence; get openers tied to real signals, discovery
  questions, and objection-handling responses. Editable, stored locally.
- **Live Cockpit** — start a call and ColdCoach transcribes both sides on-device, detects the
  moment (objection / question / buying signal), and shows a coaching card in a floating overlay,
  targeting ~1.5–2s from the prospect finishing their sentence.
- **Self-improving** — after each call you log the outcome (and optionally which opener you used);
  the playbook's weights nudge up on wins and down on losses.

## Requirements

- Apple Silicon Mac, macOS 14 (Sonoma) or later.
- A **Claude (Anthropic)**, **OpenAI**, or **OpenRouter** API key (bring your own — stored in the macOS Keychain). One OpenRouter key fronts many models.
- Transcription is on-device (WhisperKit); the speech model downloads on first use.

## Install

### Build from source (works today)

```sh
git clone https://github.com/tiXor-code/coldcoach.git
cd coldcoach
make bundle          # compiles the app (pulls WhisperKit) and assembles ColdCoach.app
open build/ColdCoach.app
```

The app is ad-hoc signed. On first launch, right-click it in Finder and choose **Open** (Gatekeeper),
or run `xattr -dr com.apple.quarantine build/ColdCoach.app`.

### Homebrew cask (once releases are published)

```sh
brew install --cask tiXor-code/coldcoach/coldcoach
```

Homebrew strips the Gatekeeper quarantine automatically, so this is the lowest-friction path. See
`dist/Casks/coldcoach.rb`.

## First run

1. **Connect your AI** — pick Claude, OpenAI, or OpenRouter, paste your API key (stored in the Keychain). With OpenRouter, set the model IDs to namespaced slugs (for example `openai/gpt-4o-mini`); see https://openrouter.ai/models.
2. **Grant permissions** — Microphone (both modes) and, for System-audio mode, Screen Recording.
3. **Create a playbook** — one sentence about your offer, then Generate.
4. **Start a call** — pick the playbook and a capture mode, put your call on, and hit Start.

## Two capture modes

- **Speakerphone (mic only)** — put the phone on speaker next to your Mac; everything is captured
  through the microphone. Roles (you vs. them) are inferred by a pause-gap heuristic.
- **System audio + mic** — the prospect is captured via ScreenCaptureKit system audio (works
  alongside any softphone, Zoom, or phone mirroring) and you via the mic. Clean, deterministic roles.

## How it works

```
AudioSource ──PCM──▶ Transcription ──segments──▶ TranscriptStore
  (mic / system)      (WhisperKit)        │
                                          ▼
                          CoachingEngine (fires on prospect objection / question / buying signal)
                                          │  builds a prompt from Playbook + recent transcript
                                          ▼
                       LLMProvider (Claude | OpenAI | OpenRouter)  ──▶  floating overlay card
                                          │
                          after call ──▶ outcome logged ──▶ Playbook re-weighted
```

The reasoning core (`ColdCoachCore`) is pure Swift with no UI or audio dependencies: LLM providers,
playbook generation and weighting, intent classification, the coaching trigger/debounce logic, the
transcript store, role assignment, and JSON persistence. The app layer wires WhisperKit,
AVAudioEngine, ScreenCaptureKit, the Keychain, an `NSPanel` overlay, and SwiftUI on top of it.

## Privacy

- Your API key lives in the macOS Keychain, never on disk in plaintext.
- Speech-to-text runs entirely on-device (WhisperKit). Audio never leaves your Mac.
- The only network calls are to the AI provider you configured, to generate the playbook and the
  coaching cards. Nothing is uploaded anywhere else. Playbooks, transcripts, and call history are
  stored as local JSON under `~/Library/Application Support/ColdCoach/`.

## Development

The reasoning core is fully testable without Xcode, audio, or the network:

```sh
swift run coldcoach-selftest    # dependency-free assertion runner (works with Command Line Tools)
swift test                      # standard XCTest suite (needs full Xcode; runs in CI)
```

Building the app pulls WhisperKit:

```sh
make app        # compile only
make bundle     # compile + assemble ColdCoach.app
make dmg        # + package a .dmg
```

### Project layout

```
Sources/ColdCoachCore/     Pure-Swift brain (LLM, Playbook, Coaching, Transcription, Persistence)
Sources/ColdCoachApp/      SwiftUI app: Audio, Transcription (WhisperKit), Overlay, UI, System
Sources/ColdCoachSelfTest/ Dependency-free core self-test
Tests/ColdCoachCoreTests/  XCTest suite + fixtures
dist/                      Info.plist, entitlements, Homebrew cask
```

## Roadmap

- **v2 — Practice Range**: rehearse against a lifelike AI prospect using the same coaching engine,
  with scoring. WhisperKit's bundled TTS makes the AI-prospect voice cheap to add.
- **SpeakerKit diarization** for higher-accuracy roles in speakerphone mode (currently a pause-gap
  heuristic + LLM inference).
- **Streaming transcription** (`AudioStreamTranscriber`) and streamed coaching-card tokens for
  tighter latency.
- **Pluggable local LLM** (Ollama) for a fully offline, key-free option.

## Credits & license

- Speech-to-text by [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) (Argmax), MIT.
- ColdCoach is MIT licensed. See [LICENSE](LICENSE).
