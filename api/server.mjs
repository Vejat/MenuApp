import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { digest, token, verifyPassword } from './security.mjs';
import { advanceOrder, confirmOrder, listOrders } from './orders.mjs';
import { canAttempt } from './login-limit.mjs';
import { serveWeb } from './web-files.mjs';
import { configurePush, sendPush } from './push.mjs';
import { administerDiscount, ApiError, discountFor, guestAction, guestVisit, normalizeCode, staffVisitAction, summaryPdf, transaction, visitSummary } from './visit.mjs';

const database = new pg.Pool({ connectionString: process.env.DATABASE_URL, connectionTimeoutMillis: 5000 });
const origin = new URL(process.env.PUBLIC_WEB_URL ?? process.env.RENDER_EXTERNAL_URL ?? 'http://localhost:8080');
const listenHost = process.env.API_HOST ?? '127.0.0.1';
const pushPublicKey = await configurePush(database);

const listeners = new Set();
const productCategories = ['Entradas', 'Platos principales', 'Acompañamientos', 'Bebidas sin alcohol', 'Cervezas', 'Vinos y cócteles', 'Postres'];
const uuidPattern = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;

function orderEvents(response, sessionHash, visitId, alerts = false) {
  if (response.destroyed) return;
  response.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'X-Accel-Buffering': 'no',
  });
  const listener = { response, sessionHash, visitId, alerts };
  listeners.add(listener);
  const heartbeat = setInterval(() => response.write(': heartbeat\n\n'), 15000);
  response.on('close', () => {
    clearInterval(heartbeat);
    listeners.delete(listener);
  });
  response.write(alerts ? ': connected\n\n' : 'data: orders\n\n');
}

function publishEvent(data, matches) {
  for (const listener of listeners) {
    if (matches(listener)) {
      if (listener.response.writableLength > 65536) listener.response.destroy();
      else listener.response.write(`data: ${data}\n\n`);
    }
  }
}

function notifyOrders(visitId) {
  publishEvent('orders', listener => !listener.alerts &&
    (!listener.visitId || listener.visitId === visitId));
}

function notifyStaff(type, { id, table }) {
  publishEvent(JSON.stringify({ type, id, table }), listener => listener.alerts && !listener.visitId);
  const title = type === 'new_order' ? 'Nuevo pedido' : type === 'bill_requested' ? 'Solicitud de pago' : type === 'waiter_called' ? 'Llamaron al mesero' : 'Pago confirmado';
  void sendPush(database, 'staff', { title: `MenuApp · ${title}`, body: `${table ?? 'Restaurante'} · Toca para abrir MenuApp`, url: '/?personal=1', tag: `${type}-${id}` });
}

async function readBody(request) {
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 4096) throw new ApiError(413, 'Solicitud demasiado grande.');
    chunks.push(chunk);
  }
  try {
    const body = JSON.parse(Buffer.concat(chunks));
    if (!body || Array.isArray(body) || typeof body !== 'object') throw new Error();
    return body;
  } catch {
    throw new ApiError(400, 'Solicitud inválida.');
  }
}

function bearer(request) {
  return /^Bearer ([\w-]{43})$/.exec(request.headers.authorization ?? '')?.[1] ?? '';
}

async function staffAccount(request) {
  const result = await database.query(
    `SELECT staff.username, role FROM staff_sessions JOIN staff USING (username)
     WHERE token_hash = $1 AND expires_at > now() AND staff.enabled`, [digest(bearer(request))],
  );
  if (!result.rowCount) throw new ApiError(401, 'Inicia sesión nuevamente.');
  return result.rows[0];
}

function qrUrl(qrToken, parameter = 'visita') {
  const url = new URL(origin);
  url.searchParams.set(parameter, qrToken);
  return url.href;
}

function publishClose(visitId) {
  notifyOrders(visitId);
  for (const listener of listeners) {
    if (listener.visitId === visitId) listener.response.end();
  }
}

