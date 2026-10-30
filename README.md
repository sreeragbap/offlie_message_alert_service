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
4. [WhatsApp + relay phone setup](docs/04-whatsapp-setup.md): automatic alerts (Track B)

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
- Tests: 80 backend tests (on a real PostgreSQL 17) and 24 Flutter tests.

### Implemented ("Track B": automatic alerts, needs setup)
- **WhatsApp tab:** send messages from a WhatsApp Business number through the Cloud API, with delivery ticks from Meta's signed webhooks. A template is used when the 24-hour window is closed; replies are shown.
- **Automatic SMS:** if WhatsApp has not reported delivery after the chosen time (or the message failed), an SMS alert becomes due. Delivery or a reply cancels it.
- **Relay phone (Android):** sends due SMS automatically from its own SIM. Leases, retries and "unknown" handling mean no duplicate SMS. Home shows when it is offline.
- It works once a Meta app, the webhook and a relay phone are set up ([guide](docs/04-whatsapp-setup.md)). It covers only messages sent from the app's WhatsApp tab, not your personal WhatsApp ([D9–D11](docs/02-decisions.md)).

### Proposed / not built yet
- **Server-sent SMS** through a DLT-registered provider (e.g. MSG91). Needs a registered business entity plus DLT header and template registration.
- Production deployment (hosting in Mumbai/Singapore with a fixed HTTPS address instead of the temporary tunnel, monitoring), the deployment guide, push notifications, and more languages.
- Relay mode as a background service, so the relay screen need not stay open.

### Platform limitations (not fixable by this project)
- No app can monitor personal WhatsApp, Telegram, Messenger, Instagram or Signal chats. Delivery status exists only for business APIs.
- Android does not tell apps whether an SMS sent from the messaging app went out. The app records the user's confirmation, never delivery.
