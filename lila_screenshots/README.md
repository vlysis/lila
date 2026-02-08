# Lila Android Tutorial Screenshots

This folder is the default output target for the Android capture script.

## Expected Files

1. `01-home.png`
2. `02-log-mode.png`
3. `03-log-orientation-duration.png`
4. `04-reminder-sheet.png`
5. `05-past-day-navigation.png`
6. `06-weekly-review.png`
7. `07-balance-garden.png`
8. `08-trash.png`
9. `09-settings.png`

## Run

```bash
bash /Users/vivek/dev/lila/scripts/capture_android_tutorial_screenshots.sh
```

To save to your requested external folder (`../lila_screenshots`), run:

```bash
bash /Users/vivek/dev/lila/scripts/capture_android_tutorial_screenshots.sh --output-dir /Users/vivek/dev/lila_screenshots
```

## Preconditions

- Android emulator booted and visible in `adb devices`
- Lila app running in emulator
- Light mode selected
- Test week data generated from app settings
