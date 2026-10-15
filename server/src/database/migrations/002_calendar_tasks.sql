CREATE TYPE visibility_scope AS ENUM ('self', 'family', 'selected', 'admins', 'guardians');
CREATE TYPE task_status AS ENUM ('open', 'completed', 'cancelled');
CREATE TYPE list_type AS ENUM ('task', 'shopping');

CREATE TABLE calendar_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id),
  created_by_member_id uuid NOT NULL REFERENCES family_members(id),
  title varchar(160) NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  all_day boolean NOT NULL DEFAULT false,
  location varchar(240),
  notes text,
  visibility visibility_scope NOT NULL DEFAULT 'family',
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK (ends_at >= starts_at)
);

CREATE TABLE calendar_event_participants (
  event_id uuid NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES family_members(id),
  reminder_minutes integer,
  PRIMARY KEY (event_id, member_id),
  CHECK (reminder_minutes IS NULL OR reminder_minutes BETWEEN 0 AND 10080)
);

CREATE TABLE task_lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id),
  created_by_member_id uuid NOT NULL REFERENCES family_members(id),
  title varchar(120) NOT NULL,
  type list_type NOT NULL DEFAULT 'task',
  visibility visibility_scope NOT NULL DEFAULT 'family',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id),
  list_id uuid REFERENCES task_lists(id),
  created_by_member_id uuid NOT NULL REFERENCES family_members(id),
  assigned_to_member_id uuid REFERENCES family_members(id),
  title varchar(200) NOT NULL,
  notes text,
  due_at timestamptz,
  status task_status NOT NULL DEFAULT 'open',
  completed_at timestamptz,
  completed_by_member_id uuid REFERENCES family_members(id),
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX idx_calendar_family_start ON calendar_events(family_id, starts_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_calendar_participant ON calendar_event_participants(member_id, event_id);
CREATE INDEX idx_tasks_family_due ON tasks(family_id, due_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_assignee ON tasks(assigned_to_member_id, status) WHERE deleted_at IS NULL;

