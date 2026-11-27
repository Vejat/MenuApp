import webpush from 'web-push';

export async function configurePush(database) {
  await database.query(`CREATE TABLE IF NOT EXISTS push_config (id boolean PRIMARY KEY DEFAULT true, public_key text NOT NULL, private_key text NOT NULL, CHECK (id))`);
  await database.query(`CREATE TABLE IF NOT EXISTS push_subscriptions (endpoint text PRIMARY KEY, subscription jsonb NOT NULL, audience text NOT NULL CHECK (audience IN ('staff','guest')), session_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now())`);
  let { rows } = await database.query('SELECT public_key, private_key FROM push_config WHERE id = true');
  if (!rows.length) {
    const keys = webpush.generateVAPIDKeys();
    await database.query('INSERT INTO push_config (id, public_key, private_key) VALUES (true,$1,$2) ON CONFLICT (id) DO NOTHING', [keys.publicKey, keys.privateKey]);
    ({ rows } = await database.query('SELECT public_key, private_key FROM push_config WHERE id = true'));
  }
  webpush.setVapidDetails('mailto:admin@menuapp.local', rows[0].public_key, rows[0].private_key);
  return rows[0].public_key;
}

export async function sendPush(database, audience, payload, sessionHash = null) {
  const { rows } = await database.query('SELECT endpoint, subscription FROM push_subscriptions WHERE audience=$1 AND ($2::text IS NULL OR session_hash=$2)', [audience, sessionHash]);
  await Promise.allSettled(rows.map(async ({ endpoint, subscription }) => {
    try { await webpush.sendNotification(subscription, JSON.stringify(payload)); }
    catch (error) { if ([404, 410].includes(error.statusCode)) await database.query('DELETE FROM push_subscriptions WHERE endpoint=$1', [endpoint]); }
  }));
}
