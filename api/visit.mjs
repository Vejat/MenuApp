import PDFDocument from 'pdfkit';

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function transaction(database, action) {
  const client = await database.connect();
  try {
    await client.query('BEGIN');
    const result = await action(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function guestVisit(database, sessionHash, lock = false) {
  const { rows } = await database.query(
    `SELECT visits.*, label FROM guest_sessions
     JOIN visits ON visits.id = guest_sessions.visit_id
     JOIN dining_tables ON dining_tables.id = visits.table_id
     WHERE token_hash = $1 AND visits.status <> 'closed'${lock ? ' FOR UPDATE OF visits' : ''}`,
    [sessionHash],
  );
  if (!rows.length) throw new ApiError(401, 'Esta mesa ya se cerró. Escanea el QR otra vez para empezar.');
  return rows[0];
}

export function totals(subtotal, percent) {
  const discount = Math.floor((subtotal * percent + 50) / 100);
  return { subtotal, discount, total: subtotal - discount };
}

export async function discountFor(database, visit, code, lock = false) {
  if (visit.discount_code) {
    if (code && code !== visit.discount_code) throw new ApiError(409, 'Esta visita ya tiene un código aplicado.');
    return { code: visit.discount_code, percent: visit.discount_percent };
  }
  if (!code) return { code: '', percent: 0 };
  const { rows } = await database.query(
    `SELECT code, percent FROM discount_codes WHERE code = $1 AND active
      AND (now() AT TIME ZONE 'America/Santiago')::date BETWEEN starts_on AND ends_on${lock ? ' FOR SHARE' : ''}`,
    [code],
  );
  if (!rows.length) throw new ApiError(409, 'Este código no es válido o ya venció.');
  return rows[0];
}

export function normalizeCode(value) {
  if (value == null || value === '') return '';
  if (typeof value !== 'string' || !/^[A-Z0-9_-]{1,24}$/.test(value.trim().toUpperCase())) {
    throw new ApiError(400, 'Usa letras, números o guiones (máx. 24).');
  }
  return value.trim().toUpperCase();
}

export async function visitSummary(database, visitId) {
  const { rows } = await database.query(
    `SELECT visits.id, table_id AS "tableId", label, visits.status, discount_code AS code, discount_percent AS percent,
      bill_method AS method, review, waiter_calls.id AS "callId",
      COALESCE(SUM(orders.total), 0)::float8 AS subtotal, COUNT(orders.id)::integer AS "orderCount",
      (COUNT(orders.id) FILTER (WHERE orders.status <> 'delivered'))::integer AS "pendingDelivery"
     FROM visits JOIN dining_tables ON dining_tables.id = table_id
     LEFT JOIN orders ON orders.visit_id = visits.id
     LEFT JOIN waiter_calls ON waiter_calls.visit_id = visits.id AND attended_at IS NULL
     WHERE ($1::uuid IS NULL OR visits.id = $1) AND visits.status <> 'closed'
     GROUP BY visits.id, label, waiter_calls.id ORDER BY label`, [visitId ?? null],
  );
  return rows.map(row => ({ ...row, ...totals(row.subtotal, row.percent) }));
}

export async function administerDiscount(database, body) {
  const code = normalizeCode(body.code);
  const { percent, startsOn, endsOn, active } = body;
  const validDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) &&
    Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value && value.slice(0, 4) !== '0000';
  if (!code || !Number.isInteger(percent) || percent < 1 || percent > 100 ||
      !validDate(startsOn) || !validDate(endsOn) || startsOn > endsOn || typeof active !== 'boolean') {
    throw new ApiError(400, 'Revisa el porcentaje, las fechas y el código.');
  }
  await database.query(
    `INSERT INTO discount_codes VALUES ($1,$2,$3,$4,$5) ON CONFLICT (code) DO UPDATE
     SET percent = EXCLUDED.percent, starts_on = EXCLUDED.starts_on,
         ends_on = EXCLUDED.ends_on, active = EXCLUDED.active`, [code, percent, startsOn, endsOn, active],
  );
  return {};
}

const methods = { transfer: 'Transferencia', cash: 'Efectivo', card: 'Tarjeta' };

export function guestAction(database, sessionHash, action, body) {
  return transaction(database, async client => {
    const visit = await guestVisit(client, sessionHash, true);
    if (visit.status === 'paid') throw new ApiError(409, 'La cuenta ya está pagada.');
    if (action === 'call') {
      const { rows } = await client.query(
        `INSERT INTO waiter_calls (visit_id) VALUES ($1)
         ON CONFLICT (visit_id) WHERE attended_at IS NULL DO NOTHING RETURNING id`, [visit.id],
      );
      return { id: visit.id, table: visit.label, callId: rows[0]?.id };
    } else {
      if (typeof body.method !== 'string' || !Object.hasOwn(methods, body.method)) {
        throw new ApiError(400, 'Elige un método de pago.');
      }
      const [summary] = await visitSummary(client, visit.id);
      if (!summary.orderCount) throw new ApiError(409, 'La mesa aún no tiene pedidos.');
      await client.query(
        "UPDATE visits SET status = 'bill_requested', bill_method = $2, bill_total = $3 WHERE id = $1",
        [visit.id, body.method, summary.total],
      );
    }
    return { id: visit.id, table: visit.label, billRequested: action === 'bill' && visit.status === 'open' };
  });
}

export function staffVisitAction(database, visitId, action, body, username) {
  return transaction(database, async client => {
    const { rows } = await client.query(
      `SELECT visits.*, label FROM visits JOIN dining_tables ON dining_tables.id = visits.table_id
       WHERE visits.id = $1 FOR UPDATE OF visits`, [visitId],
    );
    const visit = rows[0];
    if (action === 'pay' && visit?.status === 'closed' && visit.paid_at &&
        body.total === Number(visit.bill_total) && body.method === visit.bill_method) return;
    if (!visit || visit.status === 'closed') throw new ApiError(404, 'La visita ya no está disponible.');
    switch (action) {
      case 'attend':
        if (!Number.isInteger(body.callId)) throw new ApiError(400, 'Llamada inválida.');
        await client.query(
          'UPDATE waiter_calls SET attended_at = now() WHERE visit_id = $1 AND id = $2 AND attended_at IS NULL',
          [visitId, body.callId],
        );
        break;
      case 'review':
        if (typeof body.review !== 'boolean') throw new ApiError(400, 'Marca de revisión inválida.');
        await client.query('UPDATE visits SET review = $2 WHERE id = $1', [visitId, body.review]);
        break;
      case 'reopen':
        if (visit.status !== 'bill_requested') throw new ApiError(409, 'La cuenta ya cambió.');
        await client.query("UPDATE visits SET status = 'open', bill_method = NULL, bill_total = NULL WHERE id = $1", [visitId]);
        break;
      case 'pay':
        if (visit.status === 'paid' && body.total === Number(visit.bill_total) && body.method === visit.bill_method) break;
        if (visit.status !== 'bill_requested' || body.total !== Number(visit.bill_total) ||
            body.method !== visit.bill_method) throw new ApiError(409, 'La cuenta cambió. Revisa el total y el método.');
        const pending = await client.query(
          "SELECT 1 FROM orders WHERE visit_id = $1 AND status <> 'delivered' LIMIT 1", [visitId],
        );
        if (pending.rowCount) throw new ApiError(409, 'Marca los pedidos como entregados para confirmar el pago.');
        await client.query(
          "UPDATE visits SET status = 'closed', paid_at = now(), paid_by = $2 WHERE id = $1",
          [visitId, username],
        );
        return { id: visitId, table: visit.label };
    }
  });
}

export async function summaryPdf(summary, orders) {
  const doc = new PDFDocument({ size: 'A4', margin: 42, info: { Title: 'Resumen de consumo' } });
  const result = new Promise((resolve, reject) => {
    const parts = [];
    doc.on('data', part => parts.push(part));
    doc.on('end', () => resolve(Buffer.concat(parts).toString('base64')));
    doc.on('error', reject);
  });
  const pesos = value => '$' + new Intl.NumberFormat('es-CL').format(value);
  const left = 42;
  const width = doc.page.width - 84;
  doc.roundedRect(left, 42, width, 88, 12).fill('#18231f');
  doc.fillColor('#b7e4c7').font('Helvetica-Bold').fontSize(10).text('MENUAPP  ·  RESTAURANTE', left + 22, 58);
  doc.fillColor('#ffffff').fontSize(22).text('Resumen de consumo', left + 22, 77);
  doc.fillColor('#e7eee9').font('Helvetica').fontSize(11).text(summary.label, left + 22, 107);
  doc.y = 151;
  doc.fillColor('#59665f').fontSize(9).text('Documento de referencia · La boleta tributaria oficial la emite el restaurante.', { characterSpacing: 0.1 }).moveDown(1.2);
  for (const order of orders) {
    doc.fillColor('#18231f').font('Helvetica-Bold').fontSize(12).text('Pedido #' + order.id);
    doc.moveTo(left, doc.y + 5).lineTo(doc.page.width - left, doc.y + 5).strokeColor('#dce5df').stroke();
    doc.moveDown(0.7).font('Helvetica').fontSize(10).fillColor('#26332c');
    for (const line of order.lines) {
      const y = doc.y;
      doc.text(`${line.quantity} × ${line.name}`, left, y, { width: width * 0.62 });
      doc.text(`${pesos(line.price)} c/u`, left + width * 0.63, y, { width: width * 0.17, align: 'right' });
      doc.text(pesos(line.quantity * line.price), left + width * 0.81, y, { width: width * 0.19, align: 'right' });
    }
    doc.moveDown(0.5).font('Helvetica-Bold').text('Subtotal pedido', left, doc.y, { continued: true }).text(pesos(order.total), { align: 'right' }).moveDown(1);
  }
  doc.moveDown(0.4);
  const totalY = doc.y;
  doc.roundedRect(left, totalY, width, 103, 10).fill('#f0f5f1');
  doc.fillColor('#334139').font('Helvetica').fontSize(11).text('Subtotal', left + 16, totalY + 14, { continued: true }).text(pesos(summary.subtotal), { align: 'right' });
  doc.text(`Descuento (${summary.percent}%)`, left + 16, totalY + 38, { continued: true }).text('−' + pesos(summary.discount), { align: 'right' });
  doc.moveTo(left + 16, totalY + 63).lineTo(left + width - 16, totalY + 63).strokeColor('#d5dfd8').stroke();
  doc.fillColor('#145c3b').font('Helvetica-Bold').fontSize(16).text('TOTAL', left + 16, totalY + 73, { continued: true }).text(pesos(summary.total), { align: 'right' });
  if (summary.method) doc.moveDown(1.5).fillColor('#59665f').font('Helvetica').fontSize(10).text('Medio de pago: ' + methods[summary.method]);
  doc.moveDown(1).fillColor('#7b8780').fontSize(8).text('Gracias por tu visita.', { align: 'center' });
  doc.end();
  return result;
}
