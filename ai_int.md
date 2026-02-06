
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
