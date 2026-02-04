-- V1__init.sql (order-service)
-- PostgreSQL 13+ recommended

-- (OPTIONAL) If you run multiple services in one DB, enable schema-per-service:
-- CREATE SCHEMA IF NOT EXISTS order_service;
-- SET search_path TO order_service;

-- UUID generation (choose ONE strategy)
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- provides gen_random_uuid()

-- ---------- ENUM-LIKE via SMALLINT ----------
-- order_status:
-- 1 PENDING_PAYMENT
-- 2 CONFIRMED
-- 3 CANCELLED
-- 4 FAILED
-- 5 SHIPPING
-- 6 SHIPPED
-- 7 DELIVERED
-- payment_status:
-- 1 UNPAID
-- 2 PAID
-- 3 REFUNDED
-- 4 PARTIAL_REFUNDED
-- shipping_status:
-- 1 NOT_SHIPPED
-- 2 SHIPPING
-- 3 SHIPPED
-- 4 DELIVERED

-- ---------- TABLE: orders ----------
CREATE TABLE IF NOT EXISTS orders (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_code          varchar(32) NOT NULL,
  user_id             uuid NOT NULL,

  status              smallint NOT NULL,
  payment_status      smallint NOT NULL DEFAULT 1,
  shipping_status     smallint NOT NULL DEFAULT 1,

  currency            char(3) NOT NULL,
  subtotal            numeric(19,4) NOT NULL CHECK (subtotal >= 0),
  discount_total      numeric(19,4) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
  shipping_fee        numeric(19,4) NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
  grand_total         numeric(19,4) NOT NULL CHECK (grand_total >= 0),

  shipping_address    jsonb NOT NULL,
  billing_address     jsonb NULL,
  note                text NULL,

  version             integer NOT NULL DEFAULT 0,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_orders_order_code UNIQUE (order_code),
  CONSTRAINT ck_orders_currency_len CHECK (length(currency) = 3),
  CONSTRAINT ck_orders_totals CHECK (grand_total = (subtotal - discount_total + shipping_fee))
);

-- Query patterns: list orders by user, filter by status, recent orders
CREATE INDEX IF NOT EXISTS idx_orders_user_created_at
  ON orders (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status_created_at
  ON orders (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_payment_status
  ON orders (payment_status);

CREATE INDEX IF NOT EXISTS idx_orders_shipping_status
  ON orders (shipping_status);

-- JSONB indexing is expensive; only enable if you filter by address fields frequently:
-- CREATE INDEX IF NOT EXISTS gin_orders_shipping_address ON orders USING gin (shipping_address);

-- ---------- TABLE: order_items ----------
CREATE TABLE IF NOT EXISTS order_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL,
  sku           varchar(64) NOT NULL,
  product_name  varchar(255) NOT NULL,
  unit_price    numeric(19,4) NOT NULL CHECK (unit_price >= 0),
  qty           bigint NOT NULL CHECK (qty > 0),
  line_total    numeric(19,4) NOT NULL CHECK (line_total >= 0),

  created_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT fk_order_items_order_id
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE,

  CONSTRAINT ck_order_items_line_total CHECK (line_total = unit_price * qty)
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_sku ON order_items(sku);

-- ---------- TABLE: order_status_history ----------
CREATE TABLE IF NOT EXISTS order_status_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    uuid NOT NULL,
  from_status smallint NULL,
  to_status   smallint NOT NULL,
  reason      varchar(255) NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT fk_order_status_history_order_id
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_order_status_history_order_created
  ON order_status_history(order_id, created_at DESC);

-- ---------- TABLE: order_idempotency ----------
-- Prevent duplicate "Create Order" requests from client retries
CREATE TABLE IF NOT EXISTS order_idempotency (
  idempotency_key  varchar(128) PRIMARY KEY,
  user_id          uuid NOT NULL,
  order_id         uuid NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_order_idempotency_order_id UNIQUE (order_id)
);

CREATE INDEX IF NOT EXISTS idx_order_idempotency_user_created
  ON order_idempotency(user_id, created_at DESC);

-- ---------- OUTBOX (Kafka publish safety) ----------
CREATE TABLE IF NOT EXISTS outbox_event (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type varchar(64) NOT NULL,          -- e.g. "order"
  aggregate_id   uuid NOT NULL,                 -- orders.id
  event_type     varchar(128) NOT NULL,         -- e.g. "OrderCreated"
  payload        jsonb NOT NULL,
  trace_id       varchar(64) NULL,

  occurred_at    timestamptz NOT NULL DEFAULT now(),
  published_at   timestamptz NULL,

  status         smallint NOT NULL DEFAULT 0,   -- 0 NEW, 1 PUBLISHED, 2 FAILED
  retry_count    integer NOT NULL DEFAULT 0,

  CONSTRAINT ck_outbox_status CHECK (status IN (0,1,2))
);

CREATE INDEX IF NOT EXISTS idx_outbox_status_occurred
  ON outbox_event(status, occurred_at);

CREATE INDEX IF NOT EXISTS idx_outbox_aggregate
  ON outbox_event(aggregate_type, aggregate_id);

-- ---------- PROCESSED EVENT (consumer idempotency) ----------
CREATE TABLE IF NOT EXISTS processed_event (
  event_id      varchar(128) PRIMARY KEY,      -- from Kafka header or event payload
  source_topic  varchar(255) NOT NULL,
  processed_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------- updated_at trigger (optional but recommended) ----------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