async function route(request, response) {
  const url = new URL(request.url, 'http://localhost');
  const path = url.pathname;
  const method = request.method;
  if (method === 'GET' && path === '/push/key') return { publicKey: pushPublicKey };
  if (method === 'POST' && path === '/push/subscribe') {
    const sessionHash = digest(bearer(request));
    const { subscription } = await readBody(request);
    if (!subscription || typeof subscription.endpoint !== 'string' || !subscription.endpoint.startsWith('https://')) throw new ApiError(400, 'Suscripción inválida.');
    const staff = await database.query('SELECT 1 FROM staff_sessions WHERE token_hash=$1 AND expires_at>now()', [sessionHash]);
    let audience = 'staff';
    if (!staff.rowCount) {
      const guest = await database.query('SELECT 1 FROM guest_sessions WHERE token_hash=$1', [sessionHash]);
      if (!guest.rowCount) throw new ApiError(401, 'Inicia sesión o escanea el QR nuevamente.');
      audience = 'guest';
    }
    await database.query('INSERT INTO push_subscriptions (endpoint, subscription, audience, session_hash) VALUES ($1,$2,$3,$4) ON CONFLICT (endpoint) DO UPDATE SET subscription=$2,audience=$3,session_hash=$4', [subscription.endpoint, subscription, audience, sessionHash]);
    return { ok: true };
  }
  if (method === 'GET' && path === '/healthz') {
    await database.query('SELECT 1 FROM staff LIMIT 1');
    return { ok: true };
  }
  if (method === 'POST' && path === '/staff/login') {
    const { username, password } = await readBody(request);
    if (typeof username !== 'string' || username.trim().length > 64 ||
        typeof password !== 'string' || password.length > 256) {
      throw new ApiError(400, 'Ingresa usuario y contraseña.');
    }
    const markSuccess = canAttempt(request.socket.remoteAddress, username.trim());
    if (!markSuccess) throw new ApiError(429, 'Demasiados intentos. Espera unos minutos e intenta de nuevo.');
    const { rows } = await database.query('SELECT * FROM staff WHERE username = $1 AND enabled', [username.trim()]);
    const account = rows[0];
    if (!verifyPassword(password, account?.password_hash)) {
      throw new ApiError(401, 'Usuario o contraseña incorrectos.');
    }
    const session = token();
    const { rowCount } = await database.query(
      `INSERT INTO staff_sessions (token_hash, username)
       SELECT $1, username FROM staff WHERE username = $2 AND enabled AND password_hash = $3`,
      [digest(session), account.username, account.password_hash],
    );
    if (!rowCount) throw new ApiError(401, 'La cuenta cambió. Inicia sesión nuevamente.');
    markSuccess();
    return { session, role: account.role };
  }
  if (method === 'POST' && path === '/guest/session') {
    const { qrToken, tableToken } = await readBody(request);
    if (tableToken !== undefined) {
      if (typeof tableToken !== 'string' || !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(tableToken)) {
        throw new ApiError(400, 'QR de mesa inválido.');
      }
      const session = token();
      const { visitId, created } = await transaction(database, async client => {
        const { rows: tables } = await client.query(
          'SELECT id FROM dining_tables WHERE qr_token = $1 FOR UPDATE', [tableToken],
        );
        if (!tables.length) throw new ApiError(404, 'Esta mesa no está disponible.');
        const tableId = tables[0].id;
        const { rows: visits } = await client.query(
          "SELECT id FROM visits WHERE table_id = $1 AND status <> 'closed' FOR UPDATE", [tableId],
        );
        let visitId = visits[0]?.id;
        if (!visitId) {
          visitId = randomUUID();
          await client.query('INSERT INTO visits (id, table_id, qr_token) VALUES ($1,$2,$3)', [visitId, tableId, token()]);
        }
        await client.query('INSERT INTO guest_sessions (token_hash, visit_id) VALUES ($1,$2)', [digest(session), visitId]);
        return { visitId, created: !visits.length };
      });
      if (created) notifyOrders(visitId);
      return { session };
    }
    if (typeof qrToken !== 'string') throw new ApiError(400, 'QR inválido.');
    const session = token();
    const { rowCount } = await database.query(
      `INSERT INTO guest_sessions (token_hash, visit_id)
       SELECT $1, id FROM visits WHERE qr_token = $2 AND status <> 'closed'`,
      [digest(session), qrToken],
    );
    if (!rowCount) throw new ApiError(404, 'Esta visita ya no está disponible.');
    return { session };
  }
  if (method === 'GET' && path === '/guest/visit') {
    const { label, status } = await guestVisit(database, digest(bearer(request)));
    return { label, status };
  }
  if (method === 'GET' && path === '/guest/catalog') {
    const visit = await guestVisit(database, digest(bearer(request)));
    const { rows } = await database.query('SELECT * FROM products WHERE available ORDER BY name, id');
    const [summary] = await visitSummary(database, visit.id);
    return { products: rows, summary };
  }
  if (path === '/admin/discounts') {
    const { role } = await staffAccount(request);
    if (role !== 'admin') throw new ApiError(403, 'Solo el encargado puede hacer esto.');
    if (method === 'GET') {
      const { rows } = await database.query(
        `SELECT code, percent, starts_on::text AS "startsOn", ends_on::text AS "endsOn", active
         FROM discount_codes ORDER BY code`,
      );
      return { discounts: rows };
    }
    if (method === 'POST') return administerDiscount(database, await readBody(request));
  }
  if (method === 'POST' && path === '/guest/discount') {
    const { code } = await readBody(request);
    const visit = await guestVisit(database, digest(bearer(request)));
    const discount = await discountFor(database, visit, normalizeCode(code));
    const [summary] = await visitSummary(database, visit.id);
    return { ...discount, summary };
  }
  const guestActionRoute = /^\/guest\/(call|bill)$/.exec(path);
  if (method === 'POST' && guestActionRoute) {
    const result = await guestAction(database, digest(bearer(request)), guestActionRoute[1], await readBody(request));
    notifyOrders(result.id);
    if (result.billRequested) notifyStaff('bill_requested', result);
    if (result.callId != null) notifyStaff('waiter_called', { id: result.callId, table: result.table });
    return {};
  }
  const staffActionRoute = /^\/staff\/visits\/([a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12})\/(attend|review|reopen|pay)$/i.exec(path);
  if (method === 'GET' && path === '/admin/payment-history') {
    const { role } = await staffAccount(request);
    if (role !== 'admin') throw new ApiError(403, 'Solo el encargado puede hacer esto.');
    const before = url.searchParams.get('before');
    if (before !== null && !uuidPattern.test(before)) throw new ApiError(400, 'Página de historial inválida.');
    const pageSize = 30;
    const { rows } = await database.query(
      `SELECT visits.id, label, bill_total::float8 AS total, bill_method AS method, paid_at AS "paidAt"
       FROM visits JOIN dining_tables ON dining_tables.id = visits.table_id
       WHERE paid_at IS NOT NULL AND ($1::uuid IS NULL OR (paid_at, visits.id) <
         (SELECT paid_at, id FROM visits WHERE id = $1 AND paid_at IS NOT NULL))
       ORDER BY paid_at DESC, visits.id DESC LIMIT $2`, [before, pageSize + 1],
    );
    return { payments: rows.slice(0, pageSize), next: rows.length > pageSize ? rows[pageSize - 1].id : null };
  }
  const paymentRoute = /^\/staff\/visits\/([a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12})\/payment$/i.exec(path);
  if (method === 'GET' && paymentRoute) {
    await staffAccount(request);
    const { rows } = await database.query(
      `SELECT label, bill_total::float8 AS total, bill_method AS method, paid_at AS "paidAt",
        paid_by AS "paidBy", discount_code AS code, discount_percent AS percent
       FROM visits JOIN dining_tables ON dining_tables.id = visits.table_id
       WHERE visits.id = $1 AND paid_at IS NOT NULL`, [paymentRoute[1]],
    );
    if (!rows.length) throw new ApiError(404, 'Este pago ya no está disponible.');
    const { orders } = await listOrders(database, paymentRoute[1], { includePaid: true });
    return { payment: rows[0], orders };
  }
  if (method === 'POST' && staffActionRoute) {
    const { username } = await staffAccount(request);
    const [, visitId, action] = staffActionRoute;
    const payment = await staffVisitAction(database, visitId, action.toLowerCase(), await readBody(request), username);
    if (payment) notifyStaff('payment_confirmed', payment);
    if (action.toLowerCase() === 'pay') publishClose(visitId);
    else notifyOrders(visitId);
    return {};
  }
  if (method === 'GET' && path === '/guest/summary/pdf') {
    const { summary, orders } = await transaction(database, async client => {
      const visit = await guestVisit(client, digest(bearer(request)), true);
      const [summary] = await visitSummary(client, visit.id);
      const { orders } = await listOrders(client, visit.id);
      return { summary, orders };
    });
    return { pdf: await summaryPdf(summary, orders) };
  }
  if (method === 'GET' && path === '/guest/alerts/events') {
    const sessionHash = digest(bearer(request));
    const visit = await guestVisit(database, sessionHash);
    return orderEvents(response, sessionHash, visit.id, true);
  }
  if (method === 'GET' && (path === '/guest/orders' || path === '/guest/orders/events')) {
    const sessionHash = digest(bearer(request));
    const visit = await guestVisit(database, sessionHash);
    if (path.endsWith('/events')) return orderEvents(response, sessionHash, visit.id);
    const [summary] = await visitSummary(database, visit.id);
    if (!summary) throw new ApiError(401, 'Esta mesa ya se cerró. Escanea el QR otra vez para empezar.');
    return { ...await listOrders(database, visit.id), summary };
  }
  if (method === 'POST' && path === '/guest/orders') {
    const result = await confirmOrder(database, digest(bearer(request)), await readBody(request));
    notifyOrders(result.visitId);
    if (result.table) notifyStaff('new_order', result);
    return { id: result.id };
  }
  if (method === 'GET' && path === '/staff/alerts/events') {
    await staffAccount(request);
    return orderEvents(response, digest(bearer(request)), undefined, true);
  }
  if (method === 'GET' && (path === '/staff/orders' || path === '/staff/orders/events')) {
    await staffAccount(request);
    if (path.endsWith('/events')) return orderEvents(response, digest(bearer(request)));
    return { ...await listOrders(database), visits: await visitSummary(database) };
  }
  const orderAction = /^\/staff\/orders\/([1-9][0-9]{0,8})\/advance$/.exec(path);
  if (method === 'POST' && orderAction) {
    await staffAccount(request);
    const { status } = await readBody(request);
    const result = await advanceOrder(database, orderAction[1], status);
    notifyOrders(result.visitId);
    if (result.status === 'ready' && result.guestSessionHash) {
      publishEvent(JSON.stringify({ type: 'order_ready', id: result.id }),
        listener => listener.alerts && listener.visitId === result.visitId &&
          listener.sessionHash === result.guestSessionHash);
      void sendPush(database, 'guest', { title: 'Tu pedido está listo', body: `Pedido #${result.id} · Ya te lo llevan a la mesa.`, url: '/', tag: `ready-${result.id}` }, result.guestSessionHash);
    }
    return {};
  }
  if (path === '/admin/products' || /^\/admin\/products\/[1-9][0-9]{0,8}$/.test(path)) {
    const { role } = await staffAccount(request);
    if (role !== 'admin') throw new ApiError(403, 'Solo el encargado puede hacer esto.');
    if (method === 'GET' && path === '/admin/products') {
      const { rows } = await database.query('SELECT * FROM products ORDER BY name, id');
      return { products: rows };
    }
    if (method === 'POST') {
      const { name, category, price, available } = await readBody(request);
      if (typeof name !== 'string' || !name.trim() || name.trim().length > 120 ||
          !productCategories.includes(category) || !Number.isInteger(price) || price < 1 || price > 10000000 || typeof available !== 'boolean') {
        throw new ApiError(400, 'Revisa el nombre, la categoría, el precio y la disponibilidad.');
      }
      const values = [name.trim(), category, price, available];
      const query = path === '/admin/products'
        ? await database.query('INSERT INTO products (name, category, price, available) VALUES ($1, $2, $3, $4) RETURNING id', values)
        : await database.query('UPDATE products SET name = $1, category = $2, price = $3, available = $4 WHERE id = $5 RETURNING id', [...values, path.split('/').at(-1)]);
      if (!query.rowCount) throw new ApiError(404, 'Producto no disponible.');
      return query.rows[0];
    }
  }
  if (method === 'GET' && (path === '/staff/tables' || path === '/staff/tables/events')) {
    const { role } = await staffAccount(request);
    if (path.endsWith('/events')) return orderEvents(response, digest(bearer(request)));
    const { rows } = await database.query(
      `SELECT dining_tables.id, label, dining_tables.qr_token AS table_token, visits.id AS "visitId", visits.status, visits.qr_token, visits.review FROM dining_tables
       LEFT JOIN visits ON visits.table_id = dining_tables.id AND visits.status <> 'closed'
       ORDER BY dining_tables.id`,
    );
    return { role, tables: rows.map(({ qr_token, table_token, ...table }) => ({
      ...table, qrUrl: qr_token ? qrUrl(qr_token) : null, tableQrUrl: qrUrl(table_token, 'mesa'),
    })) };
  }
  const visitAction = /^\/staff\/tables\/([1-9][0-9]{0,8})\/(open|close)$/.exec(path);
  if (method === 'POST' && visitAction) {
    await staffAccount(request);
    const [, tableId, action] = visitAction;
    if (action === 'close') {
      const { visitId } = await readBody(request);
      if (typeof visitId !== 'string' || !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(visitId)) {
        throw new ApiError(400, 'No encontramos esta mesa. Actualiza la lista.');
      }
      const { rowCount } = await database.query(
        "UPDATE visits SET status = 'closed' WHERE table_id = $1 AND id = $2 AND status = 'paid'",
        [tableId, visitId],
      );
      if (!rowCount) throw new ApiError(409, 'La mesa requiere un pago confirmado.');
      publishClose(visitId);
      return {};
    }
    const { rows } = await transaction(database, async client => {
      await client.query('SELECT id FROM dining_tables WHERE id = $1 FOR UPDATE', [tableId]);
      return client.query(
        `INSERT INTO visits (id, table_id, qr_token)
         SELECT $1, id, $2 FROM dining_tables WHERE id = $3
         ON CONFLICT (table_id) WHERE status <> 'closed' DO NOTHING RETURNING id, qr_token`,
        [randomUUID(), token(), tableId],
      );
    });
    if (!rows.length) throw new ApiError(409, 'La mesa no existe o ya tiene una visita activa.');
    notifyOrders(rows[0].id);
    return { qrUrl: qrUrl(rows[0].qr_token) };
  }
  if (method === 'POST' && path === '/staff/logout') {
    const sessionHash = digest(bearer(request));
    await database.query('DELETE FROM staff_sessions WHERE token_hash = $1', [sessionHash]);
    for (const listener of listeners) {
      if (listener.sessionHash === sessionHash) listener.response.end();
    }
    return {};
  }
  throw new ApiError(404, 'Ruta no disponible.');
}

createServer(async (request, response) => {
  response.setHeader('Vary', 'Origin');
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  if (request.headers.origin === origin.origin) {
    response.setHeader('Access-Control-Allow-Origin', origin.origin);
    response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  }
  if (request.method === 'OPTIONS') return response.writeHead(204).end();
  try {
    if (await serveWeb(request, response)) return;
    response.setHeader('Content-Type', 'application/json; charset=utf-8');
    const result = await route(request, response);
    if (!response.headersSent && !response.destroyed) response.end(JSON.stringify(result));
  } catch (error) {
    if (response.destroyed || response.headersSent) return;
    response.setHeader('Content-Type', 'application/json; charset=utf-8');
    response.statusCode = error instanceof ApiError ? error.status : 500;
    if (response.statusCode === 500) console.error(error.code ?? error.name);
    response.end(JSON.stringify({ error: response.statusCode === 500 ? 'Sin conexión con el restaurante. Intenta de nuevo.' : error.message }));
  }
}).listen(Number(process.env.PORT ?? 3000), listenHost);
