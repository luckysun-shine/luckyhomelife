import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppConfig } from '../../config.js';
import { authenticate } from '../../auth.js';
import { unauthorized } from '../../errors.js';
import { CollaborationRepository } from './repository.js';

const familyParams = z.object({ familyId: z.string().uuid() });
const taskParams = z.object({ familyId: z.string().uuid(), taskId: z.string().uuid() });
const eventParams = z.object({ familyId: z.string().uuid(), eventId: z.string().uuid() });

export async function registerCollaborationRoutes(app: FastifyInstance, options: { repository: CollaborationRepository; config: AppConfig }) {
  const { repository, config } = options;
  const auth = authenticate(config.JWT_SECRET);
  const userId = (request: { sessionUser?: { userId: string } }) => request.sessionUser?.userId ?? (() => { throw unauthorized(); })();

  app.get('/api/v1/families/:familyId/events', { preHandler: auth }, async (request) => {
    const { familyId } = familyParams.parse(request.params);
    const query = z.object({ from: z.string().datetime(), to: z.string().datetime() }).parse(request.query);
    return { data: await repository.listEvents(userId(request), familyId, query.from, query.to) };
  });

  app.post('/api/v1/families/:familyId/events', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const body = z.object({
      title: z.string().trim().min(1).max(160), startsAt: z.string().datetime(), endsAt: z.string().datetime(),
      allDay: z.boolean().default(false), location: z.string().trim().max(240).optional(), notes: z.string().max(4000).optional(),
      participantMemberIds: z.array(z.string().uuid()).max(30).default([]), reminderMinutes: z.number().int().min(0).max(10080).optional(),
      clientOperationId:z.string().min(8).max(100),
    }).refine((value) => new Date(value.endsAt) >= new Date(value.startsAt), { message: '结束时间不能早于开始时间' }).parse(request.body);
    reply.code(201);
    return { data: await repository.createEvent(userId(request), familyId, body) };
  });

  app.patch('/api/v1/families/:familyId/events/:eventId', { preHandler: auth }, async request => {
    const { familyId, eventId } = eventParams.parse(request.params);
    const body = z.object({
      title:z.string().trim().min(1).max(160),startsAt:z.string().datetime(),endsAt:z.string().datetime(),
      allDay:z.boolean(),location:z.string().trim().max(240).optional(),notes:z.string().max(4000).optional(),
      expectedVersion:z.number().int().positive(),
    }).refine(value=>new Date(value.endsAt)>=new Date(value.startsAt),{message:'结束时间不能早于开始时间'}).parse(request.body);
    return { data: await repository.updateEvent(userId(request), familyId, eventId, body) };
  });

  app.delete('/api/v1/families/:familyId/events/:eventId', { preHandler: auth }, async (request, reply) => {
    const { familyId, eventId } = eventParams.parse(request.params);
    const query = z.object({ expectedVersion:z.coerce.number().int().positive() }).parse(request.query);
    await repository.deleteEvent(userId(request), familyId, eventId, query.expectedVersion);
    reply.code(204).send();
  });

  app.get('/api/v1/families/:familyId/tasks', { preHandler: auth }, async (request) => {
    const { familyId } = familyParams.parse(request.params);
    const query = z.object({ includeCompleted: z.enum(['true', 'false']).default('false') }).parse(request.query);
    return { data: await repository.listTasks(userId(request), familyId, query.includeCompleted === 'true') };
  });

  app.post('/api/v1/families/:familyId/tasks', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const body = z.object({ title: z.string().trim().min(1).max(200), notes: z.string().max(4000).optional(), dueAt: z.string().datetime().optional(), assignedToMemberId: z.string().uuid().optional(), listId: z.string().uuid().optional(),clientOperationId:z.string().min(8).max(100) }).parse(request.body);
    reply.code(201);
    return { data: await repository.createTask(userId(request), familyId, body) };
  });

  app.patch('/api/v1/families/:familyId/tasks/:taskId/completion', { preHandler: auth }, async (request) => {
    const { familyId, taskId } = taskParams.parse(request.params);
    const body = z.object({ completed: z.boolean(), expectedVersion: z.number().int().positive() }).parse(request.body);
    return { data: await repository.setTaskCompletion(userId(request), familyId, taskId, body.completed, body.expectedVersion) };
  });

  app.post('/api/v1/families/:familyId/task-lists', { preHandler: auth }, async (request, reply) => {
    const { familyId } = familyParams.parse(request.params);
    const body = z.object({ title: z.string().trim().min(1).max(120), type: z.enum(['task', 'shopping']) }).parse(request.body);
    reply.code(201);
    return { data: await repository.createList(userId(request), familyId, body.title, body.type) };
  });

  app.get('/api/v1/families/:familyId/today', { preHandler: auth }, async (request) => {
    const { familyId } = familyParams.parse(request.params);
    const query = z.object({ timezone: z.string().min(1).max(80).default('Asia/Shanghai') }).parse(request.query);
    return { data: await repository.today(userId(request), familyId, query.timezone) };
  });
}
