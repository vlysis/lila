# iOS Reminder TODOs

## Reminders v1 parity follow-up

- [ ] Add iOS local notification scheduling for one-time reminders.
- [ ] Request notification permissions on first reminder creation.
- [ ] Configure reminder notification with strong alert behavior (sound + high visibility).
- [ ] Add notification action to "Mark Done" directly from the notification.
- [ ] Ensure tapping the notification also marks the reminder as done.
- [ ] Handle app launch/resume from reminder notifications and sync done state to markdown files.
- [ ] Verify timezone-safe scheduling (today + later in week) with DST-safe date handling.
- [ ] Define iOS fallback when precise alarm-like timing is delayed by OS policies.
- [ ] Add tests for iOS notification callback handling and done-state persistence.
- [ ] Validate behavior on device for locked screen, background, and terminated app states.
