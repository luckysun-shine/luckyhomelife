import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppConfig } from '../../config.js';
import type { DatabasePool } from '../../database/pool.js';
import { authenticate } from '../../auth.js';
import { notFound, unauthorized } from '../../errors.js';
import { FamilyRepository } from '../families/repository.js';

const familyParams = z.object({ familyId: z.string().uuid() });

export async function registerRecordRoutes(app: FastifyInstance, options: { pool: DatabasePool; config: AppConfig }) {
  const { pool, config } = options;
  const families = new FamilyRepository(pool);
  const auth = authenticate(config.JWT_SECRET);
  const context = async (request: { sessionUser?: { userId: string } }, familyId: string) => {
    const userId = request.sessionUser?.userId ?? (() => { throw unauthorized(); })();
    return { userId, member: await families.requireMembership(userId, familyId, 'family:read') };
  };

  app.post('/api/v1/families/:familyId/records', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const { member } = await context(request, familyId);
    const body = z.object({ body: z.string().max(10000).optional(), happenedAt: z.string().datetime(), visibility: z.enum(['self','family','selected','admins','guardians']).default('family'), memberIds: z.array(z.string().uuid()).max(30).default([]), viewerMemberIds:z.array(z.string().uuid()).max(30).default([]),clientOperationId:z.string().min(8).max(100) }).refine((value) => Boolean(value.body?.trim()), '记录内容不能为空').refine((value)=>value.visibility!=='selected'||value.viewerMemberIds.length>0,'指定成员可见时至少选择一位查看者').parse(request.body);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const record = await client.query(
        `INSERT INTO family_records(family_id,created_by_member_id,body,happened_at,visibility,client_operation_id) VALUES($1,$2,$3,$4,$5,$6)
         ON CONFLICT(family_id,client_operation_id) WHERE client_operation_id IS NOT NULL DO UPDATE SET client_operation_id=EXCLUDED.client_operation_id
         RETURNING id,body,happened_at AS "happenedAt",visibility,created_at AS "createdAt"`, [familyId,member.id,body.body,body.happenedAt,body.visibility,body.clientOperationId]);
      for (const memberId of new Set(body.memberIds)) {
        const linked = await client.query('INSERT INTO record_members(record_id,member_id) SELECT $1,id FROM family_members WHERE id=$2 AND family_id=$3 AND removed_at IS NULL ON CONFLICT(record_id,member_id) DO UPDATE SET member_id=EXCLUDED.member_id RETURNING member_id', [record.rows[0].id,memberId,familyId]);
        if (!linked.rowCount) throw notFound('关联成员不存在');
      }
      for(const viewerId of new Set(body.viewerMemberIds)){
        const viewer=await client.query('INSERT INTO record_viewers(record_id,member_id) SELECT $1,id FROM family_members WHERE id=$2 AND family_id=$3 AND removed_at IS NULL ON CONFLICT(record_id,member_id) DO UPDATE SET member_id=EXCLUDED.member_id RETURNING member_id',[record.rows[0].id,viewerId,familyId]);
        if(!viewer.rowCount)throw notFound('指定查看成员不存在');
      }
      await client.query('COMMIT'); reply.code(201); return { data: record.rows[0] };
    } catch (error) { await client.query('ROLLBACK'); throw error; } finally { client.release(); }
  });

  app.get('/api/v1/families/:familyId/records', { preHandler: auth }, async (request) => {
    const { familyId } = familyParams.parse(request.params);
    const { member } = await context(request, familyId);
    const query = z.object({ before: z.string().datetime().optional(), limit: z.coerce.number().int().min(1).max(100).default(30) }).parse(request.query);
    const result = await pool.query(
      `SELECT r.id,r.body,r.happened_at AS "happenedAt",r.visibility,r.created_at AS "createdAt",creator.display_name AS "createdByName",
              COALESCE(json_agg(json_build_object('id',linked.id,'displayName',linked.display_name)) FILTER(WHERE linked.id IS NOT NULL),'[]') AS members,
              COALESCE((SELECT json_agg(json_build_object('id',a.id,'mimeType',a.mime_type)) FROM media_assets a WHERE a.record_id=r.id AND a.upload_status='ready'),'[]') AS media
       FROM family_records r JOIN family_members creator ON creator.id=r.created_by_member_id
       LEFT JOIN record_members rm ON rm.record_id=r.id LEFT JOIN family_members linked ON linked.id=rm.member_id
       WHERE r.family_id=$1 AND r.deleted_at IS NULL AND ($2::timestamptz IS NULL OR r.happened_at < $2)
         AND (r.visibility='family' OR r.created_by_member_id=$3 OR (r.visibility='admins' AND $4='admin')
           OR (r.visibility='selected' AND EXISTS(SELECT 1 FROM record_viewers rv WHERE rv.record_id=r.id AND rv.member_id=$3))
           OR (r.visibility='guardians' AND EXISTS(SELECT 1 FROM record_members grm JOIN family_members child ON child.id=grm.member_id WHERE grm.record_id=r.id AND child.guardian_member_id=$3)))
       GROUP BY r.id,creator.display_name ORDER BY r.happened_at DESC LIMIT $5`, [familyId,query.before ?? null,member.id,member.role,query.limit]);
    return { data: result.rows };
  });

  app.post('/api/v1/families/:familyId/growth-milestones', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const { member } = await context(request, familyId);
    const body = z.object({ memberId: z.string().uuid(), title: z.string().trim().min(1).max(160), happenedAt: z.string().datetime(), note: z.string().max(4000).optional(), recordId: z.string().uuid().optional(),clientOperationId:z.string().min(8).max(100) }).parse(request.body);
    const target = await pool.query('SELECT 1 FROM family_members WHERE id=$1 AND family_id=$2 AND removed_at IS NULL', [body.memberId,familyId]);
    if (!target.rowCount) throw notFound('成长成员不存在');
    const result = await pool.query(
      `INSERT INTO growth_milestones(family_id,member_id,created_by_member_id,title,happened_at,note,record_id,client_operation_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8)
       ON CONFLICT(family_id,client_operation_id) WHERE client_operation_id IS NOT NULL DO UPDATE SET client_operation_id=EXCLUDED.client_operation_id
       RETURNING id,member_id AS "memberId",title,happened_at AS "happenedAt",note,record_id AS "recordId"`,
      [familyId,body.memberId,member.id,body.title,body.happenedAt,body.note ?? null,body.recordId ?? null,body.clientOperationId]);
    reply.code(201); return { data: result.rows[0] };
  });

  app.get('/api/v1/families/:familyId/growth-milestones', { preHandler: auth }, async (request) => {
    const { familyId } = familyParams.parse(request.params); await context(request, familyId);
    const query = z.object({ memberId: z.string().uuid() }).parse(request.query);
    const result = await pool.query(
      `SELECT id,member_id AS "memberId",title,happened_at AS "happenedAt",note,record_id AS "recordId" FROM growth_milestones
       WHERE family_id=$1 AND member_id=$2 ORDER BY happened_at DESC`, [familyId,query.memberId]);
    return { data: result.rows };
  });
}
