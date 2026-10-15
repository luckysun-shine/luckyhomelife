import pg from 'pg';

const { Pool } = pg;

export function createPool(connectionString: string) {
  return new Pool({ connectionString, max: 10, idleTimeoutMillis: 30_000 });
}

export type DatabasePool = ReturnType<typeof createPool>;

