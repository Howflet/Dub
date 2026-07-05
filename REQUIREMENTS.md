# Dub: Product Requirements Document (PRD)

**Version**: 1.0
**Last Updated**: 2026-07-05
**Author**: Howard Fletcher

## 1. Overview
**Dub** is a macOS utility application that automates the renaming of files (primarily images, screenshots, and documents) using on-device Apple Intelligence. It allows users to right-click files in Finder, analyze their contents, and instantly rename them to concise, descriptive, and consistently formatted filenames based on user-defined conventions.

## 2. Core Objectives
- Provide a frictionless file renaming experience directly integrated into macOS Finder.
- Leverage local Apple Intelligence (FoundationModels) to infer semantic meaning from images and generate highly descriptive, 2-4 word filenames (e.g., `golden_retriever_park.jpg`).
- Enforce consistent file naming structures across a user's filesystem (e.g., casing, date prefixes, length limits).
- Fall back gracefully to basic metadata-based naming if AI is unavailable.
- Keep all processing on-device: no telemetry, no network calls, no data leaving the user's Mac as part of the core renaming flow.

## 3. Scope & Target Audience
**Target Audience**: macOS power users, designers, developers, and photographers who struggle with generic filenames (like `IMG_0123.HEIC` or `Screen Shot 2026-07-02 at 10.00.00 AM.png`).
**Platform**: macOS, Apple Silicon (M-series) required for on-device AI via FoundationModels, targeting macOS 26.0+. Note: the FoundationModels requirement is chip-based, not OS-version-based — an Intel Mac running macOS 26.0+ still cannot run on-device inference and must use the metadata fallback path (see 4.2).

### 3.1 Non-Goals (V1)
To keep scope contained, the following are explicitly out of scope for V1:
- Renaming files inside iCloud Drive shared folders or other multi-user shared storage.
- Renaming files that are actively open in another application.
- Any cloud-based LLM fallback (see 6, Future Considerations).
- Batch renaming across more than one folder/location in a single operation.
- Localization/non-English UI (English only for V1).

## 4. Key Features & Requirements

### 4.1 Finder Integration (App Extension)
- **Context Menu Access**: Must provide a macOS Finder Extension (Quick Action) named `Dub`.
- **Background Processing**: The extension should process the selected files immediately without launching a visible window.
- **Batch Processing**: Support renaming multiple files simultaneously, within a single folder/selection (see 3.1 Non-Goals for cross-folder limits).
- **Notifications**: Deliver system notifications upon completion (e.g., "Dubbed 3 files ✓" or error summaries).
- **Onboarding & Permissions**: First-run flow must guide the user through:
  - Enabling the Finder Extension in System Settings > Extensions (extensions are disabled by default and cannot be enabled programmatically).
  - Confirming Apple Intelligence is enabled on the device; if not, direct the user to System Settings and explain that Dub will use the metadata fallback until enabled.
  - Requesting Full Disk Access if the user wants to rename files outside sandbox-accessible locations (Desktop, Downloads, Documents are covered by default; anything else requires this).

### 4.2 AI Renaming Engine
- **Image Analysis**: Load images (`.jpg`, `.png`, `.heic`, `.webp`, `.tiff`, etc.), screenshots and documents (`.pdf`, `.docx`, `.txt`, etc.).
- **Prompting & Constraints**: Prompt the AI to output exactly 2-4 lowercase words separated by underscores, describing the primary subject without the file extension.
- **Output Sanitization**: Strip or transliterate any non-ASCII characters, emoji, or filesystem-illegal characters (`/`, `:`, leading dots, etc.) from the AI's raw output before it is passed into the formatting stage (4.3).
- **Timeout Management**: Impose strict timeouts (e.g., 15 seconds per file) so the Finder extension does not hang indefinitely.
- **Fallback Mechanism**: Fall back to a metadata-driven naming scheme (e.g., `photo_landscape_0702_1430.jpg` based on resolution and timestamp) in any of the following cases:
  - Apple Intelligence is unavailable, disabled, or not supported on the device (non-Apple-Silicon hardware).
  - The on-device model call times out (see above).
  - The file type is unsupported for AI analysis.
- **Idempotency**: If a file's current name already matches Dub's active naming convention/format, Dub should detect this and skip re-analysis by default, rather than silently re-running inference and potentially renaming an already-well-named file. This behavior should be a togglable preference ("Re-analyze already-renamed files").

### 4.3 Formatting & Preferences
- **Naming Conventions**: Allow users to format the AI's raw output into:
  - `snake_case` (e.g., `red_barn`) — **default**
  - `kebab-case` (e.g., `red-barn`)
  - `Title Case` (e.g., `Red Barn`)
  - `camelCase` (e.g., `redBarn`)
