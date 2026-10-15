CREATE TABLE health_access_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), family_id uuid NOT NULL REFERENCES families(id),
  subject_member_id uuid NOT NULL REFERENCES family_members(id), grantee_member_id uuid NOT NULL REFERENCES family_members(id),
  can_write boolean NOT NULL DEFAULT false, granted_by_member_id uuid NOT NULL REFERENCES family_members(id),
  expires_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), revoked_at timestamptz,
  UNIQUE(subject_member_id, grantee_member_id)
);
CREATE INDEX idx_health_grants_grantee ON health_access_grants(grantee_member_id,subject_member_id) WHERE revoked_at IS NULL;

