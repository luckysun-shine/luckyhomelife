import { createHash, randomBytes, randomInt } from 'node:crypto';
import type { PoolClient } from 'pg';
import type { DatabasePool } from '../../database/pool.js';
import { AppError, conflict, forbidden, notFound } from '../../errors.js';
import type { FamilyRole } from '../../types.js';
import { can, type FamilyAction } from './permissions.js';

export class FamilyRepository {
  constructor(private readonly pool: DatabasePool) {}

  async upsertDevUser(phone: string, displayName: string) {
    const result = await this.pool.query(
      `INSERT INTO users(phone, display_name) VALUES($1, $2)
       ON CONFLICT(phone) DO UPDATE SET display_name = EXCLUDED.display_name, updated_at = now()
       RETURNING id, phone, display_name AS "displayName"`,
      [phone, displayName],
    );
    return result.rows[0] as { id: string; phone: string; displayName: string };
  }

  async createLoginCode(phone:string,secret:string){
    const recent=await this.pool.query(`SELECT count(*)::int AS count FROM login_codes WHERE phone=$1 AND created_at>now()-interval '10 minutes'`,[phone]);
    if(recent.rows[0].count>=5)throw new AppError(429,'TOO_MANY_REQUESTS','验证码请求过于频繁，请稍后再试');
    const code=randomInt(100000,1000000).toString();const hash=createHash('sha256').update(`${phone}:${code}:${secret}`).digest('hex');
    await this.pool.query(`INSERT INTO login_codes(phone,code_hash,expires_at) VALUES($1,$2,now()+interval '5 minutes')`,[phone,hash]);return code;
  }

