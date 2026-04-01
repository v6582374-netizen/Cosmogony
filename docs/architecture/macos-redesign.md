# Cosmogony macOS redesign

## Runtime split

- The desktop app owns all durable state, indexing, filtering, bridge auth, menu bar UI, and global shortcuts.
- The companion extension only captures page context and forwards it to the desktop app.
- Legacy MV3 background/content/options/manager code lives in `legacy/chrome-extension/` for migration reference only.

## Main UI

- Top bar: `全部 / X帖子 / 小红书 / 微信公众号 / 抖音 / YouTube / 其余网页`
- Secondary filters: `Inbox / Library / Trash`, search, timebox
- Body: clip list + detail/rules inspector
- Settings window: `Providers / Shortcuts / Capture / Storage`

## Storage rules

- `ClipItem.capturedAt` is the only timebox clock.
- `capturedHourBucket` is stored as the local hour floor to support 1h granularity queries.
- API keys never touch SQLite; only Keychain stores secrets.

## Bridge contract

- `POST /v1/handshake` issues a shared token to the extension.
- Capture endpoints require `X-Cosmogony-Token`.
- The bridge server only binds to `127.0.0.1`.

