# Decisions log

Decisions taken after the Phase 0 report ([01-feasibility-and-architecture.md](01-feasibility-and-architecture.md)).
Each entry records what was decided, why, and what it changes.

## D1 — Build order: user-triggered alert (Track A) first, WhatsApp Business (Track B) later
- **Decided:** 2026-10-29 (owner: "do the best as you wish").
- **Why:** Track A is the only legitimate way to serve personal chats on any platform. Track B needs a Meta Business account + dedicated number, which is not available yet (D4).
- **Effect:** MVP = Track A end-to-end. The integration layer is designed for Track B, but no WhatsApp code ships until D4 changes. The app shows WhatsApp Business monitoring as "not connected / requirements", never as working.

## D2 — Launch market: India only
- **Effect:** phone numbers default to region `IN` when parsing, stored as E.164 (`+91…`). UI copy in English first.

## D3 — SMS channel: send from the user's own phone/SIM via the system SMS composer
The owner asked whether alerts can be sent through the phone's own SIM instead of a paid provider. Findings:

| Option | Verdict | Reason |
|---|---|---|
| **Open the system SMS composer pre-filled; user taps Send** (Android `sms:` intent, iOS message composer) | ✅ **Chosen for MVP** | Works on Android and iOS; needs no SMS permission; message is person-to-person from the user's own number, so no DLT registration and no per-SMS cost to us; the recipient recognises the sender. |
| App sends SMS silently in the background with `SEND_SMS` | ❌ | Google Play allows SMS permissions only to apps that are the default SMS handler or that get a narrow exception ([Play policy](https://support.google.com/googleplay/android-developer/answer/10208820)). iOS has no API for this at all. |
| Use a phone with a SIM as a server-side SMS gateway for automated alerts | ❌ | That is commercial/A2P messaging from a 10-digit number. TRAI directs operators to stop commercial messages from unregistered senders using 10-digit numbers, with disconnection and blacklisting ([report](https://www.fonearena.com/blog/431632/trai-directs-telcos-to-blacklist-entities-misusing-connections-for-spam-calls.html/amp)). |
| DLT-registered provider (e.g. MSG91) | ⏳ Later | Needed only for server-originated SMS (Track B, or fully automatic alerts). Requires a registered business entity, header and template registration on a DLT portal. |

**Consequences:**
- An alert is a record the backend schedules and tracks; when it is due, the **phone** sends it after the user confirms. Delayed alerts ("remind me in 30 min unless they reply") use a local notification on the device at `due_at`.
- The backend keeps a provider-independent `SmsGateway` interface for future server-side sending; it is **off** by default (`oma.sms.server-channel-enabled=false`) and only a logging implementation exists.
- Because the SMS comes from the user's own number, there is no anonymous messaging and the separate recipient opt-in SMS is not needed for MVP. Recipient-level "stop alerts" is still enforced.
- History honestly records `SENT_FROM_DEVICE` = "user confirmed the composer was opened for sending". On Android the system does not report whether the SMS was actually sent, so the app never claims delivery.

## D4 — No Meta Business account / spare number
- Track B is postponed. Revisit when an account and a number not used on consumer WhatsApp are available.

## D5 — Database: Supabase PostgreSQL in Asia
- The existing project is in **Ireland (eu-west-1)**. Supabase cannot move a project between regions; the documented path is to create a new project in the target region and migrate ([Supabase: change project region](https://supabase.com/docs/guides/troubleshooting/change-project-region-eWJo5Z)).
- **Action for the owner:** create a new Supabase project in **South Asia (Mumbai)**, or Singapore if Mumbai is not offered, and put its connection details in `backend/.env` (see the setup guide). Nothing of this project lives in the Ireland project, so there is nothing to migrate.
- Backend hosting will be chosen at M7 in the same region (e.g. Mumbai/Singapore).

## D6 — Data access: Spring `JdbcClient` + Flyway, not JPA
- Explicit SQL makes the queue (`FOR UPDATE SKIP LOCKED`), unique-constraint idempotency and conditional state transitions obvious and testable. No ORM-generated DDL.

## D7 — Schema lives in a private `app` schema
- Supabase's Data API exposes only configured schemas (default `public`). Tables live in `app`, and `anon`/`authenticated` get no privileges on it, so the mobile app's publishable key can never read data directly. All data access goes through Spring Boot.

## D8 — Tests use embedded PostgreSQL (no Docker on the dev machine)
- Integration tests run against a real PostgreSQL 17 started in-process (zonky embedded-postgres), so SQL, constraints and locking are tested on the real engine.
