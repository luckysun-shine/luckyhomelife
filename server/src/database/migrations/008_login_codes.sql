CREATE TABLE login_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), phone varchar(32) NOT NULL,
  code_hash char(64) NOT NULL, expires_at timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0, consumed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_login_codes_phone ON login_codes(phone,created_at DESC);

