-- init.sql
-- Messaging Service: schema initialization

BEGIN;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS citext;

-- Enums
CREATE TYPE channel AS ENUM ('sms', 'mms', 'email');
CREATE TYPE inbound_or_outbound AS ENUM ('inbound', 'outbound');
CREATE TYPE status AS ENUM ('unprocessed', 'processed');

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
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  channel channel NOT NULL,
  participants TEXT NOT NULL,
  topic TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enforce: topic only allowed when channel = 'email'
ALTER TABLE conversations
  ADD CONSTRAINT conversations_topic_email_only
  CHECK (topic IS NULL OR channel = 'email');

-- Helpful for querying email threads by subject/topic
CREATE INDEX IF NOT EXISTS ix_conversations_email_topic
  ON conversations(topic)
  WHERE channel = 'email' AND topic IS NOT NULL;

CREATE TRIGGER conversations_on_update
BEFORE UPDATE ON conversations
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Conversation participants
CREATE TABLE IF NOT EXISTS conversation_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  participant CITEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (conversation_id, participant)
);

CREATE INDEX IF NOT EXISTS ix_conversation_participants_conversation_id
  ON conversation_participants(conversation_id);

CREATE TRIGGER conversation_participants_on_update
BEFORE UPDATE ON conversation_participants
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Providers
CREATE TABLE IF NOT EXISTS provider (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    channel channel NOT NULL
);

INSERT INTO provider (name, channel)
VALUES
  ('Twilio', 'sms'),
  ('Nexmo', 'sms'),
  ('SendGrid', 'email'),
  ('Mailgun', 'email'),
  ('MMSGateway', 'mms');

-- Messages
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES provider(id) ON DELETE CASCADE,
    provider_message_id VARCHAR(255),
    inbound_or_outbound inbound_or_outbound NOT NULL,
    participant_source TEXT NOT NULL,
    participant_target TEXT NOT NULL,
    channel channel NOT NULL,
    body TEXT,
    attachments JSONB,
    "timestamp" TIMESTAMPTZ NOT NULL,        -- kept as requested
    status status NOT NULL,
    error_code VARCHAR(64),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider_id, provider_message_id) -- optional but useful
);

-- Indexes
CREATE INDEX IF NOT EXISTS ix_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS ix_messages_participants ON messages(participant_source, participant_target);
CREATE INDEX IF NOT EXISTS ix_messages_timestamp ON messages("timestamp");
CREATE INDEX IF NOT EXISTS ix_messages_status_unprocessed ON messages(status) WHERE status = 'unprocessed';

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
