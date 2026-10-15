import type { DatabasePool } from '../../database/pool.js';
import { conflict, notFound } from '../../errors.js';
import { FamilyRepository } from '../families/repository.js';

export interface NewEvent {
  clientOperationId: string;
  title: string;
  startsAt: string;
  endsAt: string;
  allDay: boolean;
  location?: string;
  notes?: string;
  participantMemberIds: string[];
  reminderMinutes?: number;
}

export interface NewTask {
  clientOperationId: string;
  title: string;
  notes?: string;
  dueAt?: string;
  assignedToMemberId?: string;
  listId?: string;
}

export class CollaborationRepository {
  private readonly families: FamilyRepository;
  constructor(private readonly pool: DatabasePool) {
    this.families = new FamilyRepository(pool);
  }

  async createEvent(userId: string, familyId: string, input: NewEvent) {
    const actor = await this.families.requireMembership(userId, familyId, 'family:read');
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      if (input.participantMemberIds.length) {
        const members = await client.query(
          'SELECT id FROM family_members WHERE family_id = $1 AND id = ANY($2::uuid[]) AND removed_at IS NULL',
          [familyId, input.participantMemberIds],
        );
        if (members.rowCount !== new Set(input.participantMemberIds).size) throw notFound('部分参与成员不存在');
      }
      const event = await client.query(
        `INSERT INTO calendar_events(family_id, created_by_member_id, title, starts_at, ends_at, all_day, location, notes,client_operation_id)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT(family_id,client_operation_id) WHERE client_operation_id IS NOT NULL DO UPDATE SET client_operation_id=EXCLUDED.client_operation_id
         RETURNING id, title, starts_at AS "startsAt", ends_at AS "endsAt", all_day AS "allDay", location, notes, version`,
        [familyId, actor.id, input.title, input.startsAt, input.endsAt, input.allDay, input.location ?? null, input.notes ?? null,input.clientOperationId],
      );
      for (const memberId of new Set(input.participantMemberIds)) {
        await client.query(
          'INSERT INTO calendar_event_participants(event_id, member_id, reminder_minutes) VALUES($1,$2,$3) ON CONFLICT(event_id,member_id) DO NOTHING',
          [event.rows[0].id, memberId, input.reminderMinutes ?? null],
        );
      }
      await client.query(
        `INSERT INTO audit_logs(family_id, actor_user_id, action, resource_type, resource_id)
         VALUES($1,$2,'calendar.event_created','calendar_event',$3)`,
        [familyId, userId, event.rows[0].id],
      );
      await client.query('COMMIT');
      return event.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async listEvents(userId: string, familyId: string, from: string, to: string) {
    await this.families.requireMembership(userId, familyId, 'family:read');
    const result = await this.pool.query(
      `SELECT e.id, e.title, e.starts_at AS "startsAt", e.ends_at AS "endsAt", e.all_day AS "allDay",
              e.location, e.notes, e.version,
              COALESCE(json_agg(json_build_object('id', m.id, 'displayName', m.display_name))
                FILTER (WHERE m.id IS NOT NULL), '[]') AS participants
       FROM calendar_events e
       LEFT JOIN calendar_event_participants ep ON ep.event_id = e.id
       LEFT JOIN family_members m ON m.id = ep.member_id
       WHERE e.family_id = $1 AND e.deleted_at IS NULL AND e.starts_at < $3 AND e.ends_at >= $2
       GROUP BY e.id ORDER BY e.starts_at`,
      [familyId, from, to],
    );
    return result.rows;
  }

  async updateEvent(userId: string, familyId: string, eventId: string, input: {
    title: string; startsAt: string; endsAt: string; allDay: boolean;
    location?: string; notes?: string; expectedVersion: number;
  }) {
    await this.families.requireMembership(userId, familyId, 'family:read');
    const result = await this.pool.query(
      `UPDATE calendar_events SET title=$1,starts_at=$2,ends_at=$3,all_day=$4,
         location=$5,notes=$6,version=version+1,updated_at=now()
       WHERE id=$7 AND family_id=$8 AND version=$9 AND deleted_at IS NULL
       RETURNING id,title,starts_at AS "startsAt",ends_at AS "endsAt",
                 all_day AS "allDay",location,notes,version`,
      [input.title, input.startsAt, input.endsAt, input.allDay,
        input.location ?? null, input.notes ?? null, eventId, familyId, input.expectedVersion],
    );
    if (!result.rowCount) throw conflict('日程已被其他家人修改，请刷新后重试');
    return result.rows[0];
  }

  async deleteEvent(userId: string, familyId: string, eventId: string, expectedVersion: number) {
    await this.families.requireMembership(userId, familyId, 'family:read');
    const result = await this.pool.query(
      `UPDATE calendar_events SET deleted_at=now(),version=version+1,updated_at=now()
       WHERE id=$1 AND family_id=$2 AND version=$3 AND deleted_at IS NULL RETURNING id`,
      [eventId, familyId, expectedVersion],
    );
    if (!result.rowCount) throw conflict('日程已被其他家人修改，请刷新后重试');
  }

  async createTask(userId: string, familyId: string, input: NewTask) {
    const actor = await this.families.requireMembership(userId, familyId, 'family:read');
    if (input.assignedToMemberId) {
      const assignee = await this.pool.query(
        'SELECT 1 FROM family_members WHERE id = $1 AND family_id = $2 AND removed_at IS NULL',
        [input.assignedToMemberId, familyId],
      );
      if (!assignee.rowCount) throw notFound('负责人不存在');
    }
    const result = await this.pool.query(
      `INSERT INTO tasks(family_id, list_id, created_by_member_id, assigned_to_member_id, title, notes, due_at,client_operation_id)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(family_id,client_operation_id) WHERE client_operation_id IS NOT NULL DO UPDATE SET client_operation_id=EXCLUDED.client_operation_id
       RETURNING id, title, notes, due_at AS "dueAt", assigned_to_member_id AS "assignedToMemberId", status, version`,
      [familyId, input.listId ?? null, actor.id, input.assignedToMemberId ?? null, input.title, input.notes ?? null, input.dueAt ?? null,input.clientOperationId],
    );
    return result.rows[0];
  }

  async listTasks(userId: string, familyId: string, includeCompleted: boolean) {
    await this.families.requireMembership(userId, familyId, 'family:read');
    const result = await this.pool.query(
      `SELECT t.id, t.title, t.notes, t.due_at AS "dueAt", t.status, t.version,
              t.assigned_to_member_id AS "assignedToMemberId", m.display_name AS "assignedToName",
              l.title AS "listTitle", l.type AS "listType"
       FROM tasks t
       LEFT JOIN family_members m ON m.id = t.assigned_to_member_id
       LEFT JOIN task_lists l ON l.id = t.list_id
       WHERE t.family_id = $1 AND t.deleted_at IS NULL AND ($2 OR t.status = 'open')
       ORDER BY t.status, t.due_at NULLS LAST, t.created_at DESC`,
      [familyId, includeCompleted],
    );
    return result.rows;
  }

  async setTaskCompletion(userId: string, familyId: string, taskId: string, completed: boolean, expectedVersion: number) {
    const actor = await this.families.requireMembership(userId, familyId, 'family:read');
    const result = await this.pool.query(
      `UPDATE tasks SET status=$1, completed_at=$2, completed_by_member_id=$3, version=version+1, updated_at=now()
       WHERE id=$4 AND family_id=$5 AND version=$6 AND deleted_at IS NULL
       RETURNING id, status, completed_at AS "completedAt", version`,
      [completed ? 'completed' : 'open', completed ? new Date() : null, completed ? actor.id : null, taskId, familyId, expectedVersion],
    );
    if (!result.rowCount) throw conflict('任务已被其他家人修改，请刷新后重试');
    return result.rows[0];
  }

  async createList(userId: string, familyId: string, title: string, type: 'task' | 'shopping') {
    const actor = await this.families.requireMembership(userId, familyId, 'family:read');
    const result = await this.pool.query(
      `INSERT INTO task_lists(family_id, created_by_member_id, title, type) VALUES($1,$2,$3,$4)
       RETURNING id, title, type, created_at AS "createdAt"`,
      [familyId, actor.id, title, type],
    );
    return result.rows[0];
  }

  async today(userId: string, familyId: string, timezone: string) {
    await this.families.requireMembership(userId, familyId, 'family:read');
    const [events, tasks] = await Promise.all([
      this.pool.query(
        `SELECT id, title, starts_at AS "startsAt", ends_at AS "endsAt", all_day AS "allDay", location
         FROM calendar_events
         WHERE family_id=$1 AND deleted_at IS NULL
           AND starts_at < ((now() AT TIME ZONE $2)::date + 1) AT TIME ZONE $2
           AND ends_at >= (now() AT TIME ZONE $2)::date AT TIME ZONE $2
         ORDER BY starts_at`,
        [familyId, timezone],
      ),
      this.pool.query(
        `SELECT id, title, due_at AS "dueAt", status, version FROM tasks
         WHERE family_id=$1 AND deleted_at IS NULL AND status='open'
           AND (due_at IS NULL OR due_at < ((now() AT TIME ZONE $2)::date + 1) AT TIME ZONE $2)
         ORDER BY due_at NULLS LAST LIMIT 20`,
        [familyId, timezone],
      ),
    ]);
    return { events: events.rows, tasks: tasks.rows };
  }
}
