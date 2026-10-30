-- Track B: WhatsApp messages sent through the WhatsApp Business Platform (Cloud API), with an
-- automatic SMS alert when WhatsApp does not report delivery in time. The SMS goes out from the
-- user's relay phone (channel RELAY_SMS).

alter table app.alert drop constraint alert_channel_check;
alter table app.alert add constraint alert_channel_check
    check (channel in ('DEVICE_SMS', 'SERVER_SMS', 'RELAY_SMS'));

create index alert_relay_due_idx on app.alert (user_id, due_at) where channel = 'RELAY_SMS' and state = 'DUE';

-- Last time the user's relay phone asked for work; shown on the dashboard.
alter table app.user_account add column relay_last_seen_at timestamptz;

-- Last message the recipient sent to the business number. Free-form messages are allowed for
-- 24 hours after it; otherwise WhatsApp requires an approved template.
alter table app.recipient add column wa_last_inbound_at timestamptz;

create table app.wa_message (
    id                uuid primary key default gen_random_uuid(),
    user_id           uuid not null references app.user_account (id) on delete cascade,
    recipient_id      uuid references app.recipient (id) on delete set null,
    direction         text not null check (direction in ('OUT', 'IN')),
    -- Outgoing only: makes retried sends idempotent.
    client_request_id uuid,
    kind              text not null check (kind in ('TEXT', 'TEMPLATE', 'OTHER')),
    body              text check (char_length(body) <= 4096),
    -- WhatsApp's message id ("wamid..."), set once the Cloud API accepts the message.
    wamid             text,
    status            text not null check (status in (
                          'PENDING', 'ACCEPTED', 'SENT', 'DELIVERED', 'READ', 'FAILED', 'UNKNOWN', 'RECEIVED')),
    error_code        text,
    error_message     text,
    -- The SMS alert that fires if this message is not delivered in time.
    alert_id          uuid references app.alert (id) on delete set null,
    -- Why no SMS alert was scheduled (e.g. the recipient's daily limit was reached).
    alert_skipped     text,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    sent_at           timestamptz,
    delivered_at      timestamptz,
    read_at           timestamptz,
    check ((direction = 'OUT') = (client_request_id is not null))
);

create unique index wa_message_request_uq on app.wa_message (user_id, client_request_id)
    where client_request_id is not null;
-- An inbound message is stored once per user who has the sender as a recipient.
create unique index wa_message_wamid_uq on app.wa_message (user_id, wamid) where wamid is not null;
create index wa_message_wamid_idx on app.wa_message (wamid) where wamid is not null;
create index wa_message_user_created_idx on app.wa_message (user_id, created_at desc);

-- Every status webhook as received. Statuses can arrive before we have stored the wamid of a
-- message we just sent; they are applied when it is stored.
create table app.wa_status_event (
    id          bigint generated always as identity primary key,
    wamid       text not null,
    status      text not null,
    occurred_at timestamptz not null,
    error_code  text,
    error_title text,
    received_at timestamptz not null default now()
);

create index wa_status_event_wamid_idx on app.wa_status_event (wamid);

do $$
begin
    if exists (select 1 from pg_roles where rolname = 'anon') then
        execute 'revoke all on all tables in schema app from anon';
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
        execute 'revoke all on all tables in schema app from authenticated';
    end if;
end
$$;
