CREATE TABLE IF NOT EXISTS staff (
  username text PRIMARY KEY,
  password_hash text NOT NULL,
  role text NOT NULL CHECK (role IN ('staff', 'admin'))
);
ALTER TABLE staff ADD COLUMN IF NOT EXISTS enabled boolean NOT NULL DEFAULT true;
CREATE TABLE IF NOT EXISTS dining_tables (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  label text UNIQUE NOT NULL
);
CREATE TABLE IF NOT EXISTS visits (
  id uuid PRIMARY KEY,
  table_id integer NOT NULL REFERENCES dining_tables,
  qr_token text UNIQUE NOT NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'bill_requested', 'paid', 'closed'))
);
CREATE UNIQUE INDEX IF NOT EXISTS visits_one_active_per_table
  ON visits (table_id) WHERE status <> 'closed';
CREATE TABLE IF NOT EXISTS staff_sessions (
  token_hash text PRIMARY KEY,
  username text NOT NULL REFERENCES staff,
  expires_at timestamptz NOT NULL
);
ALTER TABLE staff_sessions ALTER COLUMN expires_at SET DEFAULT 'infinity';
CREATE TABLE IF NOT EXISTS guest_sessions (
  token_hash text PRIMARY KEY,
  visit_id uuid NOT NULL REFERENCES visits
);
CREATE TABLE IF NOT EXISTS products (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL,
  price integer NOT NULL CHECK (price > 0),
  available boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS orders (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  visit_id uuid NOT NULL REFERENCES visits,
  request_key text NOT NULL,
  request_hash text NOT NULL,
  lines jsonb NOT NULL,
  total bigint NOT NULL CHECK (total > 0),
  status text NOT NULL DEFAULT 'received'
    CHECK (status IN ('received', 'preparing', 'ready', 'delivered')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (visit_id, request_key)
);
CREATE TABLE IF NOT EXISTS discount_codes (
  code text PRIMARY KEY,
  percent integer NOT NULL CHECK (percent BETWEEN 1 AND 100),
  starts_on date NOT NULL,
  ends_on date NOT NULL CHECK (ends_on >= starts_on),
  active boolean NOT NULL
);
ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS discount_code text,
  ADD COLUMN IF NOT EXISTS discount_percent integer NOT NULL DEFAULT 0 CHECK (discount_percent BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS bill_method text CHECK (bill_method IN ('transfer', 'cash', 'card')),
  ADD COLUMN IF NOT EXISTS bill_total bigint,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS paid_by text REFERENCES staff,
  ADD COLUMN IF NOT EXISTS review boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS waiter_calls (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  visit_id uuid NOT NULL REFERENCES visits,
  requested_at timestamptz NOT NULL DEFAULT now(),
  attended_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS waiter_calls_one_pending
  ON waiter_calls (visit_id) WHERE attended_at IS NULL;
INSERT INTO dining_tables (label) VALUES ('Mesa 1'), ('Mesa 2'), ('Mesa 3')
ON CONFLICT (label) DO NOTHING;
