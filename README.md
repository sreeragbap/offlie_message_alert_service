# Offline Message Alert Service

Lets a person alert someone by SMS when a message they sent on WhatsApp (or another app) seems to be unseen. The recipient does not need this app.

| Part | Tech | Folder |
|---|---|---|
| Mobile app (Android, iOS) | Flutter, Cubit, Dio, go_router | [`mobile/`](mobile) |
| Backend | Java 17, Spring Boot 4.1, Spring Security, JDBC, Flyway | [`backend/`](backend) |
| Database & sign-in | Supabase PostgreSQL + Supabase Auth (Mumbai region) | — |

## Documents
1. [Feasibility report & architecture](docs/01-feasibility-and-architecture.md): what each messaging platform allows
2. [Decisions log](docs/02-decisions.md): build order, India, SMS from the user's own phone, Supabase region
3. [Setup guide](docs/03-setup-guide.md): Supabase project, backend, mobile app

## Status

### Implemented (MVP, "Track A": user-triggered alerts)
- Sign-up / sign-in / password reset with Supabase Auth; the backend verifies tokens (JWKS, issuer, audience).
- Recipients: add, edit, remove; Indian numbers normalised to E.164; alerts on/off; "asked not to be alerted" opt-out; users can only see their own data.
- Alerts: now or delayed; idempotent creation (no duplicates on retry); per-recipient and per-day limits; cancel ("they replied"); history with paging.
- The SMS is sent **from the user's own phone** through the system SMS app, with the message filled in. There is no SMS gateway cost and no DLT registration. Reminder notifications fire when a delayed alert is due.
- Alert preferences: default delay, limits, message template with `{name}` and `{platform}`.
- Dashboard with service status and setup issues. A help screen with a per-platform capability matrix that never claims monitoring is active.
- Account deletion.
- Backend scheduler: device alerts become due and then expire. A server-SMS pipeline (claim with `SKIP LOCKED`, retry with backoff, `UNKNOWN` on ambiguous outcomes) is ready behind a provider-independent `SmsGateway`, but **switched off**.
- Tests: 52 backend tests (on a real PostgreSQL 17) and 17 Flutter tests.

### Proposed / not built yet
- **Track B: automatic WhatsApp Business delivery monitoring.** Needs a Meta Business account and a dedicated number ([D4](docs/02-decisions.md)).
- **Server-sent SMS** through a DLT-registered provider (e.g. MSG91). Needs a registered business entity plus DLT header and template registration.
- Production deployment (hosting in Mumbai/Singapore, HTTPS, monitoring), the deployment guide, push notifications, and more languages.

### Platform limitations (not fixable by this project)
- No app can monitor personal WhatsApp, Telegram, Messenger, Instagram or Signal chats. Delivery status exists only for business APIs.
- Android does not tell apps whether an SMS sent from the messaging app went out. The app records the user's confirmation, never delivery.
