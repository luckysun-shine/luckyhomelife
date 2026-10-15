CREATE TYPE transaction_type AS ENUM ('expense', 'income', 'refund', 'reimbursement');
CREATE TYPE medication_plan_status AS ENUM ('active', 'paused', 'ended');
CREATE TYPE medication_log_status AS ENUM ('taken', 'skipped', 'missed');

CREATE TABLE ledgers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  name varchar(100) NOT NULL, is_personal boolean NOT NULL DEFAULT false,
  owner_member_id uuid REFERENCES family_members(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  ledger_id uuid NOT NULL REFERENCES ledgers(id), created_by_member_id uuid NOT NULL REFERENCES family_members(id),
  payer_member_id uuid REFERENCES family_members(id), type transaction_type NOT NULL,
  amount_minor bigint NOT NULL CHECK(amount_minor > 0), currency char(3) NOT NULL DEFAULT 'CNY',
  category varchar(80) NOT NULL, occurred_at timestamptz NOT NULL, note varchar(500),
  idempotency_key varchar(100) NOT NULL, version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz,
  UNIQUE(family_id, idempotency_key)
);
CREATE INDEX idx_transactions_family_date ON transactions(family_id, occurred_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE family_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  created_by_member_id uuid NOT NULL REFERENCES family_members(id), body text,
  happened_at timestamptz NOT NULL, visibility visibility_scope NOT NULL DEFAULT 'family',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE record_members (
  record_id uuid NOT NULL REFERENCES family_records(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES family_members(id), PRIMARY KEY(record_id, member_id)
);
CREATE TABLE media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  record_id uuid REFERENCES family_records(id), storage_key varchar(500) NOT NULL,
  thumbnail_key varchar(500), mime_type varchar(100) NOT NULL, size_bytes bigint NOT NULL CHECK(size_bytes >= 0),
  sha256 char(64), upload_status varchar(20) NOT NULL DEFAULT 'pending', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE growth_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  member_id uuid NOT NULL REFERENCES family_members(id), created_by_member_id uuid NOT NULL REFERENCES family_members(id),
  title varchar(160) NOT NULL, happened_at timestamptz NOT NULL, note text,
  record_id uuid REFERENCES family_records(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_records_family_time ON family_records(family_id, happened_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_growth_member_time ON growth_milestones(member_id, happened_at DESC);

CREATE TABLE health_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  member_id uuid NOT NULL REFERENCES family_members(id), blood_type varchar(10), allergies text,
  chronic_conditions text, surgery_history text, emergency_contact varchar(200),
  updated_by_member_id uuid NOT NULL REFERENCES family_members(id), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(family_id, member_id)
);
CREATE TABLE health_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  member_id uuid NOT NULL REFERENCES family_members(id), created_by_member_id uuid NOT NULL REFERENCES family_members(id),
  visited_at timestamptz NOT NULL, hospital varchar(160) NOT NULL, department varchar(100), doctor varchar(100),
  symptoms text, diagnosis text, treatment text, follow_up_at timestamptz,
  transaction_id uuid REFERENCES transactions(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE health_exams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  member_id uuid NOT NULL REFERENCES family_members(id), created_by_member_id uuid NOT NULL REFERENCES family_members(id),
  examined_at timestamptz NOT NULL, institution varchar(160) NOT NULL, summary text,
  next_exam_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE health_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  member_id uuid NOT NULL REFERENCES family_members(id), metric_type varchar(60) NOT NULL,
  value_numeric numeric(12,3) NOT NULL, secondary_value numeric(12,3), unit varchar(30) NOT NULL,
  measured_at timestamptz NOT NULL, source varchar(80) NOT NULL DEFAULT 'manual', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE medications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  name varchar(160) NOT NULL, specification varchar(120), form varchar(80), expires_on date,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE medication_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  member_id uuid NOT NULL REFERENCES family_members(id), medication_id uuid NOT NULL REFERENCES medications(id),
  created_by_member_id uuid NOT NULL REFERENCES family_members(id), dose varchar(80) NOT NULL,
  instructions varchar(300), schedule_times jsonb NOT NULL, start_date date NOT NULL, end_date date,
  timezone varchar(80) NOT NULL DEFAULT 'Asia/Shanghai', status medication_plan_status NOT NULL DEFAULT 'active',
  version integer NOT NULL DEFAULT 1, source varchar(80) NOT NULL DEFAULT 'manual', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE medication_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  plan_id uuid NOT NULL REFERENCES medication_plans(id), scheduled_at timestamptz NOT NULL,
  actual_at timestamptz, status medication_log_status NOT NULL, confirmed_by_member_id uuid REFERENCES family_members(id),
  reason varchar(240), client_operation_id varchar(100) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(family_id, client_operation_id), UNIQUE(plan_id, scheduled_at)
);
CREATE INDEX idx_visits_member_time ON health_visits(member_id, visited_at DESC);
CREATE INDEX idx_exams_member_time ON health_exams(member_id, examined_at DESC);
CREATE INDEX idx_metrics_member_time ON health_metrics(member_id, metric_type, measured_at DESC);
CREATE INDEX idx_medication_plans_member ON medication_plans(member_id, status);
CREATE INDEX idx_medication_logs_schedule ON medication_logs(plan_id, scheduled_at DESC);
