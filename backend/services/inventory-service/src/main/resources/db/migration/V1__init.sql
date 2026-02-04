-- V1__init.sql (inventory-service)

-- CREATE SCHEMA IF NOT EXISTS inventory_service;
-- SET search_path TO inventory_service;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- reservation_status:
-- 1 PENDING
-- 2 RESERVED
-- 3 RELEASED
-- 4 FAILED

-- ---------- TABLE: warehouses ----------
CREATE TABLE IF NOT EXISTS warehouses (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        varchar(32) NOT NULL,
  name        varchar(255) NOT NULL,
  address     text NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_warehouses_code UNIQUE (code)
);

-- ---------- TABLE: stock_items ----------
-- Stock per (warehouse, sku)
CREATE TABLE IF NOT EXISTS stock_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id uuid NOT NULL,
  sku          varchar(64) NOT NULL,

  on_hand      bigint NOT NULL DEFAULT 0 CHECK (on_hand >= 0),
  reserved     bigint NOT NULL DEFAULT 0 CHECK (reserved >= 0),

  updated_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_stock_items_wh_sku UNIQUE (warehouse_id, sku),
  CONSTRAINT fk_stock_items_warehouse
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
    ON DELETE RESTRICT,

  CONSTRAINT ck_stock_items_reserved_le_onhand CHECK (reserved <= on_hand)
);

CREATE INDEX IF NOT EXISTS idx_stock_items_sku ON stock_items(sku);
CREATE INDEX IF NOT EXISTS idx_stock_items_wh ON stock_items(warehouse_id);

-- ---------- TABLE: stock_reservations ----------
CREATE TABLE IF NOT EXISTS stock_reservations (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     uuid NOT NULL,                  -- no FK across services
  warehouse_id uuid NOT NULL,
  status       smallint NOT NULL,
  expires_at   timestamptz NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT ck_reservation_status CHECK (status IN (1,2,3,4)),
  CONSTRAINT fk_stock_res_warehouse
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
    ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_stock_res_order_id ON stock_reservations(order_id);
CREATE INDEX IF NOT EXISTS idx_stock_res_status_expires
  ON stock_reservations(status, expires_at);

-- ---------- TABLE: stock_reservation_items ----------
CREATE TABLE IF NOT EXISTS stock_reservation_items (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid NOT NULL,
  sku            varchar(64) NOT NULL,
  qty            bigint NOT NULL CHECK (qty > 0),

  CONSTRAINT fk_stock_res_items_reservation
    FOREIGN KEY (reservation_id) REFERENCES stock_reservations(id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stock_res_items_reservation
  ON stock_reservation_items(reservation_id);

CREATE INDEX IF NOT EXISTS idx_stock_res_items_sku
  ON stock_reservation_items(sku);

-- Optional: prevent duplicated sku lines per reservation
CREATE UNIQUE INDEX IF NOT EXISTS uq_stock_res_items_reservation_sku
  ON stock_reservation_items(reservation_id, sku);

-- ---------- TABLE: stock_movements (audit ledger) ----------
-- Track changes for audit & reconciliation
-- movement_type:
-- 1 INBOUND
-- 2 OUTBOUND
-- 3 ADJUSTMENT
-- 4 RESERVE
-- 5 RELEASE
CREATE TABLE IF NOT EXISTS stock_movements (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id uuid NOT NULL,
  sku          varchar(64) NOT NULL,
  movement_type smallint NOT NULL CHECK (movement_type IN (1,2,3,4,5)),
  qty          bigint NOT NULL CHECK (qty > 0),
  reference_id varchar(64) NULL,              -- e.g. orderId/reservationId
  created_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT fk_stock_movements_warehouse
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
    ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_wh_sku_created
  ON stock_movements(warehouse_id, sku, created_at DESC);

-- ---------- OUTBOX ----------
CREATE TABLE IF NOT EXISTS outbox_event (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type varchar(64) NOT NULL,         -- e.g. "inventory"
  aggregate_id   uuid NOT NULL,                -- reservation id or stock item id
  event_type     varchar(128) NOT NULL,        -- "StockReserved"
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

DROP TRIGGER IF EXISTS trg_warehouses_updated_at ON warehouses;
CREATE TRIGGER trg_warehouses_updated_at
BEFORE UPDATE ON warehouses
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_stock_reservations_updated_at ON stock_reservations;
CREATE TRIGGER trg_stock_reservations_updated_at
BEFORE UPDATE ON stock_reservations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
