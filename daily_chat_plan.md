# Daily Reflection Companion - Implementation Plan

## Feature Overview

Add a "Discuss your day" chat interface to the daily reflection screen that allows users to have a conversation with Claude about their logged moments and reflections. Only visible when Claude integration is enabled.

---

## Files to Modify/Create

| File | Action | Purpose |
|------|--------|---------|
| `lib/screens/daily_reflection_screen.dart` | Modify | Add "Discuss your day" button, conditionally rendered |
| `lib/widgets/day_discussion_sheet.dart` | Create | Bottom sheet with chat interface |
| `lib/services/claude_api_client.dart` | Modify | Add conversation support (message history) |
| `lib/services/file_service.dart` | Modify | Add read/write methods for `## Discussion` section |
| `test/widgets/day_discussion_sheet_test.dart` | Create | Tests for chat UI |

---

## UI Design

### 1. Entry Point (in daily_reflection_screen.dart)

Add a "Discuss your day" button after the Log button, only when Claude is enabled:

```
[existing content...]
[Log button]
[SizedBox(height: 24)]

if (claudeEnabled) {
  [Discuss your day button]
  - Outlined style (not filled like Log button)
  - Icon: Icons.chat_bubble_outline
  - Text: "Discuss your day"
  - Opens DayDiscussionSheet as modal bottom sheet
}
```

### 2. Chat Interface (DayDiscussionSheet)

**Layout:**
```
DraggableScrollableSheet (0.6 → 0.95 height)
├─ Handle bar (drag indicator)
├─ Header: "Discuss your day" + close button
├─ Messages ListView (expanded, reverse: true)
│   ├─ Claude messages (left-aligned, sage green bg)
│   └─ User messages (right-aligned, darker bg)
└─ Input area (TextField + send button)
```

**Message bubble styling:**
- Reuse the card pattern from daily reflection (rounded corners, subtle bg)
- Claude: left-aligned, `Color(0xFF6B8F71).withOpacity(0.15)` (sage)
- User: right-aligned, `Colors.white.withOpacity(0.08)`
- Max width: 85% of container
- Padding: 12px horizontal, 10px vertical

**Initial state:**
- Empty chat — user speaks first
- Placeholder text in input: "What's on your mind?"
- Previous conversation loaded from `## Discussion` section if it exists

---

## Data Flow

### Context Passed to Claude

Build a system prompt that includes:
1. Today's date
2. List of entries with time, mode, orientation, label
3. User's reflection text (if any)
4. Lila's design philosophy (observational, not prescriptive)

**System prompt template:**
```
You are a gentle, observational companion in Lila, a mindful activity logger.
The user is reflecting on their day. Be curious and supportive, never prescriptive
or productivity-focused. Drift is not negative. All modes have equal value.

Today is {date}.

The user logged these moments:
{entries formatted as list}

Their reflection so far: "{reflection_text}"

Ask thoughtful questions. Make gentle observations. Keep responses concise (2-3 sentences).
```

### Message History & Persistence

- Persist conversation to daily markdown under `## Discussion` section
- Format in markdown:
  ```markdown
  ## Discussion

  **User:** How did my afternoon feel?

  **Claude:** You had a cluster of growth moments between 2-4pm...
  ```
- Load existing discussion when sheet opens
- Auto-save after each Claude response (debounced)
- `## Discussion` placed after `## Reflection` in daily file
- Each message: `{role: 'user'|'assistant', content: String}`
- Send full history with each request for context

---

## Implementation Steps

### Step 1: Add FileService methods for Discussion section
- `Future<String?> readDiscussion(DateTime date)` — returns discussion markdown or null
- `Future<void> saveDiscussion(DateTime date, String markdown)` — saves under `## Discussion`
- Discussion section placed after `## Reflection` (last in file)

### Step 2: Add Claude check to daily_reflection_screen.dart
- Import ClaudeService
- Load `isEnabled` state in `initState`
- Add conditional "Discuss your day" button

### Step 3: Create DayDiscussionSheet widget
- Stateful widget receiving `date`, `entries`, `reflectionText`
- Load existing discussion on open
- Empty initial state — user types first
- Message list with scroll controller
- Input field with send button
- Loading state while Claude responds

### Step 4: Integrate with ClaudeApiClient
- Build system prompt from day's data
- Send messages with conversation history
- Handle errors gracefully (show inline error, allow retry)
- Track token usage
- Auto-save discussion after each response

### Step 5: Polish
- Auto-scroll to new messages
- Keyboard handling (adjust for input)
- Dismiss keyboard on scroll
- Loading indicator while Claude thinks

---

## Error Handling

| Error | UI Response |
|-------|-------------|
| `integrationPaused` | Don't show button at all |
| `dailyCapReached` | Show message: "Daily limit reached" |
| `networkOffline` | Show message: "No connection" with retry |
| `keyInvalid` | Show message: "API key issue" + link to settings |
| `timeout` | Show message: "Taking too long" with retry |

---

## Testing

1. **Unit tests for FileService discussion methods:**
   - `readDiscussion` returns null when no discussion exists
   - `readDiscussion` parses existing discussion correctly
   - `saveDiscussion` creates section if not exists
   - `saveDiscussion` updates existing section
   - Discussion section placed after Reflection section

2. **Unit tests for DayDiscussionSheet:**
   - Opens with empty chat when no prior discussion
   - Loads existing discussion on open
   - User can type and send message
   - Messages appear in correct order
   - Loading state shows while waiting
   - Error states display correctly
   - Discussion persists after send

3. **Integration test:**
   - Button only appears when Claude enabled
   - Chat opens with day context
   - Messages round-trip correctly
   - Discussion survives close/reopen

---

## Verification

1. Run `flutter analyze` - no errors
2. Run `flutter test` - all tests pass
3. Manual test flow:
   - Log a few entries for today
   - Write some reflection text
   - Enable Claude integration in Settings (need valid API key)
   - Open daily reflection for today
   - Tap "Discuss your day"
   - Verify chat opens empty (user speaks first)
   - Type a message, send it
   - Verify Claude response appears
   - Close the sheet, reopen — verify conversation persisted
   - Check `Daily/YYYY-MM-DD.md` file has `## Discussion` section
   - Check token usage updates in Settings
