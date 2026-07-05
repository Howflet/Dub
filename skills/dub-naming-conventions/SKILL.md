# Skill: Dub Naming Conventions

Use this skill whenever writing or editing the FoundationModels prompt, or the filename-formatting logic that runs on its output.

## AI prompt constraints

The prompt sent to FoundationModels must constrain the model to output:
- Exactly 2-4 words
- Lowercase only
- Words separated by underscores
- Describing the primary subject of the image/document only
- No file extension included in the output
- No punctuation, emoji, or non-ASCII characters (if any appear anyway, they are sanitized downstream — see `dub-file-safety` skill — but the prompt should still ask the model not to produce them in the first place)

Example of the shape the model should return: `golden_retriever_park`, `handwritten_grocery_list`, `sunset_beach_photo`.

## Post-processing / case formatting

The raw underscore-separated output is the canonical intermediate form. Apply the user's selected format on top of it:

| Format | Example | Notes |
|---|---|---|
| `snake_case` | `red_barn` | **Default.** Also the raw model output format — no transformation needed. |
| `kebab-case` | `red-barn` | Replace underscores with hyphens. |
| `Title Case` | `Red Barn` | Replace underscores with spaces, capitalize each word. |
| `camelCase` | `redBarn` | Remove underscores, capitalize each word after the first. |

Formatting order of operations (must happen in this sequence):
1. Raw model output (sanitized per `dub-file-safety`)
2. Apply case format (table above)
3. Prepend date, if the user has date-prefixing enabled (e.g., `2026-07-05_red_barn.jpg`)
4. Truncate to the user's configured max length
5. Check for filename collisions (after truncation, not before — truncation can itself introduce a new collision)

## Metadata fallback naming

When falling back (AI unavailable, timeout, unsupported file type — see `dub-file-safety`), construct the name from metadata rather than the model:
- Pattern: `photo_[orientation]_[MMdd]_[HHmm]` (e.g., `photo_landscape_0702_1430.jpg`)
- Orientation derived from image resolution (width vs. height) via `ImageIO`, not from AI analysis
- The same case-format/date-prefix/length/collision pipeline above still applies to fallback-generated names — the fallback only replaces the *source* of the base name, not the formatting pipeline.

Reference: REQUIREMENTS.md §4.2, §4.3.
