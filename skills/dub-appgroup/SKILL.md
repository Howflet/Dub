# Skill: Dub App Group & Shared State

Use this skill whenever writing or editing code that reads/writes shared preferences or history data, or when configuring entitlements/capabilities for either target.

## Identifiers

- **App Group identifier**: `group.kevonfletcher.dub`
- **Main App target name**: `Dub` (Bundle ID: `com.kevonFletcher.Dub`)
- **Finder Extension target name**: `DubFinderExtension` (Bundle ID: `com.kevonFletcher.Dub.DubFinderExtension`) — this is an **Action Extension**, not a Finder Sync Extension (see `dub-file-safety` skill / project history for why that distinction matters)
- **Shared `UserDefaults` suite name**: same as the App Group identifier above (`UserDefaults(suiteName:)`)

Note: the Group ID intentionally does not follow the same reverse-DNS casing as the Bundle ID (`group.kevonfletcher.dub` vs. `com.kevonFletcher.Dub`) — this is cosmetic only and both are functional as registered. Do not "fix" this mismatch without updating both targets' entitlements together.

## Rules

- **Both targets must share the exact same App Group identifier** in their entitlements files. A mismatch (even a typo) will cause preferences/history to silently fail to sync — the extension will read stale/default values with no error thrown. If preferences aren't syncing during testing, check this first, before debugging the Swift code.
- **All shared preferences live in `UserPreferences.swift`**, a shared model file accessible to both targets (add it to both target memberships in Xcode, or place it in a shared framework/package if the project grows).
- **Do not invent a new App Group identifier or suite name.** If this file's placeholder hasn't been filled in yet, ask the user for the real identifier rather than generating a plausible-looking one — a made-up identifier will compile fine and fail silently at runtime.
- **History data** (original filename, new filename, timestamp, file path) is also written through the shared App Group container, not to each target's private sandbox, so the History View in the main app can read renames performed by the extension.
- **Retention**: history is capped (most recent 500 entries or a configurable 30/90-day window) — any write path to history should also check/enforce pruning, not just the read path.

Reference: REQUIREMENTS.md §4.4, §5.
