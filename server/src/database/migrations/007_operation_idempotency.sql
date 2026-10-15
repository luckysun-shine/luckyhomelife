ALTER TABLE calendar_events ADD COLUMN client_operation_id varchar(100);
ALTER TABLE tasks ADD COLUMN client_operation_id varchar(100);
ALTER TABLE family_records ADD COLUMN client_operation_id varchar(100);
ALTER TABLE growth_milestones ADD COLUMN client_operation_id varchar(100);

CREATE UNIQUE INDEX uq_calendar_operation ON calendar_events(family_id,client_operation_id) WHERE client_operation_id IS NOT NULL;
CREATE UNIQUE INDEX uq_task_operation ON tasks(family_id,client_operation_id) WHERE client_operation_id IS NOT NULL;
CREATE UNIQUE INDEX uq_record_operation ON family_records(family_id,client_operation_id) WHERE client_operation_id IS NOT NULL;
CREATE UNIQUE INDEX uq_growth_operation ON growth_milestones(family_id,client_operation_id) WHERE client_operation_id IS NOT NULL;

