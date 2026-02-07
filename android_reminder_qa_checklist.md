# Android Reminder QA Checklist

## Setup

- [ ] Install latest debug build on Android 13+ device.
- [ ] Ensure app notifications are initially allowed.
- [ ] Ensure exact alarms are initially allowed for the app.

## Create Reminder Flow

- [ ] Tap `Remind` on home screen.
- [ ] Enter text, pick day/time in future, choose each alarm offset option.
- [ ] Save and verify reminder card appears on selected day with reminder styling.
- [ ] Confirm invalid inputs block save:
  - [ ] Empty text
  - [ ] Reminder time in the past
  - [ ] Alarm offset that would place alarm in the past

## Notification Permission Cases

- [ ] Revoke notifications permission in system settings.
- [ ] Create reminder and verify save succeeds.
- [ ] Verify in-app warning appears about notification permission.
- [ ] Re-enable notifications and confirm next reminder posts normally.

## Exact Alarm Permission Cases

- [ ] Disable exact alarms for app in system settings (Android 12+).
- [ ] Create reminder and verify save succeeds.
- [ ] Verify in-app warning appears that reminders may be delayed.
- [ ] Re-enable exact alarms and verify no warning for next reminder.

## Alarm Delivery

- [ ] Create reminder for `+2 min` with `At time`.
- [ ] Lock screen and wait for notification.
- [ ] Verify alarm-style behavior:
  - [ ] High-visibility notification
  - [ ] Alarm sound
  - [ ] Vibration

## Notification Tap => Done

- [ ] Tap reminder notification while app is backgrounded.
- [ ] Verify app opens and reminder is marked done.
- [ ] Verify reminder card shows done state (subdued + done pill).
- [ ] Verify no duplicate rescheduling after done.

## App State Matrix

- [ ] Foreground: notification tap marks done.
- [ ] Background: notification tap marks done.
- [ ] Terminated: notification tap cold-starts app and marks done.

## Day Navigation + Timeline

- [ ] Confirm dates with only reminders are navigable.
- [ ] Confirm reminder appears in timeline with moments.
- [ ] Confirm reminder count appears in summary header.
- [ ] Confirm done reminders remain visible with done styling.

## Persistence

- [ ] Force close and reopen app.
- [ ] Verify reminders persist and statuses remain correct.
- [ ] Verify markdown exists under `Reminders/YYYY-MM-DD.md`.

## Regression Spot Checks

- [ ] `Log Moment` flow still works unchanged.
- [ ] Daily reflection save/log still works.
- [ ] Swipe day navigation still works without jitter/race.

## Optional Debug Commands

- [ ] `adb shell dumpsys alarm | grep lila` to inspect scheduled alarms.
- [ ] `adb shell dumpsys notification --noredact` to inspect posted reminder notification.
