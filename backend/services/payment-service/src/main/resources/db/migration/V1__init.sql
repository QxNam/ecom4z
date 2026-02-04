-- V1__init.sql (payment-service)

-- CREATE SCHEMA IF NOT EXISTS payment_service;
-- SET search_path TO payment_service;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- payment_status:
-- 1 CREATED
-- 2 PROCESSING
-- 3 SUCCEEDED
-- 4 FAILED
-- 5 CANCELLED

-- ---------- TABLE: payment_intents ----------
CREATE TABLE IF NOT EXISTS payment_intents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id         uuid NOT NULL,                 -- no FK cross-service
  provider         varchar(32) NOT NULL,          -- e.g. vnpay/momo/stripe
  amount           numeric(19,4) NOT NULL CHECK (amount >= 0),
  currency         char(3) NOT NULL CHECK (length(currency) = 3),
  status           smallint NOT NULL CHECK (status IN (1,2,3,4,5)),

  idempotency_key  varchar(128) NOT NULL,
  provider_ref     varchar(128) NULL,            -- transaction id from provider

  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_payment_intents_idempotency UNIQUE (idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_payment_intents_order_id
  ON payment_intents(order_id);

CREATE INDEX IF NOT EXISTS idx_payment_intents_status_created
  ON payment_intents(status, created_at DESC);

-- If provider_ref is used for lookup often:
CREATE INDEX IF NOT EXISTS idx_payment_intents_provider_ref
  ON payment_intents(provider, provider_ref);

-- ---------- TABLE: payment_transactions (optional but recommended) ----------
-- Keep an internal ledger of payment attempts / captures / refunds
-- txn_type:
-- 1 AUTHORIZE
-- 2 CAPTURE
-- 3 REFUND
CREATE TABLE IF NOT EXISTS payment_transactions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_intent_id uuid NOT NULL,
  txn_type       smallint NOT NULL CHECK (txn_type IN (1,2,3)),
  provider_ref   varchar(128) NULL,
  amount         numeric(19,4) NOT NULL CHECK (amount >= 0),
  currency       char(3) NOT NULL CHECK (length(currency) = 3),
  status         smallint NOT NULL CHECK (status IN (1,2,3,4,5)),
  raw_payload    jsonb NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT fk_payment_txn_intent
    FOREIGN KEY (payment_intent_id) REFERENCES payment_intents(id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_payment_txn_intent_created
  ON payment_transactions(payment_intent_id, created_at DESC);

-- ---------- TABLE: payment_webhook_events (idempotency for webhook) ----------
CREATE TABLE IF NOT EXISTS payment_webhook_events (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider      varchar(32) NOT NULL,
  event_id      varchar(128) NOT NULL,      -- provider's event id (unique per provider)
  payload       jsonb NOT NULL,
  received_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_webhook_provider_event UNIQUE (provider, event_id)
);

CREATE INDEX IF NOT EXISTS idx_webhook_received_at
  ON payment_webhook_events(received_at DESC);

-- ---------- OUTBOX ----------
CREATE TABLE IF NOT EXISTS outbox_event (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type varchar(64) NOT NULL,         -- e.g. "payment"
  aggregate_id   uuid NOT NULL,                -- payment_intents.id
  event_type     varchar(128) NOT NULL,        -- PaymentSucceeded, PaymentFailed...
  payload        jsonb NOT NULL,
  trace_id       varchar(64) NULL,
  occurred_at    timestamptz NOT NULL DEFAULT now(),
  published_at   timestamptz NULL,
  status         smallint NOT NULL DEFAULT 0,  -- 0 NEW, 1 PUBLISHED, 2 FAILED
  retry_count    integer NOT NULL DEFAULT 0,

  CONSTRAINT ck_outbox_status CHECK (status IN (0,1,2))
);

CREATE INDEX IF NOT EXISTS idx_outbox_status_occurred
  ON outbox_event(status, occurred_at);

CREATE INDEX IF NOT EXISTS idx_outbox_aggregate
  ON outbox_event(aggregate_type, aggregate_id);

-- ---------- PROCESSED EVENT ----------
CREATE TABLE IF NOT EXISTS processed_event (
  event_id      varchar(128) PRIMARY KEY,
  source_topic  varchar(255) NOT NULL,
  processed_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------- updated_at trigger ----------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payment_intents_updated_at ON payment_intents;
CREATE TRIGGER trg_payment_intents_updated_at
BEFORE UPDATE ON payment_intents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
