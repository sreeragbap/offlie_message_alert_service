# WhatsApp Business + relay phone setup (Track B)

With this set up, sending a WhatsApp message and alerting by SMS is automatic:

1. In the app's **WhatsApp** tab you send a message. It goes out from your WhatsApp Business number through Meta's Cloud API.
2. WhatsApp reports `sent`, `delivered` and `read` to the backend (webhook).
3. If **delivered** has not arrived after the time you chose (e.g. 15 min), their phone is offline. The alert becomes due.
4. Your **relay phone**, an Android phone with a SIM running the app in relay mode, sends the SMS from its own number automatically.
5. If WhatsApp reports delivery first, or the person replies, the SMS is cancelled.

What it cannot do: watch chats in your personal WhatsApp app. Only messages sent from the app's WhatsApp tab are tracked (see [D9](02-decisions.md)).

## 1. Meta app and test number (you, about 15 minutes)

1. Go to <https://developers.facebook.com/apps> and sign in with Facebook. Click **Create app**.
   - Use case: **Connect with customers through WhatsApp**. Select or create a business portfolio when asked.
2. Open **WhatsApp → API Setup** in the app. Meta gives you a free **test number**.
   - Copy the **Phone number ID** (not the phone number itself).
   - Under **To**, add up to 5 phone numbers that may receive test messages. Each gets a code on WhatsApp to confirm. Add the people you will test with.
   - Click **Generate access token**. This token lasts 24 hours. For longer use, see step 5.
3. Open **App settings → Basic** and copy the **App secret** (click Show).
4. Put the values in `backend/.env`. Never in the app or in git:
   ```
   WHATSAPP_PHONE_NUMBER_ID=<Phone number ID>
   WHATSAPP_ACCESS_TOKEN=<access token>
   WHATSAPP_APP_SECRET=<App secret>
   ```
   `WHATSAPP_VERIFY_TOKEN` is already filled with a random value; you will paste it into Meta in step 2 below.
   Restart the backend after editing `.env`.
5. **Long-lived token (when the test works):** in [Business settings](https://business.facebook.com/settings) → **Users → System users**, add a system user (Admin) and assign your app and WhatsApp account. Then **Generate token** with the permissions `whatsapp_business_messaging` and `whatsapp_business_management`, and replace `WHATSAPP_ACCESS_TOKEN`.

## 2. Webhook: let WhatsApp report delivery to the backend

WhatsApp needs a public HTTPS address. While the backend runs on your Mac, a Cloudflare tunnel provides it:

```bash
cloudflared tunnel --no-autoupdate --url http://localhost:8080
```

It prints an address like `https://<random-words>.trycloudflare.com`. This address changes every time the tunnel restarts, so repeat the Meta step below after each restart. A fixed address needs hosting or a named Cloudflare tunnel (later).

In the Meta app, open **WhatsApp → Configuration → Webhook → Edit**:
- **Callback URL:** `https://<random-words>.trycloudflare.com/webhooks/whatsapp`
- **Verify token:** the `WHATSAPP_VERIFY_TOKEN` value from `backend/.env`

Click **Verify and save**. The backend must be running. Then under **Webhook fields**, **Subscribe** to `messages`.

The backend accepts webhook calls only when they are signed with your App secret.

## 3. First messages and templates

WhatsApp lets a business send free text only within **24 hours of the person's last message to the business number**. Otherwise it must use an approved **template**. The backend picks automatically:
- The person has not written to you in 24 hours: the template from `WHATSAPP_TEMPLATE_NAME` is sent.
- They have written in the last 24 hours: your own text is sent.

The test setup uses Meta's pre-approved `hello_world` template. The person receives Meta's "Hello World" text, not your message, but **delivery tracking and the SMS alert work the same**. Once they reply, your own texts go through.

To send your own words as the first message, create a template in **WhatsApp Manager → Message templates**:
- Category **Utility**, language e.g. **English**.
- Body, for example: `{{1}} sent you a message: {{2}}` (variables cannot be the whole message).

After Meta approves it, set:
```
WHATSAPP_TEMPLATE_NAME=<template name>
WHATSAPP_TEMPLATE_LANGUAGE=en
WHATSAPP_TEMPLATE_PARAMS=sender,text
```
`sender` is your name from the app's Settings, `text` is the message you typed, and `name` is the recipient's name.

## 4. Relay phone

Use an Android phone with an **active SIM** that can send SMS. It can be your own phone or a spare one.

1. Install the app and sign in with **the same account** you send WhatsApp messages from. To make the app reach the backend from any network, build it against the tunnel address. Make `mobile/env.tunnel.json` (git-ignored) with `"API_BASE_URL": "https://<random-words>.trycloudflare.com"`, then run:
   ```bash
   flutter build apk --release --dart-define-from-file=env.tunnel.json
   ```
   In VS Code, the task **Build release APK (tunnel)** does the same. Rebuild when the tunnel address changes.
2. Open **Settings → Relay phone → Start relay** and allow the SMS permission.
3. Keep that screen open, the phone charging and online. The screen stays on by itself.

The Home screen shows "Your relay phone is offline" when it has not checked in for 2 minutes. An alert that waits more than 24 hours for the relay phone expires instead of being sent late.

SMS from the relay phone are normal person-to-person SMS from its number. They are fine for personal use at low volume. Sending many automated messages from a personal SIM is not allowed in India (TRAI); use a DLT-registered provider for that (see [D3](02-decisions.md)).

## 5. Try it

1. In the app's **Recipients**, add a test number you allowed in step 1.2.
2. In **WhatsApp → New message**, send something with **SMS alert after 5 min**.
3. Either:
   - leave the recipient's phone **online**: the ticks go to delivered, and the alert says "SMS alert not needed: Delivered on WhatsApp"; or
   - first turn **mobile data and Wi-Fi off** on the recipient's phone, keeping the phone on. WhatsApp cannot deliver, so after 5 minutes the relay phone sends the SMS and it arrives right away. In airplane mode the SMS would also wait until the phone is back on the network.

## Costs (India, approximate, check Meta's rate card)

- Template messages (utility): about ₹0.12 each. Free text within 24 hours of their reply: free.
- SMS: your relay SIM's plan.
