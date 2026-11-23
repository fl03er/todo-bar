// Dumps one PNG per requested time (seconds) for quick layout checks: node stills.mjs outDir 3 8 15 ...
import http from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { extname, join } from 'node:path';
import puppeteer from 'puppeteer-core';
const ROOT = new URL('.', import.meta.url).pathname;
const [out, ...times] = process.argv.slice(2);
await mkdir(out, { recursive: true });
const types = { '.html': 'text/html', '.png': 'image/png' };
const server = http.createServer(async (req, res) => { try { const p = join(ROOT, decodeURIComponent(req.url.split('?')[0])); const b = await readFile(p); res.writeHead(200, { 'content-type': types[extname(p)] || 'application/octet-stream' }); res.end(b); } catch { res.writeHead(404); res.end(); } }).listen(0);
const browser = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true, args: ['--force-color-profile=srgb', '--hide-scrollbars'] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080 });
page.on('pageerror', e => console.error('page error:', e.message));
await page.goto(`http://localhost:${server.address().port}/promo.html`, { waitUntil: 'networkidle0' });
await page.evaluate(() => window.ready);
for (const t of times) { await page.evaluate(t => window.renderAt(t), Number(t)); await writeFile(join(out, `t${String(t).padStart(5, '0')}.png`), await page.screenshot({ type: 'png' })); }
await browser.close(); server.close();
