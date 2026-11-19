import { digest } from './security.mjs';
import { ApiError, discountFor, guestVisit, normalizeCode, transaction } from './visit.mjs';

export async function listOrders(database, visitId) {
  const { rows } = await database.query(
    `SELECT orders.id, label AS "table", orders.status, total::float8 AS total,
      lines, created_at AS "createdAt"
     FROM orders JOIN visits ON visits.id = orders.visit_id
     JOIN dining_tables ON dining_tables.id = visits.table_id
     WHERE visits.status <> 'closed' AND ($1::uuid IS NULL OR visit_id = $1)
     ORDER BY orders.id DESC`, [visitId ?? null],
  );
  return { orders: rows };
}

export async function confirmOrder(database, sessionHash, body) {
  if (typeof body.key !== 'string' || !/^[a-f0-9]{32}$/.test(body.key) ||
      !Array.isArray(body.lines) || body.lines.length < 1 || body.lines.length > 50) {
    throw new ApiError(400, 'Revisa los productos del carrito.');
  }
  const ids = new Set();
  const lines = body.lines.map(line => {
    if (!line || !Number.isInteger(line.id) || line.id < 1 || line.id > 2147483647 ||
        !Number.isInteger(line.quantity) || line.quantity < 1 || line.quantity > 99 ||
        !Number.isInteger(line.price) || line.price < 1 || line.price > 10000000 || ids.has(line.id)) {
      throw new ApiError(400, 'Revisa las cantidades y precios del carrito.');
    }
    ids.add(line.id);
    return { id: line.id, quantity: line.quantity, price: line.price };
  }).sort((a, b) => a.id - b.id);
  const code = normalizeCode(body.code);
  const percent = body.percent ?? 0;
  if (!Number.isInteger(percent) || percent < 0 || percent > 100 || Boolean(code) !== (percent > 0)) {
    throw new ApiError(400, 'Revisa el descuento del carrito.');
  }
  // Keep replays from clients without a discount compatible with earlier orders.
  const requestHash = digest(JSON.stringify(code ? { lines, code, percent } : lines));
  return transaction(database, async client => {
    const visit = await guestVisit(client, sessionHash, true);
    const existing = await client.query(
      'SELECT id, request_hash FROM orders WHERE visit_id = $1 AND request_key = $2',
      [visit.id, body.key],
    );
    if (existing.rowCount) {
      if (existing.rows[0].request_hash !== requestHash) {
        throw new ApiError(409, 'Esta solicitud ya corresponde a otro pedido.');
      }
      return { id: existing.rows[0].id, visitId: visit.id };
    }
    if (visit.status !== 'open') throw new ApiError(409, 'La mesa ya no admite pedidos.');
    const discount = await discountFor(client, visit, code, true);
    if (discount.code !== code || discount.percent !== percent) {
      throw new ApiError(409, 'Cambió el descuento. Revisa el carrito.');
    }
    const { rows } = await client.query(
      'SELECT id, name, price FROM products WHERE id = ANY($1::integer[]) AND available ORDER BY id FOR SHARE',
      [[...ids]],
    );
    const products = new Map(rows.map(product => [product.id, product]));
    const snapshot = lines.map(line => {
      const product = products.get(line.id);
      if (!product || product.price !== line.price) {
        throw new ApiError(409, 'Cambió el precio o la disponibilidad. Revisa el carrito.');
      }
      return { ...line, name: product.name };
    });
    const total = snapshot.reduce((sum, line) => sum + line.price * line.quantity, 0);
    const inserted = await client.query(
      'INSERT INTO orders (visit_id, request_key, request_hash, lines, total) VALUES ($1,$2,$3,$4,$5) RETURNING id',
      [visit.id, body.key, requestHash, JSON.stringify(snapshot), total],
    );
    if (code && !visit.discount_code) {
      await client.query(
        'UPDATE visits SET discount_code = $2, discount_percent = $3 WHERE id = $1',
        [visit.id, code, percent],
      );
    }
    return { id: inserted.rows[0].id, visitId: visit.id };
  });
}

export async function advanceOrder(database, id, expected) {
  const next = new Map([['received', 'preparing'], ['preparing', 'ready'], ['ready', 'delivered']]).get(expected);
  if (!next) throw new ApiError(400, 'Estado de pedido inválido.');
  const { rows } = await database.query(
    `UPDATE orders SET status = $3 FROM visits
     WHERE orders.id = $1 AND orders.status = $2 AND visits.id = orders.visit_id
       AND visits.status <> 'closed' RETURNING orders.visit_id`, [id, expected, next],
  );
  if (!rows.length) throw new ApiError(409, 'El pedido cambió. Revisa su estado actual.');
  return rows[0].visit_id;
}
