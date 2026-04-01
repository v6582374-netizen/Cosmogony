# Legacy JSON import

The macOS app imports the JSON format exported by the old MuseMark manager:

```json
{
  "items": [...],
  "categoryRules": [...]
}
```

Compatibility rules:

- `url` or `canonicalUrl` is required.
- `createdAt`, `updatedAt`, and `lastSavedAt` are mapped into the new `capturedAt` using the newest available timestamp.
- Old statuses map as:
  - `trashed -> trashed`
  - `classified -> library`
  - `error -> failed`
  - everything else -> inbox
- `userNote -> note`
- `aiSummary -> aiSummary`
- `tags`, `category`, and category rules are preserved.

