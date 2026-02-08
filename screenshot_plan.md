# Android Screenshot Implementation Plan

## Scope

Create a repeatable Android emulator workflow to capture tutorial screenshots for:
- `/Users/vivek/dev/lila/tutorial_lila.md`

Output directory:
- `/Users/vivek/dev/lila/docs/images/tutorial/`

## Objectives

1. Produce consistent, high-quality screenshots from Android emulator only.
2. Keep filenames stable so markdown links do not change.
3. Make regeneration easy after UI updates.

## Screenshot Set

Use this fixed list:

1. `01-home.png` — Home (today)
2. `02-log-mode.png` — Log Moment sheet (mode step)
3. `03-log-orientation-duration.png` — orientation/duration step
4. `04-reminder-sheet.png` — reminder creation sheet
5. `05-past-day-navigation.png` — past day view with return-to-today
6. `06-weekly-review.png` — weekly review screen
7. `07-balance-garden.png` — garden visualization
8. `08-trash.png` — trash screen
9. `09-settings.png` — settings screen

## Environment Setup

1. Ensure Android SDK and emulator are installed.
2. Use a single AVD for consistency (recommended: Pixel 6).
3. Start emulator and wait for full boot.
4. Run app with Flutter:

```bash
export PATH="/Users/vivek/dev/flutter/bin:$PATH"
flutter run
```

## App State Preparation

Before capture:

1. Set app to **light mode**.
2. Generate deterministic sample data via **Settings → Generate test week** (debug).
3. Return to Home (today).
4. Confirm no transient overlays (toasts/dialogs) are visible.

## Capture Commands (Android)

Create output folder once:

```bash
mkdir -p /Users/vivek/dev/lila/docs/images/tutorial
```

Capture from emulator:

```bash
adb exec-out screencap -p > /Users/vivek/dev/lila/docs/images/tutorial/01-home.png
```

Repeat with each target filename after navigating to target screen.

## Capture Workflow

For each screenshot:

1. Navigate to the exact target screen/state.
2. Wait for animations to settle.
3. Run `adb exec-out screencap -p` to correct filename.
4. Open image and verify readability.
5. Re-capture immediately if needed.

## Quality Standards

- Same emulator/device for all screenshots.
- Same orientation (portrait).
- Same theme (light).
- No personal/sensitive content.
- Crisp text and visible primary actions.
- Keep one clear focus per screenshot.

## Markdown Integration

Reference images in tutorial markdown using relative links:

```md
![Home screen](docs/images/tutorial/01-home.png)
```

## Regeneration Process

When UI changes:

1. Boot same AVD.
2. Recreate app state (light mode + test week data).
3. Re-capture only impacted files with same names.
4. Check markdown preview for visual flow.

## Optional Next Step

Automate capture with a script (phase 2):
- `scripts/capture_android_tutorial_screenshots.sh`
- Start checks, output file checklist, and helper prompts for each shot.
