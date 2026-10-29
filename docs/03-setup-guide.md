# Setup guide (local development)

This gets the backend and the Flutter app running on your Mac against your Supabase project.

## 1. Prerequisites

| Tool | Version used | Check |
|---|---|---|
| Java (JDK) | 17 | `java -version` |
| Flutter | 3.44 | `flutter --version` |
| Android SDK / Xcode | SDK 36 / Xcode 26 | `flutter doctor` |

Gradle is downloaded by `./gradlew` automatically. Docker is **not** needed: backend tests start their own PostgreSQL 17.

## 2. Supabase: create the project in Mumbai (one-time, done by you)

Your existing project is in Ireland and Supabase cannot move a project between regions (see [decisions D5](02-decisions.md)), so create a new project:

1. **Create the project.**
   1. In the [Supabase dashboard](https://supabase.com/dashboard), click **New project**.
   2. Set **Region** to **South Asia (Mumbai)**. If Mumbai isn't listed, use **Southeast Asia (Singapore)**.
   3. Choose a strong **database password** and save it in your password manager.
2. **Check that sign-in tokens use the newer signing keys.** Go to **Project Settings → JWT Keys**. The current key should be an asymmetric key (ECC P-256 / ES256), which is what new projects get. If it says "Legacy JWT secret", migrate to the new signing keys. The backend only accepts ES256/RS256 tokens, verified through the project's JWKS endpoint.
3. **Set up email sign-in.** In **Authentication → Sign In / Providers**, keep **Email** enabled. Email confirmation is on by default: new users must click the link in the email before signing in.
4. **Copy the API values.** Go to **Project Settings → API Keys** and copy:
   - the **Project URL** (`https://<ref>.supabase.co`), for both the backend and the app;
   - the **publishable key** (`sb_publishable_…`), for the app only;
   - the **secret / service-role key**, *optional* and for the **backend only**. With it, "Delete account" also removes the sign-in. **Never put this key in the app.**
5. **Copy the database connection.** Click **Connect** (top of the dashboard) and copy the **Session pooler** connection. It works over IPv4. Convert it to JDBC:
   ```
   postgresql://postgres.<ref>:[PASSWORD]@aws-0-ap-south-1.pooler.supabase.com:5432/postgres
   → DB_URL=jdbc:postgresql://aws-0-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require
     DB_USERNAME=postgres.<ref>
     DB_PASSWORD=[PASSWORD]
   ```
   Use the host shown in your dashboard; the one above is only an example.
6. **Leave the Data API's exposed schemas as they are.** Under **Data API → Exposed schemas** the default is `public`; do not add `app`. All app data lives in the private `app` schema and is reachable only through the backend.

## 3. Backend

```bash
cd backend
cp .env.example .env      # then fill in DB_URL, DB_USERNAME, DB_PASSWORD, SUPABASE_URL
./gradlew bootRun
```

- On first start, Flyway creates the `app` schema and its tables.
- Health check: <http://localhost:8080/actuator/health> should return `{"status":"UP"}`.
- API docs (when `OMA_API_DOCS_ENABLED=true`): <http://localhost:8080/swagger-ui.html>.
- Run the tests (no database setup needed):

```bash
./gradlew test
```

### Least-privilege database login (recommended before production)

By default the app uses the `postgres` login. To give the running app only the rights it needs, run this in the Supabase **SQL editor** after the first start (Flyway must have created the tables):

```sql
create role oma_app login password 'CHOOSE-A-STRONG-PASSWORD';
grant usage on schema app to oma_app;
grant select, insert, update, delete on all tables in schema app to oma_app;
alter default privileges for role postgres in schema app
  grant select, insert, update, delete on tables to oma_app;
```

Then update `.env`:
- set `DB_USERNAME=oma_app.<ref>` and `DB_PASSWORD` to the new role;
- set `DB_MIGRATION_USERNAME=postgres.<ref>` and `DB_MIGRATION_PASSWORD` to the owner, so migrations keep working.

## 4. Mobile app

```bash
cd mobile
cp env.example.json env.json   # fill in SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY
flutter run --dart-define-from-file=env.json
```

Set `API_BASE_URL` in `env.json` according to where the app runs:

| Running on | `API_BASE_URL` |
|---|---|
| Android emulator | `http://10.0.2.2:8080` |
| iOS simulator | `http://localhost:8080` |
| Real phone on the same Wi-Fi | `http://<your Mac's LAN IP>:8080` |

Plain `http://` is allowed only for local development: any host in Android debug builds, only `localhost` in Android release builds (for `adb reverse`), and local networking on iOS. Production must use HTTPS.

### Release APK

Every build command needs the config file, otherwise the app opens on "App is not configured":

```bash
flutter build apk --release --dart-define-from-file=env.device.json
```

In VS Code, the task **Build release APK (phone)** runs this. To try it on a USB-connected phone against the backend on your Mac:

```bash
flutter install --release
```

```bash
adb reverse tcp:8080 tcp:8080
```

A release APK for other people needs a backend hosted on HTTPS (set `API_BASE_URL` to it) and your own signing key. For now it is signed with the debug key.

- Run the tests:

```bash
flutter test
```

## 5. Try the flow

1. Sign up in the app, confirm your email, then sign in.
2. **Recipients → +**: add a mobile number, e.g. `98765 43210`. It is saved as `+919876543210`.
3. **Home → New alert**: pick the recipient, choose WhatsApp, then:
   - **Now:** your SMS app opens with the message ready. Send it, return, and confirm "Yes, I sent it".
   - **In 15 min:** a reminder notification appears when it is due. Tap it to send, or cancel the alert if they replied.
4. **History** shows each alert and what is known about it.
