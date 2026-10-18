// Static file server for the web preview: node tool/serve.mjs build/web 8765
import http from 'http';
import fs from 'fs';
import path from 'path';

const root = path.resolve(process.argv[2]);
const port = Number(process.argv[3] ?? 8765);
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.webp': 'image/webp', '.css': 'text/css',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.ico': 'image/x-icon', '.svg': 'image/svg+xml',
};

http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = path.join(root, p);
  if (!file.startsWith(root)) { res.writeHead(403).end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) { res.writeHead(404).end('not found'); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
  fs.createReadStream(file).pipe(res);
}).listen(port, '127.0.0.1', () => console.log(`serving ${root} on http://localhost:${port}`));
