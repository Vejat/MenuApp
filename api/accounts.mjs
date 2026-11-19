import { randomBytes } from 'node:crypto';
import pg from 'pg';
import { passwordHash } from './security.mjs';

const [action, username, role] = process.argv.slice(2);
if (!['create', 'reset', 'disable'].includes(action) || !/^[a-z0-9_.-]{3,64}$/.test(username ?? '') ||
    (action === 'create' && !['staff', 'admin'].includes(role)) || !process.env.DATABASE_URL) {
  console.error('Uso: node accounts.mjs create usuario staff|admin, reset usuario o disable usuario.');
  process.exit(1);
}
const db = new pg.Client({ connectionString: process.env.DATABASE_URL });
const password = action === 'disable' ? null : randomBytes(18).toString('base64url');
await db.connect();
try {
  await db.query('BEGIN');
  let result;
  if (action === 'create') {
    result = await db.query(
      'INSERT INTO staff (username, password_hash, role) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING',
      [username, passwordHash(password), role],
    );
  } else if (action === 'reset') {
    result = await db.query(
      'UPDATE staff SET password_hash = $2, enabled = true WHERE username = $1',
      [username, passwordHash(password)],
    );
  } else {
    result = await db.query('UPDATE staff SET enabled = false WHERE username = $1', [username]);
  }
  if (!result.rowCount) throw new Error('La cuenta no existe o ya se había creado.');
  if (action !== 'create') await db.query('DELETE FROM staff_sessions WHERE username = $1', [username]);
  await db.query('COMMIT');
  console.log(action === 'disable' ? 'Acceso revocado.' : 'Contraseña generada: ' + password);
} catch (error) {
  await db.query('ROLLBACK');
  throw error;
} finally {
  await db.end();
}
