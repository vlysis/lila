# Tutorial Screenshot Plan v1

## Goal

Add clear, maintainable screenshots to `/Users/vivek/dev/lila/tutorial_lila.md`.

## Plan

1. Decide screenshot set (8-12 max) that maps to tutorial sections.
2. Capture consistently (same device/theme/sample data).
3. Store images in repo with stable naming.
4. Insert Markdown image links + short captions.
5. Add a lightweight “refresh screenshots” process.

## Suggested Screenshot List

1. Home (today view)
2. Log Moment sheet (mode selection)
3. Orientation + duration step
4. Reminder sheet
5. Past-day navigation view
6. Weekly Review screen
7. Balance Garden screen
8. Trash screen
9. Settings (vault + theme/model area)

## Repository Layout

- `/Users/vivek/dev/lila/docs/images/tutorial/`
- Naming convention: `01-home.png`, `02-log-mode.png`, etc.

## How to Capture

1. Use simulator/emulator with fixed size (for example, iPhone 15 or Pixel 6).
2. Seed deterministic test data (the debug “Generate test week” feature is ideal).
3. Use light mode first (matches default), optionally add a dark-mode appendix.
4. Keep status bar/time consistent where possible for visual polish.

## How to Embed in Markdown

Use relative links from `tutorial_lila.md`, for example:

```md
## Home Screen
![Home screen](docs/images/tutorial/01-home.png)
*Today view with Log Moment, Set Alarm, and reflection area.*
```

## Quality Checklist

- Same aspect ratio across all screenshots
- No personal/sensitive text
- Readable tap targets/text
- One screenshot per subsection (avoid clutter)

## Next Action

Add placeholder screenshot sections to `/Users/vivek/dev/lila/tutorial_lila.md` so images can be dropped into `docs/images/tutorial/` later.
