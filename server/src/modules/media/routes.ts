import { createReadStream } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppConfig } from '../../config.js';
import type { DatabasePool } from '../../database/pool.js';
import { authenticate } from '../../auth.js';
import { notFound, unauthorized } from '../../errors.js';
import { FamilyRepository } from '../families/repository.js';

export async function registerMediaRoutes(app: FastifyInstance, options:{pool:DatabasePool;config:AppConfig}){
 const {pool,config}=options;const families=new FamilyRepository(pool);const auth=authenticate(config.JWT_SECRET);const mediaRoot=resolve(config.MEDIA_ROOT);
 app.addContentTypeParser('application/octet-stream',{parseAs:'buffer',bodyLimit:20*1024*1024},(_request,body,done)=>done(null,body));
 app.post('/api/v1/families/:familyId/media',{preHandler:auth},async(request,reply)=>{
  const {familyId}=z.object({familyId:z.string().uuid()}).parse(request.params);const userId=request.sessionUser?.userId??(()=>{throw unauthorized();})();await families.requireMembership(userId,familyId,'family:read');
  const query=z.object({recordId:z.string().uuid().optional(),mimeType:z.enum(['image/jpeg','image/png','image/webp','application/pdf']),sha256:z.string().length(64).optional()}).parse(request.query);
  const body=request.body;if(!Buffer.isBuffer(body)||body.length===0)throw new Error('上传内容为空');
  const extension:{[key:string]:string}={'image/jpeg':'jpg','image/png':'png','image/webp':'webp','application/pdf':'pdf'};const id=randomUUID();const relative=join(familyId,id.slice(0,2),`${id}.${extension[query.mimeType]}`);const target=resolve(mediaRoot,relative);if(!target.startsWith(mediaRoot))throw new Error('非法存储路径');await mkdir(dirname(target),{recursive:true});await writeFile(target,body,{flag:'wx'});
  const result=await pool.query(`INSERT INTO media_assets(id,family_id,record_id,storage_key,mime_type,size_bytes,sha256,upload_status) VALUES($1,$2,$3,$4,$5,$6,$7,'ready') RETURNING id,record_id AS "recordId",mime_type AS "mimeType",size_bytes AS "sizeBytes",created_at AS "createdAt"`,[id,familyId,query.recordId??null,relative,query.mimeType,body.length,query.sha256??null]);reply.code(201);return{data:result.rows[0]};
 });
 app.get('/api/v1/families/:familyId/media/:mediaId',{preHandler:auth},async(request,reply)=>{const {familyId,mediaId}=z.object({familyId:z.string().uuid(),mediaId:z.string().uuid()}).parse(request.params);const userId=request.sessionUser?.userId??(()=>{throw unauthorized();})();const member=await families.requireMembership(userId,familyId,'family:read');const result=await pool.query(`SELECT a.storage_key,a.mime_type FROM media_assets a LEFT JOIN family_records r ON r.id=a.record_id
   WHERE a.id=$1 AND a.family_id=$2 AND a.upload_status='ready' AND (a.record_id IS NULL OR r.visibility='family' OR r.created_by_member_id=$3
    OR (r.visibility='admins' AND $4='admin') OR (r.visibility='selected' AND EXISTS(SELECT 1 FROM record_viewers rv WHERE rv.record_id=r.id AND rv.member_id=$3))
    OR (r.visibility='guardians' AND EXISTS(SELECT 1 FROM record_members rm JOIN family_members child ON child.id=rm.member_id WHERE rm.record_id=r.id AND child.guardian_member_id=$3)))`,[mediaId,familyId,member.id,member.role]);if(!result.rowCount)throw notFound('文件不存在或不可访问');const target=resolve(mediaRoot,result.rows[0].storage_key);if(!target.startsWith(mediaRoot))throw notFound();reply.type(result.rows[0].mime_type);return reply.send(createReadStream(target));});
}
