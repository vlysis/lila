# Lila

A mindful activity logger that captures Mode × Orientation moments as Obsidian-compatible Markdown.

## Build & Run

```bash
export PATH="/Users/vivek/dev/flutter/bin:$PATH"
flutter pub get
flutter run                # run on connected device/emulator
flutter build apk --debug  # build Android APK
flutter build ios --debug  # build iOS app (requires Xcode)
flutter build macos --debug # build macOS app (requires CocoaPods)
flutter analyze            # static analysis
flutter test               # run tests
```

## Architecture

- **Framework:** Flutter (Android + iOS + macOS)
- **Storage:** Local `.md` files only, no database
- **Vault path:** `<app documents>/Lila/` by default, user-configurable in Settings
  - Custom path persisted via `SharedPreferences` (`custom_vault_path` key)
  - `FileService.setVaultPath()` updates the path, creates directories, and persists the preference
  - Changing path does not move existing data; old vault remains at its original location
  - Settings uses native folder picker (`file_picker` package) with two options:
    - "Choose existing folder" — opens OS folder picker
    - "Create new folder" — prompts for name, then picks parent location
  - **macOS sandbox:** Custom paths lose permission after app restart. `FileService._init()` tests write access and falls back to default path if permission is lost. Requires `com.apple.security.files.user-selected.read-write` entitlement.
  - `Daily/YYYY-MM-DD.md` — daily log entries + optional `## Reflection` section
  - `Activities/` — reserved for future use
  - `Weekly/YYYY-Www.md` — auto-generated weekly summaries + user reflections
  - `Meta/modes.md` — mode definitions
  - `Trash/YYYY-MM-DD.md` — soft-deleted moments (permanent unless deleted manually)
  - Vault backups can be created/restored from Settings. Backups copy the entire vault
    into a timestamped folder inside a user-chosen destination.

## Project Structure

```
lib/
  main.dart                        # Entry point, dark theme, LilaApp widget
  models/log_entry.dart            # Mode, LogOrientation, LogEntry (with MD serialization)
  services/
    file_service.dart              # File I/O: create/append/read daily + weekly .md files, daily/weekly reflections
    focus_controller.dart          # Current intention + brightness (light/dark) state
    claude_service.dart            # Claude API key storage, integration toggle, format validation
    claude_api_client.dart         # Dio HTTP client for Claude API with retry, error handling, log redaction
    claude_usage_service.dart      # Token usage tracking, daily caps, UTC midnight reset
    synthetic_data_service.dart    # Generates 7 days of test data (debug only)
    weekly_summary_service.dart    # Builds weekly markdown summaries
  screens/
    home_screen.dart               # Today view with mode ribbon, moments list, Log Moment button, reflection input, trash + garden icons
    daily_detail_screen.dart       # Read-only entry list with mode/orientation badges
    daily_reflection_screen.dart   # Legacy full-screen reflection view (home screen now hosts reflection)
    intention_flow_screen.dart     # Intention selector (Builder/Sanctuary/Explorer/Grounded)
    trash_screen.dart              # Trash browser with swipe-to-restore/delete
    visualization_screen.dart      # Balance Garden visualizations (sentiment + word blooms)
    weekly_review_screen.dart      # Weekly visualizations and reflections
    settings_screen.dart           # Vault path (changeable), Obsidian info, reset vault, test data
  widgets/
    log_bottom_sheet.dart          # Log flow: mode grid → orientation → duration presets → optional label
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
- **Duration:** optional, mode-specific presets for capturing "feel" of time
  - Nourishment: moment, stretch, immersive
  - Growth: focused, deep, extended
  - Maintenance: quick, routine, heavy
  - Drift: energizing, short, spiral (stored values remain `brief`, `lost`, `spiral`)
- **LogEntry:** ephemeral — immediately serialized to Markdown, never stored as objects
- **FileService:** singleton with `@visibleForTesting resetInstance()` for test isolation
- Flutter's `Orientation` conflicts with ours, so the enum is named `LogOrientation`
 - **FocusSeason:** Builder, Sanctuary, Explorer, Grounded (Anchor). Explorer is the default.
 - **Theme:** Light/dark mode toggle stored in `SharedPreferences` (`lila_dark_mode`).

## Markdown Entry Format

```markdown
- **Reading**
  mode:: growth
  orientation:: self
  duration:: deep
  at:: 10:32
