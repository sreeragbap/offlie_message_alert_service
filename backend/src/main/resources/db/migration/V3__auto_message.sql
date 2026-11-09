-- Automatic WhatsApp message, set up once per recipient. The backend sends it on a schedule, or
-- once a minute after it is saved, through the Cloud API. The usual SMS alert follows when WhatsApp
-- does not report it delivered in time, so nobody has to send anything by hand.

create table app.auto_message (
    recipient_id      uuid primary key references app.recipient (id) on delete cascade,
    user_id           uuid not null references app.user_account (id) on delete cascade,
    enabled           boolean not null default true,
    -- Null: the default text. "{name}" is replaced with the recipient's name, "{sender}" with the user's.
    message_text      text check (char_length(message_text) between 1 and 1000),
    -- Null: send once, a minute after saving. Otherwise the local time to send on repeat_days.
    send_time         time,
    -- Bit 0 = Monday ... bit 6 = Sunday. Used only with send_time.
    repeat_days       smallint not null default 127 check (repeat_days between 1 and 127),
    time_zone         text not null default 'Asia/Kolkata',
    sms_after_minutes integer not null default 1 check (sms_after_minutes between 1 and 1440),
    -- Next time the scheduler sends it; null when nothing is pending (a one-off that already went).
    next_run_at       timestamptz,
    last_run_at       timestamptz,
    last_message_id   uuid references app.wa_message (id) on delete set null,
    last_error        text,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now()
);

create index auto_message_due_idx on app.auto_message (next_run_at) where enabled and next_run_at is not null;
create index auto_message_user_idx on app.auto_message (user_id);

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