  async verifyLoginCode(phone:string,code:string,displayName:string,secret:string){
    const client=await this.pool.connect();try{await client.query('BEGIN');const result=await client.query(`SELECT id,code_hash,attempts FROM login_codes WHERE phone=$1 AND consumed_at IS NULL AND expires_at>now() ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,[phone]);const challenge=result.rows[0];if(!challenge)throw new AppError(400,'CODE_INVALID','验证码无效或已过期');if(challenge.attempts>=5)throw new AppError(429,'CODE_LOCKED','验证码尝试次数过多，请重新获取');const hash=createHash('sha256').update(`${phone}:${code}:${secret}`).digest('hex');if(hash!==challenge.code_hash){await client.query('UPDATE login_codes SET attempts=attempts+1 WHERE id=$1',[challenge.id]);await client.query('COMMIT');throw new AppError(400,'CODE_INVALID','验证码不正确');}await client.query('UPDATE login_codes SET consumed_at=now() WHERE id=$1',[challenge.id]);const user=await client.query(`INSERT INTO users(phone,display_name) VALUES($1,$2) ON CONFLICT(phone) DO UPDATE SET display_name=COALESCE(NULLIF(users.display_name,''),EXCLUDED.display_name),updated_at=now() RETURNING id,phone,display_name AS "displayName"`,[phone,displayName]);await client.query('COMMIT');return user.rows[0] as{id:string;phone:string;displayName:string};}catch(error){if((error as AppError).code!=='CODE_INVALID'||(error as AppError).message!=='验证码不正确')await client.query('ROLLBACK');throw error;}finally{client.release();}
  }

  async listFamilies(userId: string) {
    const result = await this.pool.query(
      `SELECT f.id, f.name, fm.id AS "memberId", fm.display_name AS "memberName", fm.role
       FROM family_members fm JOIN families f ON f.id = fm.family_id
       WHERE fm.user_id = $1 AND fm.removed_at IS NULL AND f.deleted_at IS NULL
       ORDER BY f.created_at`,
      [userId],
    );
    return result.rows;
  }

  async createFamily(userId: string, name: string, memberName: string) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const family = await client.query(
        'INSERT INTO families(name, owner_user_id) VALUES($1, $2) RETURNING id, name, created_at AS "createdAt"',
        [name, userId],
      );
      const member = await client.query(
        `INSERT INTO family_members(family_id, user_id, display_name, role)
         VALUES($1, $2, $3, 'admin') RETURNING id, display_name AS "displayName", role`,
        [family.rows[0].id, userId, memberName],
      );
      await this.audit(client, family.rows[0].id, userId, 'family.created', 'family', family.rows[0].id);
      await client.query('COMMIT');
      return { ...family.rows[0], currentMember: member.rows[0] };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async requireMembership(userId: string, familyId: string, action: FamilyAction) {
    const result = await this.pool.query(
      `SELECT id, family_id AS "familyId", display_name AS "displayName", role
       FROM family_members WHERE family_id = $1 AND user_id = $2 AND removed_at IS NULL`,
      [familyId, userId],
    );
    const member = result.rows[0] as { id: string; familyId: string; displayName: string; role: FamilyRole } | undefined;
    if (!member) throw notFound('家庭不存在或你不是该家庭成员');
    if (!can(member.role, action)) throw forbidden();
    return member;
  }

  async listMembers(userId: string, familyId: string) {
    await this.requireMembership(userId, familyId, 'member:read');
    const result = await this.pool.query(
      `SELECT id, display_name AS "displayName", role, user_id IS NOT NULL AS "accountBound",
              guardian_member_id AS "guardianMemberId", joined_at AS "joinedAt"
       FROM family_members WHERE family_id = $1 AND removed_at IS NULL ORDER BY joined_at`,
      [familyId],
    );
    return result.rows;
  }

  async createManagedMember(userId:string,familyId:string,displayName:string,role:'child'|'teen'|'elder',guardianMemberId?:string){
    const actor=await this.requireMembership(userId,familyId,'member:manage');
    if((role==='child'||role==='teen')&&!guardianMemberId)guardianMemberId=actor.id;
    if(guardianMemberId){const guardian=await this.pool.query(`SELECT role FROM family_members WHERE id=$1 AND family_id=$2 AND removed_at IS NULL`,[guardianMemberId,familyId]);if(!guardian.rowCount||!['admin','adult'].includes(guardian.rows[0].role))throw notFound('监护人不存在或身份不适用');}
    const result=await this.pool.query(`INSERT INTO family_members(family_id,display_name,role,guardian_member_id) VALUES($1,$2,$3,$4) RETURNING id,display_name AS "displayName",role,guardian_member_id AS "guardianMemberId",false AS "accountBound"`,[familyId,displayName,role,guardianMemberId??null]);
    await this.pool.query(`INSERT INTO audit_logs(family_id,actor_user_id,action,resource_type,resource_id) VALUES($1,$2,'member.profile_created','family_member',$3)`,[familyId,userId,result.rows[0].id]);return result.rows[0];
  }

  async updateMember(
    userId: string,
    familyId: string,
    memberId: string,
    input: { displayName?: string; role?: Exclude<FamilyRole, 'admin'>; guardianMemberId?: string | null },
  ) {
    await this.requireMembership(userId, familyId, 'member:manage');
    const target = await this.pool.query(
      `SELECT id, role FROM family_members
       WHERE id=$1 AND family_id=$2 AND removed_at IS NULL`,
      [memberId, familyId],
    );
    if (!target.rowCount) throw notFound('家庭成员不存在');
    if (target.rows[0].role === 'admin' && input.role) {
      throw forbidden('请使用管理员交接功能变更管理员身份');
    }
    if (input.guardianMemberId) {
      const guardian = await this.pool.query(
        `SELECT role FROM family_members
         WHERE id=$1 AND family_id=$2 AND removed_at IS NULL`,
        [input.guardianMemberId, familyId],
      );
      if (!guardian.rowCount || !['admin', 'adult'].includes(guardian.rows[0].role)) {
        throw notFound('监护人不存在或身份不适用');
      }
    }
    const result = await this.pool.query(
      `UPDATE family_members SET
         display_name=COALESCE($3,display_name),
         role=COALESCE($4,role),
         guardian_member_id=CASE WHEN $5 THEN $6 ELSE guardian_member_id END
       WHERE id=$1 AND family_id=$2 AND removed_at IS NULL
       RETURNING id,display_name AS "displayName",role,
                 guardian_member_id AS "guardianMemberId",user_id IS NOT NULL AS "accountBound"`,
      [memberId, familyId, input.displayName ?? null, input.role ?? null,
        Object.hasOwn(input, 'guardianMemberId'), input.guardianMemberId ?? null],
    );
    await this.pool.query(
      `INSERT INTO audit_logs(family_id,actor_user_id,action,resource_type,resource_id)
       VALUES($1,$2,'member.updated','family_member',$3)`,
      [familyId, userId, memberId],
    );
    return result.rows[0];
  }

  async removeMember(userId: string, familyId: string, memberId: string) {
    const actor = await this.requireMembership(userId, familyId, 'member:manage');
    if (actor.id === memberId) throw forbidden('管理员不能移除自己，请先交接管理员');
    const target = await this.pool.query(
      `SELECT role FROM family_members WHERE id=$1 AND family_id=$2 AND removed_at IS NULL`,
      [memberId, familyId],
    );
    if (!target.rowCount) throw notFound('家庭成员不存在');
    if (target.rows[0].role === 'admin') throw forbidden('不能直接移除管理员');
    await this.pool.query(
      `UPDATE family_members SET removed_at=now() WHERE id=$1 AND family_id=$2`,
      [memberId, familyId],
    );
    await this.pool.query(
      `UPDATE family_members SET guardian_member_id=NULL
       WHERE family_id=$1 AND guardian_member_id=$2 AND removed_at IS NULL`,
      [familyId, memberId],
    );
    await this.pool.query(
      `INSERT INTO audit_logs(family_id,actor_user_id,action,resource_type,resource_id)
       VALUES($1,$2,'member.removed','family_member',$3)`,
      [familyId, userId, memberId],
    );
  }

  async transferAdmin(userId: string, familyId: string, targetMemberId: string) {
    const actor = await this.requireMembership(userId, familyId, 'member:manage');
    if (actor.id === targetMemberId) throw conflict('你已经是家庭管理员');
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const target = await client.query(
        `SELECT id,user_id AS "userId" FROM family_members
         WHERE id=$1 AND family_id=$2 AND removed_at IS NULL FOR UPDATE`,
        [targetMemberId, familyId],
      );
      if (!target.rowCount) throw notFound('目标成员不存在');
      if (!target.rows[0].userId) throw forbidden('管理员只能交接给已登录并加入家庭的成员');
      await client.query(`UPDATE family_members SET role='adult' WHERE id=$1`, [actor.id]);
      await client.query(`UPDATE family_members SET role='admin' WHERE id=$1`, [targetMemberId]);
      await client.query(`UPDATE families SET owner_user_id=$1,updated_at=now() WHERE id=$2`, [target.rows[0].userId, familyId]);
      await this.audit(client, familyId, userId, 'family.admin_transferred', 'family_member', targetMemberId);
      await client.query('COMMIT');
      return { previousAdminMemberId: actor.id, adminMemberId: targetMemberId };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async createInvite(userId: string, familyId: string, role: FamilyRole, expiresInHours: number) {
    const member = await this.requireMembership(userId, familyId, 'member:invite');
    if (role === 'admin') throw forbidden('邀请时不能直接授予管理员角色');
    const code = randomBytes(6).toString('base64url').toUpperCase();
    const codeHash = this.hashInvite(code);
    const result = await this.pool.query(
      `INSERT INTO family_invites(family_id, code_hash, role, invited_by_member_id, expires_at)
       VALUES($1, $2, $3, $4, now() + ($5 || ' hours')::interval)
       RETURNING id, role, expires_at AS "expiresAt"`,
      [familyId, codeHash, role, member.id, expiresInHours],
    );
    await this.pool.query(
      `INSERT INTO audit_logs(family_id, actor_user_id, action, resource_type, resource_id)
       VALUES($1, $2, 'member.invite_created', 'family_invite', $3)`,
      [familyId, userId, result.rows[0].id],
    );
    return { ...result.rows[0], code };
  }

  async acceptInvite(userId: string, code: string, displayName: string) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const inviteResult = await client.query(
        `SELECT id, family_id AS "familyId", role FROM family_invites
         WHERE code_hash = $1 AND accepted_at IS NULL AND expires_at > now() FOR UPDATE`,
        [this.hashInvite(code)],
      );
      const invite = inviteResult.rows[0] as { id: string; familyId: string; role: FamilyRole } | undefined;
      if (!invite) throw notFound('邀请码无效或已过期');
      const existing = await client.query(
        'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2 AND removed_at IS NULL',
        [invite.familyId, userId],
      );
      if (existing.rowCount) throw conflict('你已经是该家庭成员');
      const member = await client.query(
        `INSERT INTO family_members(family_id, user_id, display_name, role)
         VALUES($1, $2, $3, $4) RETURNING id, family_id AS "familyId", display_name AS "displayName", role`,
        [invite.familyId, userId, displayName, invite.role],
      );
      await client.query(
        'UPDATE family_invites SET accepted_at = now(), accepted_by_user_id = $1 WHERE id = $2',
        [userId, invite.id],
      );
      await this.audit(client, invite.familyId, userId, 'member.invite_accepted', 'family_member', member.rows[0].id);
      await client.query('COMMIT');
      return member.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private hashInvite(code: string) {
    return createHash('sha256').update(code.trim().toUpperCase()).digest('hex');
  }

  private async audit(
    client: PoolClient,
    familyId: string,
    actorUserId: string,
    action: string,
    resourceType: string,
    resourceId: string,
  ) {
    await client.query(
      `INSERT INTO audit_logs(family_id, actor_user_id, action, resource_type, resource_id)
       VALUES($1, $2, $3, $4, $5)`,
      [familyId, actorUserId, action, resourceType, resourceId],
    );
  }
}
