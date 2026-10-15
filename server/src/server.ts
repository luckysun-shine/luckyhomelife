import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createPool } from './database/pool.js';

const config = loadConfig();
const pool = createPool(config.DATABASE_URL);
const app = await buildApp(config, pool);

const close = async () => {
  await app.close();
  await pool.end();
};

process.on('SIGINT', close);
process.on('SIGTERM', close);

await app.listen({ host: '0.0.0.0', port: config.PORT });

