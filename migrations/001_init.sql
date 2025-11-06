-- init.sql
-- Messaging Service: schema initialization

BEGIN;

-- Extensions
CREATE EXTENSION IF NOT EXISTS citext;

-- Enums
CREATE TYPE channel AS ENUM ('sms', 'mms', 'email');
CREATE TYPE endpoint_kind AS ENUM ('email', 'phone', 'cross');
CREATE TYPE phone_channel AS ENUM ('sms', 'mms');
CREATE TYPE inbound_or_outbound AS ENUM ('inbound', 'outbound');
CREATE TYPE status AS ENUM ('outbox', 'retry', 'ok', 'failed');

-- Updated-at trigger function
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Conversations
CREATE TABLE IF NOT EXISTS conversations (
  id BIGSERIAL PRIMARY KEY,
  endpoint_kind endpoint_kind NOT NULL,
  phone_channel phone_channel,
  endpoint_source TEXT NOT NULL,
  endpoint_target TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER conversations_on_update
BEFORE UPDATE ON conversations
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Messages
CREATE TABLE IF NOT EXISTS messages (
    id BIGSERIAL PRIMARY KEY,
    conversation_id BIGSERIAL NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    endpoint_source TEXT NOT NULL,
    endpoint_target TEXT NOT NULL,
    provider_id TEXT,
    provider_message_id TEXT,
    inbound_or_outbound inbound_or_outbound NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL,
    endpoint_kind endpoint_kind NOT NULL,
    phone_channel phone_channel,
    body TEXT NOT NULL,
    attachments JSONB,
    status_tag status NOT NULL,
    status_payload TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider_id, provider_message_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS ix_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS ix_messages_timestamp ON messages("sent_at");
CREATE INDEX IF NOT EXISTS ix_messages_status_unprocessed ON messages(status_tag) WHERE status_tag = 'outbox' OR status_tag = 'retry' ;

CREATE TRIGGER messages_on_update
BEFORE UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Schema migrations history
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT now()
);

COMMIT;
