import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { ZodError } from 'zod';
import type { AppConfig } from './config.js';
import type { DatabasePool } from './database/pool.js';
import { AppError } from './errors.js';
import { FamilyRepository } from './modules/families/repository.js';
import { registerFamilyRoutes } from './modules/families/routes.js';
import { CollaborationRepository } from './modules/collaboration/repository.js';
import { registerCollaborationRoutes } from './modules/collaboration/routes.js';
import { registerLedgerRoutes } from './modules/ledger/routes.js';
import { registerRecordRoutes } from './modules/records/routes.js';
import { registerHealthRoutes } from './modules/health/routes.js';
import { registerMediaRoutes } from './modules/media/routes.js';
import { registerNotificationRoutes } from './modules/notifications/routes.js';

export async function buildApp(config: AppConfig, pool: DatabasePool) {
  const app = Fastify({ logger: { redact: ['req.headers.authorization', 'req.body.phone'] } });
  await app.register(helmet);
  await app.register(cors, { origin: config.APP_ORIGIN, credentials: true });
  await app.register(rateLimit, { max: 120, timeWindow: '1 minute' });

  app.get('/health', async () => {
    await pool.query('SELECT 1');
    return { status: 'ok', timestamp: new Date().toISOString() };
  });

  await registerFamilyRoutes(app, { repository: new FamilyRepository(pool), config });
  await registerCollaborationRoutes(app, { repository: new CollaborationRepository(pool), config });
  await registerLedgerRoutes(app, { pool, config });
  await registerRecordRoutes(app, { pool, config });
  await registerHealthRoutes(app, { pool, config });
  await registerMediaRoutes(app, { pool, config });
  await registerNotificationRoutes(app, { pool, config });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof ZodError) {
      return reply.code(400).send({ error: { code: 'VALIDATION_ERROR', message: '提交内容不完整或格式不正确', details: error.flatten() }, requestId: request.id });
    }
    if (error instanceof AppError) {
      return reply.code(error.statusCode).send({ error: { code: error.code, message: error.message, details: error.details }, requestId: request.id });
    }
    request.log.error(error);
    return reply.code(500).send({ error: { code: 'INTERNAL_ERROR', message: '服务暂时不可用，请稍后重试' }, requestId: request.id });
  });

  return app;
}
