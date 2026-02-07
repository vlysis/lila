# Lila User Tutorial

Lila is a mindful activity logger that helps you capture short “Mode × Orientation” moments and reflections in local Markdown files.

## 1) Getting Started

When you open Lila, you land on the **Home** screen for today.

Main actions on Home:
- **Log Moment**: add a new activity moment
- **Set Alarm**: add a one-time reminder
- **Reflection box**: write how the day feels
- **Top icons**: open Trash, Weekly Review, Garden, and Settings

Lila stores everything locally as Markdown in your vault.

## 2) Understand the Core Model

Each moment has:
- **Mode**: nourishment, growth, maintenance, drift, decay
- **Orientation**: self, mutual, other
- Optional **Duration**
- Optional **Label** (e.g., “Reading”, “Lunch walk”)

Think of it as: “What kind of energy was this?” + “Who was it oriented toward?”

## 3) Log Your First Moment

1. Tap **Log Moment**.
2. Choose a **Mode**.
3. Choose an **Orientation**.
4. Optionally choose a **Duration**.
5. Optionally enter a **label**.
6. Save.

The entry is written to today’s Markdown file in `Daily/YYYY-MM-DD.md`.

Tip:
- Keep labels short and specific (“Planning”, “Coffee with Sam”, “Inbox cleanup”).

## 4) Use Daily Reflection

On Home, below your timeline, you’ll see a reflection prompt.

Prompt changes by time of day:
- Before 12:00: **“What do you want from today?”**
- 12:00–17:59: **“How is today unfolding?”**
- 18:00+: **“How did today feel?”**

How it works:
- Type in the reflection box.
- Lila auto-saves with debounce.
- Reflection is stored under `## Reflection` in that day’s file.

You can also tap **Log Reflection** to create a timeline entry tagged as a daily reflection.

## 5) Add and Complete Reminders

To create a reminder:
1. Tap **Set Alarm**.
2. Enter reminder text.
3. Pick day and time.
4. Pick alert timing (at time or offset).
5. Save.

What happens:
- Reminder is saved to `Reminders/YYYY-MM-DD.md`.
- It appears in the day timeline with reminder styling.
- Tap a reminder card to mark it done.

On Android, reminder notifications can route back into Lila and mark reminders complete.

## 6) Navigate Between Days

Lila supports horizontal day swiping on Home.

- **Swipe right**: go to previous day
- **Swipe left**: move forward toward today

Notes:
- You can navigate across dates that have data (plus today).
- Past days are editable: you can still log moments and edit reflections.
- Focus card is hidden on past days.
- A “Return to today” link appears when viewing old dates.

## 7) Weekly Review

Tap the **week icon** in the Home app bar to open Weekly Review.

You’ll see:
1. Weekly whisper (short observation)
2. Week texture (mode pebbles)
3. Orientation threads
4. Daily rhythm heatmap
5. Insight cards
6. Weekly reflection input

Write your weekly reflection in that screen; it auto-saves to `Weekly/YYYY-Www.md`.

## 8) Balance Garden

Tap the **garden icon** to open Balance Garden.

This view gives local-only visual summaries:
- Tone summary
- Mode pebbles
- Orientation threads
- Word blooms (from reflections/tags)
- 7-day tone trend

No cloud analysis is required for this screen.

## 9) Trash and Restore

Tap the **trash icon** on Home to open Trash.

For trashed moments:
- Swipe right: restore to original day
- Swipe left: permanently delete

Trash data is stored in `Trash/YYYY-MM-DD.md` until you delete it.

## 10) Settings You Should Know

Open **Settings** to manage:
- Vault location (default or custom folder)
- Backup/restore of full vault
- Theme (light/dark)
- Model selector (Haiku/Sonnet/Opus, if enabled)
- Usage and daily token limit (if enabled)

Vault path behavior:
- Changing path affects future reads/writes.
- Existing vault data is not moved automatically.

## 11) Recommended Daily Workflow

A simple pattern:
1. Morning: write intention in reflection prompt.
2. During day: log moments quickly with short labels.
3. Add reminders for time-bound tasks.
4. Evening: update reflection in a few lines.
5. End of week: review patterns and add weekly reflection.

## 12) Where Your Data Lives

Default structure:

```text
Lila/
  Daily/
  Weekly/
  Reminders/
  Trash/
  Meta/
  Activities/
```

Everything is plain Markdown, so you can read it directly in Obsidian or any text editor.

---

If you want, a next step is to create a short in-app onboarding checklist from this tutorial.
