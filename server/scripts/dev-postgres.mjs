import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import EmbeddedPostgres from 'embedded-postgres';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const databaseDir = join(root, 'data', 'dev-postgres');
const user = 'family_os';
const password = process.env.POSTGRES_PASSWORD;
const port = 5432;

if (!password) {
  console.error('缺少 POSTGRES_PASSWORD，请先在项目根目录准备 .env');
  process.exit(1);
}

const postgres = new EmbeddedPostgres({
  databaseDir,
  user,
  password,
  port,
  persistent: true,
  initdbFlags: ['--encoding=UTF8', '--locale=C'],
});

if (!existsSync(join(databaseDir, 'PG_VERSION'))) {
  await postgres.initialise();
}

await postgres.start();

try {
  await postgres.createDatabase('family_os');
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  if (!/already exists/i.test(message)) throw error;
}

console.log(`本地数据库已启动：127.0.0.1:${port}`);
await new Promise(() => {});