- **Date Prefixing**: Option to prepend the current date (e.g., `2026-07-05_red_barn.jpg`).
- **Length Limits**: Configurable maximum filename length (e.g., 10 to 100 characters).
- **Collision Resolution**: Automatically handle filename collisions by appending a counter (e.g., `-1`, `-2`) to ensure files are never overwritten. Within a single batch operation, files must be processed and renamed sequentially (in Finder selection order) rather than in parallel, so that two files independently generating the same AI output cannot race to claim the same filename.

### 4.4 User Interface (Main App)
- **Architecture**: A SwiftUI-based macOS app featuring a `NavigationSplitView` with a sidebar.
- **Settings View**: Exposes toggles and sliders for the formatting preferences listed above, along with live previews of the filename structure.
- **History View**: Persists and displays a log of previously renamed files, allowing users to track what was changed.
  - Each history entry stores: original filename, new filename, timestamp, and file path (for future undo support per 6, Future Considerations). Thumbnails are not stored in V1 to limit data footprint and avoid retaining copies of user image content.
  - History retention is capped (e.g., most recent 500 entries, or a configurable 30/90-day window), after which older entries are pruned automatically.
- **Shared State**: Preferences and history must be shared between the Main App and the Finder Extension (via App Groups/`UserDefaults`).

## 5. Technical Requirements
- **Frameworks**:
  - `SwiftUI` for the main application interface.
  - `AppKit` (NSViewController) for the Finder Action extension.
  - `FoundationModels` for local Apple Intelligence APIs.
  - `ImageIO` & `CoreGraphics` for memory-efficient image loading.
  - `UserNotifications` for completion alerts.
- **File Coordination**: File renaming within the extension sandbox *must* use `NSFileCoordinator` and `NSFilePresenter` to safely move/rename files and notify the OS.
- **App Groups**: Both the main app target and extension target must belong to the same App Group to share preferences (`UserPreferences.swift`) and data.
- **File Access Edge Cases**: The rename pipeline must explicitly handle, rather than silently fail on:
  - Locked or read-only files (skip, report in the completion notification/summary).
  - Files still downloading from iCloud (on-demand/not fully materialized locally) — skip and notify, do not block waiting for download.
  - Files open in another application (skip and notify; do not force-close or force-rename).
  - Files the sandboxed extension lacks permission to access (skip and prompt for Full Disk Access if relevant).
- **Distribution**: Target distribution is via **Homebrew** (as a Cask), outside the Mac App Store. The app and extension must still be code-signed and notarized by Apple for Gatekeeper to allow installation, but Homebrew distribution avoids Mac App Store sandbox entitlement restrictions, giving more flexibility for Full Disk Access and broader file system access than the App Store path would allow.

### 5.1 Non-Functional Requirements
- **Extension memory ceiling**: Finder Sync/Action extensions are terminated by macOS if they exceed system-imposed memory limits; the extension should stay well under this (target: under 50MB resident for typical single-image jobs) to avoid being killed mid-batch.
- **Latency**: Per-file processing (AI inference + fallback + rename) should complete within the 15-second AI timeout plus no more than ~1 additional second of overhead for formatting/file I/O.
- **Batch size**: Define a maximum supported batch size for a single Quick Action invocation (e.g., 50 files) beyond which the user is warned or the batch is chunked.

## 6. Future Considerations (Post-V1)
- Support for document analysis (PDFs, text files).
- Undo functionality (reverting a rename directly from the History View), enabled by the file path already being tracked in history (see 4.4).
- Cloud-based LLM fallbacks (e.g., Gemini or OpenAI) for users without Apple Intelligence hardware. Any such fallback must be opt-in and clearly disclosed to the user before any file content leaves the device, consistent with the on-device-first privacy stance in Section 2.
- Localization of the main app UI and notifications.
- Cross-folder / multi-location batch renaming.

## 7. Success Metrics
- **Rename acceptance rate**: percentage of AI-generated names not manually reverted or re-renamed by the user within 24 hours (target: >85%).
- **Extension latency**: median time from Quick Action invocation to completion notification for a single file (target: under 5 seconds, excluding AI timeout edge cases).
- **Stability**: crash-free session rate for both the main app and the Finder extension (target: >99.5%).
- **Fallback rate**: percentage of renames that fall back to the metadata scheme rather than completing via AI, tracked locally (not transmitted) to help gauge real-world Apple Intelligence availability during testing.