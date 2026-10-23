-- Service Commandes — schéma orders (owner: orders_svc)
SET ROLE orders_svc;
SET search_path TO orders;

CREATE TABLE customers (
    id     serial PRIMARY KEY,
    name   text NOT NULL,
    email  text NOT NULL UNIQUE
);

-- Partitioned by month on created_at: the PK must contain the partition key,
-- hence (id, created_at) instead of id alone (see ADR-001).
CREATE TABLE orders (
    id               bigserial,
    customer_id      integer     NOT NULL REFERENCES customers(id),
    status           text        NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'paid', 'preparing',
                                       'payment_failed', 'delivered', 'cancelled')),
    total_cents      integer     NOT NULL CHECK (total_cents >= 0),
    idempotency_key  text        NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, created_at),
    UNIQUE (idempotency_key, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE order_items (
    id                serial PRIMARY KEY,
    order_id          bigint      NOT NULL,
    order_created_at  timestamptz NOT NULL,
    product_id        integer     NOT NULL,  -- lien applicatif vers catalog (pas de FK)
    quantity          integer     NOT NULL CHECK (quantity > 0),
    unit_price_cents  integer     NOT NULL CHECK (unit_price_cents >= 0),
    FOREIGN KEY (order_id, order_created_at)
        REFERENCES orders(id, created_at) ON DELETE CASCADE
);

-- Monthly partitions around "now" + a default partition so inserts never fail.
DO $$
DECLARE
    m date := date_trunc('month', now())::date - interval '6 months';
BEGIN
    FOR i IN 0..12 LOOP
        EXECUTE format(
            'CREATE TABLE orders_%s PARTITION OF orders FOR VALUES FROM (%L) TO (%L)',
            to_char(m, 'YYYY_MM'), m, (m + interval '1 month')::date);
        m := (m + interval '1 month')::date;
    END LOOP;
END $$;
CREATE TABLE orders_default PARTITION OF orders DEFAULT;

-- Indexes chosen for the screens (Commandes tab: recent orders, by customer, by status).
-- Compare with EXPLAIN ANALYZE before/after in db/explain/.
CREATE INDEX idx_orders_customer   ON orders (customer_id, created_at DESC);
CREATE INDEX idx_orders_status     ON orders (status, created_at DESC);
CREATE INDEX idx_order_items_order ON order_items (order_id);

RESET ROLE;
