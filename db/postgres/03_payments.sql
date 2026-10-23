-- Service Paiement — schéma payments (owner: payments_svc)
SET ROLE payments_svc;
SET search_path TO payments;

CREATE TABLE payments (
    id               bigserial PRIMARY KEY,
    order_id         bigint      NOT NULL,  -- lien applicatif vers orders
    amount_cents     integer     NOT NULL CHECK (amount_cents > 0),
    status           text        NOT NULL CHECK (status IN ('accepted', 'refused')),
    idempotency_key  text        NOT NULL UNIQUE,
    created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_payments_order ON payments (order_id);

RESET ROLE;
