CREATE TABLE record_viewers (
  record_id uuid NOT NULL REFERENCES family_records(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES family_members(id),
  PRIMARY KEY(record_id,member_id)
);
CREATE INDEX idx_record_viewers_member ON record_viewers(member_id,record_id);

