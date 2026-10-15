import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppConfig } from '../../config.js';
import type { DatabasePool } from '../../database/pool.js';
import { authenticate } from '../../auth.js';
import { forbidden, notFound, unauthorized } from '../../errors.js';
import { FamilyRepository } from '../families/repository.js';

const familyParams = z.object({ familyId: z.string().uuid() });

export async function registerHealthRoutes(app: FastifyInstance, options: { pool: DatabasePool; config: AppConfig }) {
  const { pool, config } = options;
  const families = new FamilyRepository(pool);
  const auth = authenticate(config.JWT_SECRET);

  const healthContext = async (request: { sessionUser?: { userId: string } }, familyId: string, subjectMemberId: string, write = false) => {
    const userId = request.sessionUser?.userId ?? (() => { throw unauthorized(); })();
    const actor = await families.requireMembership(userId, familyId, 'family:read');
    const subject = await pool.query('SELECT id FROM family_members WHERE id=$1 AND family_id=$2 AND removed_at IS NULL', [subjectMemberId,familyId]);
    if (!subject.rowCount) throw notFound('健康档案成员不存在');
    if (actor.role === 'admin' || actor.id === subjectMemberId) return { userId, actor };
    const grant = await pool.query(
      `SELECT can_write FROM health_access_grants WHERE family_id=$1 AND subject_member_id=$2 AND grantee_member_id=$3
       AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at > now())`, [familyId,subjectMemberId,actor.id]);
    if (!grant.rowCount || (write && !grant.rows[0].can_write)) throw forbidden('该健康档案未向你开放');
    return { userId, actor };
  };

  app.post('/api/v1/families/:familyId/health/access-grants',{preHandler:auth},async(request,reply)=>{const{familyId}=familyParams.parse(request.params);const userId=request.sessionUser?.userId??(()=>{throw unauthorized();})();const actor=await families.requireMembership(userId,familyId,'member:manage');const body=z.object({subjectMemberId:z.string().uuid(),granteeMemberId:z.string().uuid(),canWrite:z.boolean().default(false),expiresAt:z.string().datetime().optional()}).refine(v=>v.subjectMemberId!==v.granteeMemberId,'不能向本人重复授权').parse(request.body);const members=await pool.query('SELECT id FROM family_members WHERE family_id=$1 AND id=ANY($2::uuid[]) AND removed_at IS NULL',[familyId,[body.subjectMemberId,body.granteeMemberId]]);if(members.rowCount!==2)throw notFound('授权成员不存在');const result=await pool.query(`INSERT INTO health_access_grants(family_id,subject_member_id,grantee_member_id,can_write,granted_by_member_id,expires_at) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(subject_member_id,grantee_member_id) DO UPDATE SET can_write=EXCLUDED.can_write,granted_by_member_id=EXCLUDED.granted_by_member_id,expires_at=EXCLUDED.expires_at,revoked_at=NULL RETURNING id,subject_member_id AS "subjectMemberId",grantee_member_id AS "granteeMemberId",can_write AS "canWrite",expires_at AS "expiresAt"`,[familyId,body.subjectMemberId,body.granteeMemberId,body.canWrite,actor.id,body.expiresAt??null]);await pool.query(`INSERT INTO audit_logs(family_id,actor_user_id,action,resource_type,resource_id) VALUES($1,$2,'health.access_granted','health_access_grant',$3)`,[familyId,userId,result.rows[0].id]);reply.code(201);return{data:result.rows[0]};});

  app.put('/api/v1/families/:familyId/health/profiles/:memberId', { preHandler: auth }, async (request) => {
    const { familyId } = familyParams.parse(request.params);
    const memberId = z.object({ memberId: z.string().uuid() }).parse(request.params).memberId;
    const { userId, actor } = await healthContext(request, familyId, memberId, true);
    const body = z.object({ bloodType: z.string().max(10).optional(), allergies: z.string().max(4000).optional(), chronicConditions: z.string().max(4000).optional(), surgeryHistory: z.string().max(4000).optional(), emergencyContact: z.string().max(200).optional() }).parse(request.body);
    const result = await pool.query(
      `INSERT INTO health_profiles(family_id,member_id,blood_type,allergies,chronic_conditions,surgery_history,emergency_contact,updated_by_member_id)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(family_id,member_id) DO UPDATE SET blood_type=EXCLUDED.blood_type,
       allergies=EXCLUDED.allergies,chronic_conditions=EXCLUDED.chronic_conditions,surgery_history=EXCLUDED.surgery_history,
       emergency_contact=EXCLUDED.emergency_contact,updated_by_member_id=EXCLUDED.updated_by_member_id,updated_at=now()
       RETURNING member_id AS "memberId",blood_type AS "bloodType",allergies,chronic_conditions AS "chronicConditions",surgery_history AS "surgeryHistory",emergency_contact AS "emergencyContact",updated_at AS "updatedAt"`,
      [familyId,memberId,body.bloodType ?? null,body.allergies ?? null,body.chronicConditions ?? null,body.surgeryHistory ?? null,body.emergencyContact ?? null,actor.id]);
    await pool.query(`INSERT INTO audit_logs(family_id,actor_user_id,action,resource_type,resource_id) VALUES($1,$2,'health.profile_updated','health_profile',$3)`, [familyId,userId,memberId]);
    return { data: result.rows[0] };
  });

  app.get('/api/v1/families/:familyId/health/profiles/:memberId', { preHandler: auth }, async (request) => {
    const { familyId } = familyParams.parse(request.params); const { memberId } = z.object({ memberId: z.string().uuid() }).parse(request.params);
    await healthContext(request,familyId,memberId);
    const [profile,visits,exams,plans] = await Promise.all([
      pool.query(`SELECT member_id AS "memberId",blood_type AS "bloodType",allergies,chronic_conditions AS "chronicConditions",surgery_history AS "surgeryHistory",emergency_contact AS "emergencyContact",updated_at AS "updatedAt" FROM health_profiles WHERE family_id=$1 AND member_id=$2`,[familyId,memberId]),
      pool.query(`SELECT id,visited_at AS "visitedAt",hospital,department,doctor,symptoms,diagnosis,treatment,follow_up_at AS "followUpAt" FROM health_visits WHERE family_id=$1 AND member_id=$2 ORDER BY visited_at DESC LIMIT 20`,[familyId,memberId]),
      pool.query(`SELECT id,examined_at AS "examinedAt",institution,summary,next_exam_at AS "nextExamAt" FROM health_exams WHERE family_id=$1 AND member_id=$2 ORDER BY examined_at DESC LIMIT 20`,[familyId,memberId]),
      pool.query(`SELECT p.id,p.dose,p.instructions,p.schedule_times AS "scheduleTimes",p.start_date AS "startDate",p.end_date AS "endDate",p.timezone,p.status,p.version,m.name AS "medicationName",m.specification FROM medication_plans p JOIN medications m ON m.id=p.medication_id WHERE p.family_id=$1 AND p.member_id=$2 ORDER BY p.created_at DESC`,[familyId,memberId]),
    ]);
    return { data: { profile: profile.rows[0] ?? null, visits: visits.rows, exams: exams.rows, medicationPlans: plans.rows } };
  });

  app.post('/api/v1/families/:familyId/health/visits', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const body = z.object({ memberId:z.string().uuid(),visitedAt:z.string().datetime(),hospital:z.string().trim().min(1).max(160),department:z.string().max(100).optional(),doctor:z.string().max(100).optional(),symptoms:z.string().max(8000).optional(),diagnosis:z.string().max(8000).optional(),treatment:z.string().max(8000).optional(),followUpAt:z.string().datetime().optional(),transactionId:z.string().uuid().optional() }).parse(request.body);
    const { actor } = await healthContext(request,familyId,body.memberId,true);
    const result = await pool.query(`INSERT INTO health_visits(family_id,member_id,created_by_member_id,visited_at,hospital,department,doctor,symptoms,diagnosis,treatment,follow_up_at,transaction_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id,member_id AS "memberId",visited_at AS "visitedAt",hospital,department,doctor,symptoms,diagnosis,treatment,follow_up_at AS "followUpAt"`,[familyId,body.memberId,actor.id,body.visitedAt,body.hospital,body.department ?? null,body.doctor ?? null,body.symptoms ?? null,body.diagnosis ?? null,body.treatment ?? null,body.followUpAt ?? null,body.transactionId ?? null]);
    if(body.followUpAt){await pool.query(`INSERT INTO notification_jobs(family_id,recipient_member_id,kind,resource_type,resource_id,scheduled_at,title,body,sensitive) VALUES($1,$2,'health.follow_up','health_visit',$3,$4,'复诊提醒','有一项复诊安排即将开始',true)`,[familyId,body.memberId,result.rows[0].id,body.followUpAt]);}
    reply.code(201); return { data: result.rows[0] };
  });

  app.post('/api/v1/families/:familyId/health/exams', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const body = z.object({ memberId:z.string().uuid(),examinedAt:z.string().datetime(),institution:z.string().trim().min(1).max(160),summary:z.string().max(8000).optional(),nextExamAt:z.string().datetime().optional() }).parse(request.body);
    const { actor } = await healthContext(request,familyId,body.memberId,true);
    const result = await pool.query(`INSERT INTO health_exams(family_id,member_id,created_by_member_id,examined_at,institution,summary,next_exam_at) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id,member_id AS "memberId",examined_at AS "examinedAt",institution,summary,next_exam_at AS "nextExamAt"`,[familyId,body.memberId,actor.id,body.examinedAt,body.institution,body.summary ?? null,body.nextExamAt ?? null]);
    reply.code(201); return { data: result.rows[0] };
  });

  app.post('/api/v1/families/:familyId/health/medication-plans', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const body = z.object({ memberId:z.string().uuid(),medicationName:z.string().trim().min(1).max(160),specification:z.string().max(120).optional(),dose:z.string().trim().min(1).max(80),instructions:z.string().max(300).optional(),scheduleTimes:z.array(z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)).min(1).max(12),startDate:z.string().date(),endDate:z.string().date().optional(),timezone:z.string().min(1).max(80).default('Asia/Shanghai'),source:z.enum(['manual','prescription']).default('manual') }).parse(request.body);
    const { actor } = await healthContext(request,familyId,body.memberId,true);
    const client = await pool.connect();
    try { await client.query('BEGIN');
      const medication = await client.query(`INSERT INTO medications(family_id,name,specification) VALUES($1,$2,$3) RETURNING id`,[familyId,body.medicationName,body.specification ?? null]);
      const plan = await client.query(`INSERT INTO medication_plans(family_id,member_id,medication_id,created_by_member_id,dose,instructions,schedule_times,start_date,end_date,timezone,source) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id,member_id AS "memberId",dose,instructions,schedule_times AS "scheduleTimes",start_date AS "startDate",end_date AS "endDate",timezone,status,version`,[familyId,body.memberId,medication.rows[0].id,actor.id,body.dose,body.instructions ?? null,JSON.stringify(body.scheduleTimes),body.startDate,body.endDate ?? null,body.timezone,body.source]);
      await client.query(`INSERT INTO notification_jobs(family_id,recipient_member_id,kind,resource_type,resource_id,scheduled_at,title,body,sensitive)
       SELECT $1,$2,'medication.due','medication_plan',$3,(day::date + reminder_time::time) AT TIME ZONE $4,'用药提醒','有一项用药计划需要确认',true
       FROM generate_series($5::date,LEAST(COALESCE($6::date,$5::date+30),$5::date+30),'1 day') day
       CROSS JOIN jsonb_array_elements_text($7::jsonb) reminder_time`,[familyId,body.memberId,plan.rows[0].id,body.timezone,body.startDate,body.endDate??null,JSON.stringify(body.scheduleTimes)]);
      await client.query('COMMIT'); reply.code(201); return { data:{...plan.rows[0],medicationName:body.medicationName,specification:body.specification ?? null} };
    } catch(error){ await client.query('ROLLBACK'); throw error; } finally { client.release(); }
  });

  app.post('/api/v1/families/:familyId/health/medication-logs', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const body = z.object({ planId:z.string().uuid(),scheduledAt:z.string().datetime(),actualAt:z.string().datetime().optional(),status:z.enum(['taken','skipped','missed']),reason:z.string().max(240).optional(),clientOperationId:z.string().min(8).max(100) }).parse(request.body);
    const plan = await pool.query('SELECT member_id FROM medication_plans WHERE id=$1 AND family_id=$2',[body.planId,familyId]); if(!plan.rowCount) throw notFound('用药计划不存在');
    const { actor } = await healthContext(request,familyId,plan.rows[0].member_id,true);
    const result = await pool.query(`INSERT INTO medication_logs(family_id,plan_id,scheduled_at,actual_at,status,confirmed_by_member_id,reason,client_operation_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(family_id,client_operation_id) DO UPDATE SET client_operation_id=EXCLUDED.client_operation_id RETURNING id,plan_id AS "planId",scheduled_at AS "scheduledAt",actual_at AS "actualAt",status,confirmed_by_member_id AS "confirmedByMemberId",reason`,[familyId,body.planId,body.scheduledAt,body.actualAt ?? (body.status==='taken'?new Date():null),body.status,actor.id,body.reason ?? null,body.clientOperationId]);
    reply.code(201); return { data: result.rows[0] };
  });
}
