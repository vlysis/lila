# Lila Tutorial

Welcome to Lila, a mindful activity logger that helps you notice how your time feels. Lila captures each moment with two lenses:

- **Mode**: the kind of energy you are in (nourishment, growth, maintenance, drift)
- **Orientation**: who the moment is directed toward (self, mutual, other)

Everything is saved as simple Markdown files that work well with Obsidian.

## Quick Start

1. Tap the large **+** button on the home screen.
2. Choose a **Mode**.
3. Choose an **Orientation**.
4. (Optional) Choose a **Duration** preset.
5. (Optional) Add a short label.
6. Tap **Log** to save the moment.

Your moment appears in today’s list and is written to the daily Markdown file.

## Modes

Modes describe the feel or role of the moment:

- **Nourishment**: restoring, easing, recharging
- **Growth**: learning, effort, building
- **Maintenance**: keeping things running, the basics
- **Drift**: unfocused, wandering, looping

## Orientation

Orientation describes who the moment is for:

- **Self**: mostly for you
- **Mutual**: shared with someone or a group
- **Other**: primarily in service of someone else

## Duration (Optional)

Each mode has its own set of duration presets. Pick one if it helps capture the feel of time. If you skip this step, the entry is still valid and saved without a duration.

## Labels (Optional)

Add a short label to help you remember the moment. Examples:

- “Reading”
- “Budget check”
- “Call with Sam”

Labels show up in the daily list and make your log easier to scan later.

## Daily Reflection

The daily reflection screen lets you review the day and write a short note.

How to open it:

- Tap the **edit** icon in the home AppBar, or
- Tap the prompt on the home screen.

What you’ll see:

- A date header
- A day summary
- Your logged moments
- A reflection text box

The reflection is saved to `Daily/YYYY-MM-DD.md` under `## Reflection`.

## Weekly Review

Tap the week icon in the home AppBar to open the weekly review. It includes:

- Weekly whisper (single-line observation)
- Week texture (mode-colored dots per day)
- Orientation threads (colored bars)
- Daily rhythm (time-of-day heatmap)
- Insights (short, observational cards)
- Weekly reflection text area

The weekly reflection is saved to `Weekly/YYYY-Www.md`.

## Trash (Soft Delete)

Swipe a moment left to reveal **Delete**. This moves it to **Trash** instead of removing it immediately.

Open Trash:

- Tap the trash icon on the top left of the home screen.

Inside Trash:

- Swipe right to **Restore**
- Swipe left to **Delete permanently**

Trash entries are stored in `Trash/YYYY-MM-DD.md`.

## Intention / Theme

Open the Intention screen from the home focus card to pick a season:

- **Builder**
- **Sanctuary**
- **Explorer** (default)
- **Grounded**

Each season changes the visual theme and sets a tone for your logging. Selecting a season applies it immediately.

## Settings and Vault Location

By default, Lila stores files in:

```
<app documents>/Lila/
```

You can change the vault path in **Settings**. Lila will create the needed folders at the new location but will not move existing data.

## AI & Integrations (Optional)

Lila supports optional Claude integration in Settings. You can enter a key, choose a model, and set a daily usage cap. This is off by default and is not required to use the app.

## File Locations

Lila writes simple Markdown files:

- `Daily/YYYY-MM-DD.md`
- `Weekly/YYYY-Www.md`
- `Meta/modes.md`
- `Trash/YYYY-MM-DD.md`

These files are Obsidian-compatible and can be read or edited outside the app if needed.

---

If you want a shorter version of this tutorial for onboarding, or screenshots with callouts, tell me and I will draft them.
