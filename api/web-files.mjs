import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { extname, resolve, sep } from 'node:path';
import { pipeline } from 'node:stream/promises';

const root = process.env.WEB_ROOT ? resolve(process.env.WEB_ROOT) : null;
const mimeTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.wasm': 'application/wasm',
  '.webp': 'image/webp',
};

export async function serveWeb(request, response) {
  if (!root || !['GET', 'HEAD'].includes(request.method)) return false;
  let path;
  try {
    path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  } catch {
    return false;
  }
  const file = resolve(root, '.' + (path === '/' ? '/index.html' : path));
  if (!file.startsWith(root + sep)) return false;
  const info = await stat(file).catch(error => {
    if (['ENOENT', 'ENOTDIR', 'ERR_INVALID_ARG_VALUE'].includes(error.code)) return null;
    throw error;
  });
  if (!info?.isFile()) return false;
  response.writeHead(200, {
    'Content-Type': mimeTypes[extname(file)] ?? 'application/octet-stream',
    'Content-Length': info.size,
    'Cache-Control': 'no-cache',
  });
  if (request.method === 'HEAD') response.end();
  else await pipeline(createReadStream(file), response);
  return true;
}
