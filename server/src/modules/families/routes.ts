import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppConfig } from '../../config.js';
import { AppError, unauthorized } from '../../errors.js';
import { createAccessToken, authenticate } from '../../auth.js';
import { familyRoles } from '../../types.js';
import { FamilyRepository } from './repository.js';

const idParams = z.object({ familyId: z.string().uuid() });
const memberParams = idParams.extend({ memberId: z.string().uuid() });

export async function registerFamilyRoutes(app: FastifyInstance, options: { repository: FamilyRepository; config: AppConfig }) {
  const { repository, config } = options;
  const auth = authenticate(config.JWT_SECRET);

  app.post('/api/v1/auth/request-code', async (request, reply) => {
    const body=z.object({phone:z.string().regex(/^\+?[0-9]{6,20}$/)}).parse(request.body);const code=await repository.createLoginCode(body.phone,config.JWT_SECRET);
    if(config.NODE_ENV==='production'){
      if(!config.SMS_WEBHOOK_URL)throw new AppError(503,'SMS_NOT_CONFIGURED','短信服务尚未配置');
      const response=await fetch(config.SMS_WEBHOOK_URL,{method:'POST',headers:{'content-type':'application/json',...(config.SMS_WEBHOOK_TOKEN?{authorization:`Bearer ${config.SMS_WEBHOOK_TOKEN}`}:{})},body:JSON.stringify({phone:body.phone,code,template:'family_os_login',expiresInMinutes:5})});
      if(!response.ok)throw new AppError(502,'SMS_SEND_FAILED','验证码发送失败，请稍后重试');
    }
    reply.code(202);return{data:{expiresInSeconds:300,...(config.NODE_ENV==='development'&&config.ALLOW_DEV_LOGIN?{debugCode:code}:{})}};
  });

  app.post('/api/v1/auth/verify-code',async request=>{const body=z.object({phone:z.string().regex(/^\+?[0-9]{6,20}$/),code:z.string().regex(/^\d{6}$/),displayName:z.string().trim().min(1).max(80)}).parse(request.body);const user=await repository.verifyLoginCode(body.phone,body.code,body.displayName,config.JWT_SECRET);const accessToken=await createAccessToken({userId:user.id,phone:user.phone},config.JWT_SECRET);return{data:{user,accessToken}};});

  app.post('/api/v1/auth/dev-login', async (request) => {
    if (!config.ALLOW_DEV_LOGIN || config.NODE_ENV === 'production') {
      throw new AppError(404, 'NOT_FOUND', '接口不存在');
    }
    const body = z.object({ phone: z.string().min(6).max(32), displayName: z.string().min(1).max(80) }).parse(request.body);
    const user = await repository.upsertDevUser(body.phone, body.displayName);
    const accessToken = await createAccessToken({ userId: user.id, phone: user.phone }, config.JWT_SECRET);
    return { data: { user, accessToken } };
  });

  app.get('/api/v1/families', { preHandler: auth }, async (request) => {
    const user = request.sessionUser ?? (() => { throw unauthorized(); })();
    return { data: await repository.listFamilies(user.userId) };
  });

  app.post('/api/v1/families', { preHandler: auth }, async (request, reply) => {
    const user = request.sessionUser ?? (() => { throw unauthorized(); })();
    const body = z.object({ name: z.string().trim().min(1).max(80), memberName: z.string().trim().min(1).max(80) }).parse(request.body);
    const data = await repository.createFamily(user.userId, body.name, body.memberName);
    reply.code(201);
    return { data };
  });

  app.get('/api/v1/families/:familyId/members', { preHandler: auth }, async (request) => {
    const user = request.sessionUser ?? (() => { throw unauthorized(); })();
    const { familyId } = idParams.parse(request.params);
    return { data: await repository.listMembers(user.userId, familyId) };
  });

  app.post('/api/v1/families/:familyId/member-profiles',{preHandler:auth},async(request,reply)=>{const user=request.sessionUser??(()=>{throw unauthorized();})();const{familyId}=idParams.parse(request.params);const body=z.object({displayName:z.string().trim().min(1).max(80),role:z.enum(['child','teen','elder']),guardianMemberId:z.string().uuid().optional()}).parse(request.body);reply.code(201);return{data:await repository.createManagedMember(user.userId,familyId,body.displayName,body.role,body.guardianMemberId)};});

  app.patch('/api/v1/families/:familyId/members/:memberId',{preHandler:auth},async request=>{const user=request.sessionUser??(()=>{throw unauthorized();})();const{familyId,memberId}=memberParams.parse(request.params);const body=z.object({displayName:z.string().trim().min(1).max(80).optional(),role:z.enum(['adult','elder','teen','child','caregiver']).optional(),guardianMemberId:z.string().uuid().nullable().optional()}).refine(value=>Object.keys(value).length>0,'至少提交一个修改字段').parse(request.body);return{data:await repository.updateMember(user.userId,familyId,memberId,body)};});

  app.delete('/api/v1/families/:familyId/members/:memberId',{preHandler:auth},async(request,reply)=>{const user=request.sessionUser??(()=>{throw unauthorized();})();const{familyId,memberId}=memberParams.parse(request.params);await repository.removeMember(user.userId,familyId,memberId);reply.code(204).send();});

  app.post('/api/v1/families/:familyId/admin-transfer',{preHandler:auth},async request=>{const user=request.sessionUser??(()=>{throw unauthorized();})();const{familyId}=idParams.parse(request.params);const body=z.object({targetMemberId:z.string().uuid()}).parse(request.body);return{data:await repository.transferAdmin(user.userId,familyId,body.targetMemberId)};});

  app.post('/api/v1/families/:familyId/invites', { preHandler: auth }, async (request, reply) => {
    const user = request.sessionUser ?? (() => { throw unauthorized(); })();
    const { familyId } = idParams.parse(request.params);
    const body = z.object({
      role: z.enum(familyRoles).exclude(['admin']),
      expiresInHours: z.number().int().min(1).max(168).default(48),
    }).parse(request.body);
    const data = await repository.createInvite(user.userId, familyId, body.role, body.expiresInHours);
    reply.code(201);
    return { data };
  });

  app.post('/api/v1/invites/accept', { preHandler: auth }, async (request) => {
    const user = request.sessionUser ?? (() => { throw unauthorized(); })();
    const body = z.object({ code: z.string().min(4).max(32), displayName: z.string().trim().min(1).max(80) }).parse(request.body);
    return { data: await repository.acceptInvite(user.userId, body.code, body.displayName) };
  });
}
