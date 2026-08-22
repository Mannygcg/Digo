# Digo

**Talk. Digo writes it down.**

Digo is a free, open-source macOS menu bar app that turns your voice into clean, formatted text — anywhere on your Mac. Press a hotkey, talk, and the transcript lands right at your cursor. Transcription runs entirely on-device using [WhisperKit](https://github.com/argmaxinc/WhisperKit), so nothing you say ever leaves your laptop.

## Features

- **Speak anywhere** — one global hotkey (or a menu bar click) starts dictation in whatever app you're using
- **On-device transcription** — powered by WhisperKit, no network round-trip, no account
- **Menu bar only** — Digo has no dock icon or main window; it lives quietly in the menu bar
- **Configurable hotkey** — set your own shortcut via [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- **Launch at login** — optional, so it's ready when you are

## Requirements

- macOS 14.0 (Sonoma) or later
- Microphone access (Digo asks for this on first use)

## Install

Digo isn't notarized (no Apple Developer Program membership behind this project, on purpose — it's free and community-run), so macOS Gatekeeper will flag the first launch as from an "unidentified developer." That's expected for an app distributed this way.

1. Download the latest `.dmg` from the [Releases page](../../releases)
2. Drag **Digo.app** into `/Applications`
3. On first launch, right-click (or Control-click) the app and choose **Open**, then confirm — you only need to do this once
4. Grant microphone access when prompted

A Homebrew cask (`brew install --cask digo`) is planned once there's a stable first release.

## Build from source

Digo uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`, so the `.xcodeproj` stays out of merge-conflict territory.

```bash
brew install xcodegen
git clone https://github.com/Mannygcg/Dilo.git
cd Dilo/Digo
xcodegen generate
open Digo.xcodeproj
```

Build and run the `Digo` scheme (⌘R). Swift Package Manager will resolve `KeyboardShortcuts` and `WhisperKit` automatically.

## Contributing

Issues and pull requests are welcome. If you're planning something larger than a small fix, open an issue first so we can talk through the approach.

## License

Digo is released under the [MIT License](LICENSE) — use it, fork it, ship it.
