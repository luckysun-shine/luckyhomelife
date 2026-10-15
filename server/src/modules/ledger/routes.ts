import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppConfig } from '../../config.js';
import type { DatabasePool } from '../../database/pool.js';
import { authenticate } from '../../auth.js';
import { unauthorized, notFound } from '../../errors.js';
import { FamilyRepository } from '../families/repository.js';

const paramsSchema = z.object({ familyId: z.string().uuid() });

export async function registerLedgerRoutes(app: FastifyInstance, options: { pool: DatabasePool; config: AppConfig }) {
  const { pool, config } = options;
  const families = new FamilyRepository(pool);
  const auth = authenticate(config.JWT_SECRET);
  const actor = async (request: { sessionUser?: { userId: string } }, familyId: string) => {
    const userId = request.sessionUser?.userId ?? (() => { throw unauthorized(); })();
    return { userId, member: await families.requireMembership(userId, familyId, 'family:read') };
  };

  app.get('/api/v1/families/:familyId/ledgers', { preHandler: auth }, async (request) => {
    const { familyId } = paramsSchema.parse(request.params);
    const { member } = await actor(request, familyId);
    const result = await pool.query(
      `SELECT id,name,is_personal AS "isPersonal",owner_member_id AS "ownerMemberId" FROM ledgers
       WHERE family_id=$1 AND (NOT is_personal OR owner_member_id=$2) ORDER BY created_at`, [familyId, member.id]);
    return { data: result.rows };
  });

  app.post('/api/v1/families/:familyId/ledgers', { preHandler: auth }, async (request, reply) => {
    const { familyId } = paramsSchema.parse(request.params);
    const { member } = await actor(request, familyId);
    const body = z.object({ name: z.string().trim().min(1).max(100), isPersonal: z.boolean().default(false) }).parse(request.body);
    const result = await pool.query(
      `INSERT INTO ledgers(family_id,name,is_personal,owner_member_id) VALUES($1,$2,$3,$4)
       RETURNING id,name,is_personal AS "isPersonal",owner_member_id AS "ownerMemberId"`,
      [familyId, body.name, body.isPersonal, body.isPersonal ? member.id : null]);
    reply.code(201); return { data: result.rows[0] };
  });

  app.post('/api/v1/families/:familyId/transactions', { preHandler: auth }, async (request, reply) => {
    const { familyId } = paramsSchema.parse(request.params);
    const { member } = await actor(request, familyId);
    const body = z.object({
      ledgerId: z.string().uuid(), type: z.enum(['expense','income','refund','reimbursement']),
      amountMinor: z.number().int().positive().max(999999999999), currency: z.string().length(3).default('CNY'),
      category: z.string().trim().min(1).max(80), occurredAt: z.string().datetime(), note: z.string().max(500).optional(),
      payerMemberId: z.string().uuid().optional(), idempotencyKey: z.string().min(8).max(100),
    }).parse(request.body);
    const ledger = await pool.query('SELECT is_personal,owner_member_id FROM ledgers WHERE id=$1 AND family_id=$2', [body.ledgerId, familyId]);
    if (!ledger.rowCount || (ledger.rows[0].is_personal && ledger.rows[0].owner_member_id !== member.id)) throw notFound('账本不存在或不可访问');
    const result = await pool.query(
      `INSERT INTO transactions(family_id,ledger_id,created_by_member_id,payer_member_id,type,amount_minor,currency,category,occurred_at,note,idempotency_key)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT(family_id,idempotency_key) DO UPDATE SET idempotency_key=EXCLUDED.idempotency_key
       RETURNING id,ledger_id AS "ledgerId",type,amount_minor AS "amountMinor",currency,category,occurred_at AS "occurredAt",note,version`,
      [familyId,body.ledgerId,member.id,body.payerMemberId ?? member.id,body.type,body.amountMinor,body.currency.toUpperCase(),body.category,body.occurredAt,body.note ?? null,body.idempotencyKey]);
    reply.code(201); return { data: result.rows[0] };
  });

  app.get('/api/v1/families/:familyId/transactions', { preHandler: auth }, async (request) => {
    const { familyId } = paramsSchema.parse(request.params);
    const { member } = await actor(request, familyId);
    const query = z.object({ from: z.string().datetime(), to: z.string().datetime(), ledgerId: z.string().uuid().optional() }).parse(request.query);
    const result = await pool.query(
      `SELECT t.id,t.ledger_id AS "ledgerId",t.type,t.amount_minor AS "amountMinor",t.currency,t.category,t.occurred_at AS "occurredAt",t.note,t.version,m.display_name AS "payerName"
       FROM transactions t JOIN ledgers l ON l.id=t.ledger_id LEFT JOIN family_members m ON m.id=t.payer_member_id
       WHERE t.family_id=$1 AND t.deleted_at IS NULL AND t.occurred_at >= $2 AND t.occurred_at < $3
         AND ($4::uuid IS NULL OR t.ledger_id=$4) AND (NOT l.is_personal OR l.owner_member_id=$5)
       ORDER BY t.occurred_at DESC LIMIT 500`, [familyId,query.from,query.to,query.ledgerId ?? null,member.id]);
    return { data: result.rows };
  });

  app.get('/api/v1/families/:familyId/ledger-summary', { preHandler: auth }, async (request) => {
    const { familyId } = paramsSchema.parse(request.params);
    const { member } = await actor(request, familyId);
    const query = z.object({ from: z.string().datetime(), to: z.string().datetime() }).parse(request.query);
    const result = await pool.query(
      `SELECT type,category,SUM(amount_minor)::bigint AS "amountMinor" FROM transactions t JOIN ledgers l ON l.id=t.ledger_id
       WHERE t.family_id=$1 AND t.deleted_at IS NULL AND t.occurred_at >= $2 AND t.occurred_at < $3
         AND (NOT l.is_personal OR l.owner_member_id=$4) GROUP BY type,category ORDER BY type, "amountMinor" DESC`,
      [familyId,query.from,query.to,member.id]);
    return { data: result.rows };
  });
}

