DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'resource_state') THEN
    CREATE TYPE resource_state AS ENUM (
      'IN_WAREHOUSE',
      'CHECKED_OUT',
      'MAINTENANCE',
      'LOST'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS resource_type (
  id           BIGSERIAL PRIMARY KEY,
  name         TEXT NOT NULL UNIQUE,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS resource_item (
  id                   BIGSERIAL PRIMARY KEY,
  resource_type_id      BIGINT NOT NULL REFERENCES resource_type(id) ON DELETE RESTRICT,
  code                 TEXT NOT NULL UNIQUE,
  current_state        resource_state NOT NULL DEFAULT 'IN_WAREHOUSE',
  last_state_change_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes                TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();

RETURN NEW;

END;

$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_resource_item_updated_at ON resource_item;

CREATE TRIGGER trg_resource_item_updated_at
BEFORE UPDATE ON resource_item
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_resource_item_state ON resource_item (current_state);

CREATE INDEX IF NOT EXISTS idx_resource_item_type ON resource_item (resource_type_id);

CREATE TABLE IF NOT EXISTS event (
    id BIGSERIAL PRIMARY KEY,
    name TEXT,
    event_date DATE NOT NULL,
    location TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_date ON event(event_date);

CREATE INDEX IF NOT EXISTS idx_event_location_date ON event(location, event_date);

CREATE TABLE IF NOT EXISTS dispatch (
    id BIGSERIAL PRIMARY KEY,
    resource_item_id BIGINT NOT NULL REFERENCES resource_item (id) ON DELETE RESTRICT,
    dispatched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    dispatch_note TEXT,
    returned_at TIMESTAMPTZ NULL,
    return_note TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_one_open_dispatch_per_item ON dispatch (resource_item_id)
WHERE
    returned_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_dispatch_item_time ON dispatch (
    resource_item_id,
    dispatched_at DESC
);

CREATE TABLE IF NOT EXISTS dispatch_event (
    id BIGSERIAL PRIMARY KEY,
    dispatch_id BIGINT NOT NULL REFERENCES dispatch (id) ON DELETE CASCADE,
    event_id BIGINT NOT NULL REFERENCES event (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_dispatch_event ON dispatch_event (dispatch_id, event_id);

CREATE INDEX IF NOT EXISTS idx_dispatch_event_event ON dispatch_event (event_id);