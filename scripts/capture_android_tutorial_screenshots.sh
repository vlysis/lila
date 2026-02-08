#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../lila_screenshots"
ADB_BIN="${ADB_BIN:-adb}"

shots=(
  "01-home.png|Home (today)"
  "02-log-mode.png|Log Moment sheet (mode step)"
  "03-log-orientation-duration.png|Log Moment orientation/duration step"
  "04-reminder-sheet.png|Reminder creation sheet"
  "05-past-day-navigation.png|Past day view with return-to-today"
  "06-weekly-review.png|Weekly review screen"
  "07-balance-garden.png|Balance garden screen"
  "08-trash.png|Trash screen"
  "09-settings.png|Settings screen"
)

usage() {
  cat <<'USAGE'
Usage: capture_android_tutorial_screenshots.sh [--output-dir DIR] [--device SERIAL]

Interactive workflow:
- Navigate app on emulator/device to each requested screen.
- Press Enter to capture screenshot when prompted.
- Choose recapture/continue/quit after each shot.

Options:
  --output-dir DIR   Directory to save screenshots (default: ../lila_screenshots)
  --device SERIAL    adb device serial to target (default: first online device)
  -h, --help         Show this help
USAGE
}

DEVICE_SERIAL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --device)
      DEVICE_SERIAL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

if ! command -v "$ADB_BIN" >/dev/null 2>&1; then
  echo "Error: adb not found. Install Android platform-tools or set ADB_BIN." >&2
  exit 1
fi

adb_cmd() {
  if [[ -n "$DEVICE_SERIAL" ]]; then
    "$ADB_BIN" -s "$DEVICE_SERIAL" "$@"
  else
    "$ADB_BIN" "$@"
  fi
}

if [[ -z "$DEVICE_SERIAL" ]]; then
  mapfile -t online_devices < <("$ADB_BIN" devices | awk 'NR>1 && $2=="device" {print $1}')
  if [[ ${#online_devices[@]} -eq 0 ]]; then
    echo "Error: no online adb devices found. Start an emulator first." >&2
    exit 1
  fi
  DEVICE_SERIAL="${online_devices[0]}"
fi

if ! "$ADB_BIN" -s "$DEVICE_SERIAL" get-state >/dev/null 2>&1; then
  echo "Error: device '$DEVICE_SERIAL' is not reachable via adb." >&2
  exit 1
fi

boot_complete="$($ADB_BIN -s "$DEVICE_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
if [[ "$boot_complete" != "1" ]]; then
  echo "Error: device '$DEVICE_SERIAL' is not fully booted (sys.boot_completed=$boot_complete)." >&2
  exit 1
fi

echo "Using device: $DEVICE_SERIAL"
echo "Output directory: $OUTPUT_DIR"
echo
echo "Before starting, ensure in app:"
echo "- Light mode enabled"
echo "- Test week data generated"
echo "- You are ready on Home screen"
echo
read -r -p "Press Enter to start capture sequence..."

capture() {
  local path="$1"
  adb_cmd exec-out screencap -p > "$path"
  if [[ ! -s "$path" ]]; then
    echo "Capture failed: $path is empty." >&2
    return 1
  fi
}

for item in "${shots[@]}"; do
  file="${item%%|*}"
  label="${item#*|}"
  target="$OUTPUT_DIR/$file"

  echo
  echo "Next: $file"
  echo "Screen: $label"
  read -r -p "Navigate now, then press Enter to capture..."

  capture "$target"
  echo "Saved: $target"

  while true; do
    read -r -p "Action: [c]ontinue, [r]ecapture, [q]uit: " action
    case "${action:-c}" in
      c|C)
        break
        ;;
      r|R)
        capture "$target"
        echo "Re-saved: $target"
        ;;
      q|Q)
        echo "Stopped early by user."
        exit 0
        ;;
      *)
        echo "Invalid option. Use c/r/q."
        ;;
    esac
  done
done

echo
echo "Done. Captured files:"
for item in "${shots[@]}"; do
  file="${item%%|*}"
  target="$OUTPUT_DIR/$file"
  if [[ -f "$target" ]]; then
    echo "- $target"
  else
    echo "- MISSING: $target"
  fi
done
