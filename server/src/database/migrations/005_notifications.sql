CREATE TABLE device_registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id),
  platform varchar(20) NOT NULL, push_token varchar(500) NOT NULL,
  enabled boolean NOT NULL DEFAULT true, last_seen_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id,push_token)
);
CREATE TABLE notification_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  recipient_member_id uuid NOT NULL REFERENCES family_members(id), kind varchar(80) NOT NULL,
  resource_type varchar(80), resource_id uuid, scheduled_at timestamptz NOT NULL,
  title varchar(120) NOT NULL, body varchar(500) NOT NULL, sensitive boolean NOT NULL DEFAULT false,
  status varchar(20) NOT NULL DEFAULT 'pending', attempts integer NOT NULL DEFAULT 0,
  sent_at timestamptz, read_at timestamptz, confirmed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_notification_due ON notification_jobs(status,scheduled_at) WHERE status='pending';
CREATE INDEX idx_notification_member ON notification_jobs(recipient_member_id,created_at DESC);

