-- Service Auth — schéma auth (owner: auth_svc). Application roles (RBAC),
-- distinct from the PostgreSQL roles in 00_roles.sh which protect tables.
SET ROLE auth_svc;
SET search_path TO auth;

CREATE TABLE users (
    id             serial PRIMARY KEY,
    email          text    NOT NULL UNIQUE,
    password_hash  text    NOT NULL,  -- bcrypt/argon2, never plaintext
    is_active      boolean NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE roles (
    id           serial PRIMARY KEY,
    name         text NOT NULL UNIQUE,
    description  text
);

CREATE TABLE user_roles (
    user_id  integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id  integer NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

INSERT INTO roles (name, description) VALUES
    ('admin',           'Responsable plateforme : tout lire, tout écrire'),
    ('catalog_manager', 'Équipe catalogue : produits et prix'),
    ('analyst',         'BI / marketing : lecture seule'),
    ('logistics',       'Logistique : stocks et entrepôts'),
    ('service_account', 'Compte technique inter-services');

RESET ROLE;
