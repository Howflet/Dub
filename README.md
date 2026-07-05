# Dub

A macOS utility that renames files (images, screenshots, documents) using on-device Apple Intelligence, accessible via a Finder right-click Quick Action.

Full product spec: see [`REQUIREMENTS.md`](./REQUIREMENTS.md).

## Status

🚧 **Pre-alpha / de-risking phase.** No user-facing app yet.

Currently validating the two riskiest technical unknowns before building out full feature scope:
- [ ] Minimal Finder Extension that can rename a file via `NSFileCoordinator` / `NSFilePresenter`
- [ ] Minimal `FoundationModels` call on an image, with timeout handling

Once both spikes work independently, next step is a single end-to-end vertical slice (one file, snake_case only, no preferences UI) before broadening to the rest of the PRD.

## Requirements

- Xcode: 26.6
- macOS SDK: 26.0+
- Apple Silicon (M-series) required for on-device AI via FoundationModels — Intel Macs use the metadata fallback path only (see REQUIREMENTS.md §3, §4.2)
- Apple Intelligence enabled on the test device/simulator

## Project Structure

- **Main App target**: `[fill in target name]` — SwiftUI app (NavigationSplitView, Settings, History)
- **Finder Extension target**: `[fill in target name]` — AppKit-based Finder Action extension
- **Shared App Group**: `[fill in App Group identifier, e.g. group.com.hkfletcher.dub]` — shares `UserPreferences.swift` and history data between the two targets via `UserDefaults`

> Both targets must be signed with the same App Group entitlement. If preferences/history aren't syncing between the app and extension during testing, check this first.

## Distribution

Target distribution is via **Homebrew** (Cask), not the Mac App Store. Still requires Apple code-signing and notarization for Gatekeeper. See REQUIREMENTS.md §5 for the sandboxing implications.

## Development Notes

- All file renames must go through `NSFileCoordinator` — never a raw `FileManager.moveItem` call.
- Finder extension has a hard 15s timeout on AI calls before falling back to metadata-based naming.
- See REQUIREMENTS.md §3.1 for explicit V1 non-goals (no cloud LLM fallback, no cross-folder batch renaming, no iCloud shared folder support).
