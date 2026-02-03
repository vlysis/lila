# Lila

A mindful activity logger that captures Mode × Orientation moments as Obsidian-compatible Markdown.

## Build & Run

```bash
export PATH="/Users/vivek/dev/flutter/bin:$PATH"
flutter pub get
flutter run                # run on connected device/emulator
flutter build apk --debug  # build Android APK
flutter build macos --debug # build macOS app (requires CocoaPods)
flutter analyze            # static analysis
flutter test               # run tests
```

## Architecture

- **Framework:** Flutter (Android + macOS)
- **Storage:** Local `.md` files only, no database
- **Vault path:** `<app documents>/Lila/`
  - `Daily/YYYY-MM-DD.md` — daily log entries + optional `## Reflection` section
  - `Activities/` — reserved for future use
  - `Weekly/YYYY-Www.md` — auto-generated weekly summaries + user reflections
  - `Meta/modes.md` — mode definitions

## Project Structure

```
lib/
  main.dart                        # Entry point, dark theme, LilaApp widget
  models/log_entry.dart            # Mode, LogOrientation, LogEntry (with MD serialization)
  services/
    file_service.dart              # File I/O: create/append/read daily + weekly .md files, daily/weekly reflections
    synthetic_data_service.dart    # Generates 7 days of test data (debug only)
    weekly_summary_service.dart    # Builds weekly markdown summaries
  screens/
    home_screen.dart               # Today view with whisper, summary, FAB, evening reflection prompt
    daily_detail_screen.dart       # Read-only entry list with mode/orientation badges
    daily_reflection_screen.dart   # End-of-day reflection: day summary, entry cards, free-text reflection
    weekly_review_screen.dart      # Weekly visualizations and reflections
    settings_screen.dart           # Vault path, Obsidian info, reset vault, test data
  widgets/
    log_bottom_sheet.dart          # Log flow: mode grid → orientation → optional label
    whisper.dart                   # Reflection text based on today's entries
    weekly_whisper.dart            # Single-line weekly reflection (first-match rule)
    weekly_insights_widget.dart    # Multi-insight cards (mode balance, rhythm, streaks, arcs)
    week_texture_widget.dart       # Mode pebble river visualization (colored dots per day)
    orientation_threads_widget.dart # Colored proportional bars (violet/teal/terracotta)
    daily_rhythm_widget.dart       # Time-of-day heatmap grid colored by dominant mode
```

## Key Concepts

- **Mode:** nourishment, growth, maintenance, drift
- **Orientation:** self, mutual, other
- **LogEntry:** ephemeral — immediately serialized to Markdown, never stored as objects
- Flutter's `Orientation` conflicts with ours, so the enum is named `LogOrientation`

## Markdown Entry Format

```markdown
- **Reading**
  mode:: growth
  orientation:: self
  at:: 10:32
```

## Design Constraints

- Home AppBar buttons use circular containers (36×36, white @ 8% fill, 20px icons)
- Dark mode default
- No red/green success states
- Drift visually equal to other modes (no stigma)
- No productivity language
- Minimum 48dp tap targets
- No save button — auto-saves on mode + orientation selection; reflections auto-save with 1s debounce
- Weekly visualizations use color/proportion only — no numbers, percentages, or scores
- Insights are observational, never prescriptive ("Thursday was the fullest day", not "great job Thursday")

## Weekly Review

The weekly review screen (accessed via week icon in home AppBar) contains:
1. **Weekly whisper** — single italic observation (first-match rule)
2. **Week texture** — mode-colored pebble dots per day
3. **Orientation threads** — colored bars (Self=violet, Mutual=teal, Other=terracotta)
4. **Daily rhythm** — 7×4 heatmap colored by dominant mode per time bucket
5. **Insights** — up to 5 auto-generated observation cards with colored left borders
   (mode balance, absent modes, busiest/quietest day, time patterns, weekend shift, orientation arc, streaks)
6. **Reflection** — user-written text area, debounced auto-save to `Weekly/YYYY-Www.md`

Weekly markdown includes `## Reflection` section that persists user text across sessions.

## Daily Reflection

The daily reflection screen (accessed via edit icon in home AppBar, or evening whisper prompt) contains:
1. **Date header** — "Monday, February 2" style
2. **Day summary** — entry count + mode breakdown
3. **Daily whisper** — same logic as home screen whisper
4. **Entry cards** — each logged moment shown with mode icon (from `assets/icons/`), label, mode pill, orientation pill, and timestamp. "Daily reflection" entries render differently: no icon, user's reflection text shown in the pill, single "Daily reflection" tag.
5. **Reflection text area** — free-text, placeholder "How did today feel?", debounced 1s auto-save to `Daily/YYYY-MM-DD.md` under `## Reflection`
6. **Log button** — logs a "Daily reflection" entry (mode: nourishment, orientation: self) to the daily file

**Evening whisper:** After 6pm, if entries exist today, the home screen shows a tappable italic prompt ("How did today feel?" or "Reflection written.") that navigates to the reflection screen.

**File structure:** `## Reflection` must always be the last section in daily `.md` files. `appendEntry` inserts new entries before it to preserve this invariant.

**Mode icons:** `assets/icons/` contains `.png` icons for each mode (nourishment, growth, maintenence [sic], drift) and orientation (self, mutual, other), used in the log bottom sheet and daily reflection entry cards.

## Testing with Synthetic Data

In debug mode, Settings has a "Generate test week" button that creates 7 days of varied entries
(Mon–Sun) with different mode/orientation distributions and times. Use this to test the weekly
review screen visualizations.
