# Security notice (public share)

This repository is a **sanitized public snapshot**. The following were removed or replaced with placeholders:

| Item | Status |
|------|--------|
| Sentry DSN | Placeholder — set your own |
| Firebase `apiKey` / `google-services.json` / `GoogleService-Info.plist` | Placeholders — run FlutterFire |
| Naver Login `client_id` / `client_secret` | Placeholders in `strings.xml` + `Info.plist` |
| `assets/config/.env` / `.env.dev` | Example values only — copy from `.env.example` |
| Git history from private remotes | Not included (fresh history) |

Do **not** commit real production keys. Prefer local `.env` (gitignored) and CI secrets.
