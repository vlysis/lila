# Lila Markdown Data Model

This document defines how Lila stores user data as Obsidian-compatible Markdown files.

## Overview

Lila persists all app data as plain `.md` files in a vault directory. There is no database layer.

Default vault location:
- `<app documents>/Lila/`

Configurable vault location:
- User can select a custom folder in Settings.
- Custom path is stored in `SharedPreferences` under `custom_vault_path`.
- Changing vault path does **not** migrate old files.

## Vault Directory Structure

```text
<vault>/
  Daily/
    YYYY-MM-DD.md
  Weekly/
    YYYY-Www.md
  Reminders/
    YYYY-MM-DD.md
  Trash/
    YYYY-MM-DD.md
  Meta/
    modes.md
  Activities/           # reserved for future use
```

## Daily Files

Path pattern:
- `Daily/YYYY-MM-DD.md`

Purpose:
- Stores logged moments for that date.
- Optionally stores a reflection section.

### Entry Block Format

Each log entry is a Markdown list item followed by indented key-value lines:

```markdown
- **Reading**
  mode:: growth
  orientation:: self
  duration:: deep
  at:: 10:32
```

Fields:
- `label` (in list title): free-form entry label (e.g., `Reading`)
- `mode::` one of: `nourishment`, `growth`, `maintenance`, `drift`, `decay`
- `orientation::` one of: `self`, `mutual`, `other`
- `duration::` optional mode-specific duration keyword
- `at::` local time in `HH:mm`

`duration::` is omitted when user skips duration.

### Reflection Section

Daily files may include a reflection section:

```markdown
## Reflection
<free-form reflection text>
```

Invariant:
- `## Reflection` must be the **last section** in daily files.
- When appending new entries, they are inserted before this section.

## Reminder Files

Path pattern:
- `Reminders/YYYY-MM-DD.md`

Purpose:
- Stores one-time reminders for the date.

### Reminder Block Format

```markdown
- **Get eggs**
  id:: rem_1738967000000_12345_1739042400000
  remind_at:: 2026-02-07T15:00:00-08:00
  alert_offset_min:: 0
  created_at:: 2026-02-06T11:42:00-08:00
  done:: false
  done_at::
```

Fields:
- `label` (in list title): reminder text
- `id::` unique reminder identifier
- `remind_at::` ISO-8601 local timestamp
- `alert_offset_min::` integer minutes before `remind_at` (`0` means at-time)
- `created_at::` ISO-8601 local timestamp
- `done::` boolean (`true`/`false`)
- `done_at::` ISO-8601 local timestamp when completed, else empty

Lifecycle:
- New reminders start with `done:: false` and empty `done_at::`.
- Completing reminder sets `done:: true` and records `done_at::`.

## Weekly Files

Path pattern:
- `Weekly/YYYY-Www.md`

Purpose:
- Stores generated weekly summaries.
- Persists user-written weekly reflection.

### Reflection Section

Weekly files include:

```markdown
## Reflection
<free-form weekly reflection text>
```

Behavior:
- Weekly reflection is debounced auto-save from weekly review UI.
- Reflection persists across sessions.

## Trash Files

Path pattern:
- `Trash/YYYY-MM-DD.md`

Purpose:
- Stores soft-deleted moments.

Behavior:
- Restoring returns a moment to original day file.
- Permanent delete removes the trashed item from trash file.
- Data remains indefinitely unless explicitly deleted.

## Meta Files

Path:
- `Meta/modes.md`

Purpose:
- Stores mode definitions/metadata used by app.

## Field Semantics

### Mode
Allowed values:
- `nourishment`
- `growth`
- `maintenance`
- `drift`
- `decay`

### Orientation
Allowed values:
- `self`
- `mutual`
- `other`

### Duration Vocabulary
Mode-specific labels used in UI:
- Nourishment: `moment`, `stretch`, `immersive`
- Growth: `focused`, `deep`, `extended`
- Maintenance: `quick`, `routine`, `heavy`
- Drift: UI labels `energizing`, `short`, `spiral`; stored values remain `brief`, `lost`, `spiral`
- Decay: `pang`, `erosion`, `flood`

## Date and Naming Conventions

- Daily/reminder/trash files: `YYYY-MM-DD.md`
- Weekly files: ISO-like week key `YYYY-Www.md`
- Times in entries: `HH:mm`
- Reminder timestamps: ISO-8601 with timezone offset

## Data Model Invariants

1. Local-first markdown storage only (no DB).
2. Daily reflections must remain the final section in daily file.
3. Log entries are serialized immediately; no persistent object store.
4. Reminder completion is represented by `done` + `done_at` fields.
5. Weekly reflection is persisted in weekly markdown under `## Reflection`.
6. Custom vault path changes destination for future reads/writes; existing data is not moved.

## Compatibility Notes

- Markdown is designed to stay human-readable and Obsidian-compatible.
- File-per-day organization supports easy backup, sync, and external editing.
- Vault backup/restore operates by copying the entire vault directory.