```

Duration is optional and omitted if the user skips the duration step.

## Design Constraints

- Top AppBar icons are plain (no background ovals); keep tap targets at least 48dp.
- Builder season uses hard rectangle corners for season card and pills.
- Dark mode default, but a light/dark toggle lives in Settings.
- No red/green success states
- Drift visually equal to other modes (no stigma)
- No productivity language
- Minimum 48dp tap targets
- Weekly visualizations use color/proportion only — no numbers, percentages, or scores
- Insights are observational, never prescriptive ("Thursday was the fullest day", not "great job Thursday")

## Claude API Integration

Optional user-configurable Claude API integration accessed via "AI & Integrations" section in Settings.

**ClaudeService** (`lib/services/claude_service.dart`):
- Singleton with `@visibleForTesting resetInstance()` for test isolation
- Uses `flutter_secure_storage` for API key (iOS Keychain, Android EncryptedSharedPreferences)
- Key format validation: `^sk-ant-api03-[A-Za-z0-9_-]{40,}$`
- Masked key display: `sk-ant-...XXXX` (last 4 chars)
- Integration toggle stored in SharedPreferences (`claude_integration_enabled`)
- Model selection and daily token cap preferences

**Settings UI states:**
| State | Toggle | Behaviour |
|-------|--------|-----------|
| No key saved | OFF (greyed) | Prompt: "Enter an API key below to enable." |
| Key saved, off | OFF (active) | Shows masked key |
| Key saved, on | ON | Integration active |

**ClaudeApiClient** (`lib/services/claude_api_client.dart`):
- Singleton with `@visibleForTesting resetInstance()` for test isolation
- Uses `dio` package with base URL `https://api.anthropic.com`
- Required headers: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- Timeouts: connect 10s, receive 60s
- Retry: 3 attempts with exponential back-off + jitter for 429, 500, 502, 503, 504
- `validateApiKey(key)` — sends minimal request (haiku, max_tokens: 1) to verify key
- `sendMessage()` — sends user message, returns response text and token usage

**Error mapping:**
| HTTP | ClaudeApiError | User Message |
|------|----------------|--------------|
| 401 | keyInvalid | "Your API key is invalid or has been revoked..." |
| 429 | rateLimited | "You've reached the API usage limit..." |
| 5xx | serverError | "Something went wrong on Anthropic's side..." |
| timeout | timeout | "The request took too long..." |
| offline | networkOffline | "No internet connection..." |
| — | dailyCapReached | "You've reached your daily token limit..." |
| — | integrationPaused | "Claude integration is paused..." |

**ClaudeUsageService** (`lib/services/claude_usage_service.dart`):
- Tracks input + output tokens per API call
- Stores cumulative daily usage in SharedPreferences
- Resets at UTC midnight
- Configurable daily cap with warning at 90%, pause at 100%
- `formatTokens()` — displays "12.5K" or "1.2M"

**Settings UI additions:**
- Model selector dropdown (Haiku, Sonnet, Opus)
- Usage display ("Today: ~12.5K tokens")
- Daily limit setting (tap to edit, in thousands of tokens)

**Security:**
- Key never logged or displayed after initial entry
- Log redaction interceptor masks API keys in all log output
- Clipboard cleared after paste into key field
- Key stored with platform-native hardware-backed encryption where available

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

## Balance Garden

The Balance Garden visualization screen (garden icon on home AppBar) shows:
1. **Tone summary** — sentiment tone from reflections + tags
2. **Mode pebbles** — color balance across modes
3. **Orientation threads** — proportional bars
4. **Reflection blooms** — recent reflection count
5. **Word blooms** — reflection + tag words with rising highlights
6. **Tone trend** — 7-day tone line

All analysis is local-only (`SentimentAnalyzer`, `WordBloomBuilder`).

## Trash

Trash screen (trash icon + label on home AppBar) allows:
1. Swipe left to permanently delete a trashed moment.
2. Swipe right to restore a trashed moment to its original day.
3. Empty state copy when no deleted moments exist.

## Daily Reflection

Daily reflection now lives on the **home screen**:
1. **Prompt** — changes by time of day (see below)
2. **Reflection text area** — debounced auto-save to `Daily/YYYY-MM-DD.md` under `## Reflection`
3. **Log Reflection button** — logs a "Daily reflection" entry (mode: nourishment, orientation: self)
4. **Entry cards** — "Daily reflection" entries render with the user text and a "Daily reflection" tag

The `daily_reflection_screen.dart` file remains but is no longer the primary UI.

**Home prompt:** The home screen always shows a reflection prompt that changes by time of day.
- Morning (before 12): "What do you want from today?"
- Midday (12–17): "How is today unfolding?"
- Evening (18+): "How did today feel?"

**File structure:** `## Reflection` must always be the last section in daily `.md` files. `appendEntry` inserts new entries before it to preserve this invariant.

**Mode icons:** `assets/icons/` contains `.png` icons for each mode (nourishment, growth, maintenence [sic], drift) and orientation (self, mutual, other), used in the log bottom sheet and daily reflection entry cards.

## App Icon

- Source file: `lila_icon.png`
- Generated outputs: Android `android/app/src/main/res/mipmap-*/ic_launcher.png`, macOS `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`

## Testing

Always add tests when implementing new functionality. Widget tests go in `test/screens/`, service
tests in `test/services/`, and logic tests in `test/logic/`. Run `flutter test` to verify all
tests pass before considering work complete. Always run `flutter test` after making changes.

### Synthetic Data

In debug mode, Settings has a "Generate test week" button that creates 7 days of varied entries
(Mon–Sun) with different mode/orientation distributions and times. Use this to test the weekly
review screen visualizations.
