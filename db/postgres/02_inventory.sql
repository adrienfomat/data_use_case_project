-- Service Stock — schéma inventory (owner: inventory_svc)
SET ROLE inventory_svc;
SET search_path TO inventory;

CREATE TABLE warehouses (
    id              serial PRIMARY KEY,
    name            text    NOT NULL UNIQUE,
    capacity_units  integer NOT NULL CHECK (capacity_units > 0)
);

-- Key is (product_id, warehouse_id): one product can sit in several warehouses.
CREATE TABLE stock (
    product_id    integer NOT NULL,  -- lien applicatif vers catalog
    warehouse_id  integer NOT NULL REFERENCES warehouses(id),
    quantity      integer NOT NULL CHECK (quantity >= 0),
    reserved      integer NOT NULL DEFAULT 0 CHECK (reserved >= 0),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (product_id, warehouse_id),
    CHECK (reserved <= quantity)
);

-- Saga step "reserve stock": released if the payment fails (compensation).
-- idempotency_key UNIQUE => the same request replayed reserves only once.
CREATE TABLE reservations (
    id               bigserial PRIMARY KEY,
    order_id         bigint      NOT NULL,  -- lien applicatif vers orders
    product_id       integer     NOT NULL,
    warehouse_id     integer     NOT NULL,
    quantity         integer     NOT NULL CHECK (quantity > 0),
    status           text        NOT NULL DEFAULT 'reserved'
                     CHECK (status IN ('reserved', 'released', 'committed')),
    idempotency_key  text        NOT NULL UNIQUE,
    created_at       timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (product_id, warehouse_id) REFERENCES stock(product_id, warehouse_id)
);

CREATE INDEX idx_stock_warehouse     ON stock (warehouse_id);
CREATE INDEX idx_reservations_order  ON reservations (order_id);

RESET ROLE;
