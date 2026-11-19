import { readFile } from 'node:fs/promises';
import pg from 'pg';
import { passwordHash } from './security.mjs';

const database = new pg.Client({ connectionString: process.env.DATABASE_URL });
const { ADMIN_PASSWORD, STAFF_PASSWORD } = process.env;
const users = Object.entries({ admin: ADMIN_PASSWORD, staff: STAFF_PASSWORD })
  .filter(([, password]) => password !== undefined);
if (users.some(([, password]) => password.length < 12 || password.length > 256)) {
  throw new Error('Las contraseñas iniciales deben tener entre 12 y 256 caracteres.');
}
await database.connect();
try {
  await database.query('BEGIN');
  await database.query(await readFile(new URL('./schema.sql', import.meta.url), 'utf8'));
  for (const [username, password] of users) {
    await database.query(
      'INSERT INTO staff (username, password_hash, role) VALUES ($1, $2, $3) ON CONFLICT (username) DO NOTHING',
      [username, passwordHash(password), username],
    );
  }
  await database.query('COMMIT');
} finally {
  await database.end();
}
