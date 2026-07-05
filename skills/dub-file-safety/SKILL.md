# Skill: Dub File Safety

Use this skill whenever writing, editing, or reviewing any code that renames, moves, or otherwise mutates a file on disk within the Dub app or Finder extension.

## Non-negotiables

- **All renames must go through `NSFileCoordinator` and `NSFilePresenter`.** Never use a raw `FileManager.moveItem` or `FileManager.replaceItem` call to rename a user's file. This is required for both correctness (notifying other apps/Finder of the change) and sandbox compliance.
- **Never overwrite an existing file.** If the target filename already exists, resolve the collision by appending a counter suffix (`-1`, `-2`, ...) before the extension. Check for collisions after all formatting (case style, date prefix, length truncation) has been applied to the candidate name.
- **Batch renames are sequential, not parallel.** Process files within a single batch one at a time, in Finder selection order, so two files that independently generate the same AI output cannot race to claim the same filename.
- **The AI call has a hard 15-second timeout per file.** If the on-device model has not returned a result within that window, fall back to the metadata-based naming scheme rather than waiting further or hanging the extension.
- **Skip files that should not be touched, and report why.** Do not attempt to force-rename or force-close files in these states — skip and include them in the completion notification/error summary:
  - Locked or read-only files
  - Files not yet fully downloaded from iCloud (on-demand/dataless files)
  - Files currently open in another application
  - Files the sandboxed extension lacks permission to access (prompt for Full Disk Access instead)
- **Idempotency check first.** Before running AI inference, check whether the file's current name already matches the user's active naming convention/format. If it does, skip re-analysis unless the user has enabled "Re-analyze already-renamed files."
- **Sanitize AI output before it becomes a filename.** Strip or transliterate non-ASCII characters, emoji, and filesystem-illegal characters (`/`, `:`, leading dots, etc.) from the raw model output before passing it into the case-formatting step.

## When reviewing existing code

Flag any of the following as a bug, not a style preference:
- A rename implemented via direct `FileManager` calls instead of `NSFileCoordinator`.
- A batch loop that dispatches renames concurrently (e.g., via `DispatchQueue.concurrentPerform` or unstructured `Task {}` per file) without sequencing.
- Missing timeout handling around the FoundationModels call.
- A collision check performed before formatting/truncation is applied, which can miss collisions introduced by truncation.

Reference: REQUIREMENTS.md §4.2, §4.3, §5.
