import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(32),
  ALLOW_DEV_LOGIN: z.string().default('false').transform((value) => value === 'true'),
  APP_ORIGIN: z.string().default('http://localhost:3000'),
  MEDIA_ROOT: z.string().default('./data/media'),
  FIREBASE_PROJECT_ID: z.preprocess((value) => value === '' ? undefined : value, z.string().optional()),
  FIREBASE_CLIENT_EMAIL: z.preprocess((value) => value === '' ? undefined : value, z.string().email().optional()),
  FIREBASE_PRIVATE_KEY: z.preprocess((value) => value === '' ? undefined : value, z.string().optional()),
  SMS_WEBHOOK_URL: z.preprocess((value) => value === '' ? undefined : value, z.string().url().optional()),
  SMS_WEBHOOK_TOKEN: z.preprocess((value) => value === '' ? undefined : value, z.string().optional()),
});

export type AppConfig = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return schema.parse(env);
}
