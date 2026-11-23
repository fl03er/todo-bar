// Renders promo.html frame by frame, split across parallel workers (one browser page + one ffmpeg each), then joins the pieces.
// Usage: node render.mjs [out.mp4]       env: WORKERS (default 6), FPS (30), BITRATE (12M), FROM/TO seconds for test renders
import http from 'node:http';
import { readFile, mkdir, writeFile, rm } from 'node:fs/promises';
import { extname, join } from 'node:path';
import { spawn } from 'node:child_process';
import puppeteer from 'puppeteer-core';

const ROOT = new URL('.', import.meta.url).pathname;
const OUT = process.argv[2] || 'todobar-sync.mp4';
const FPS = Number(process.env.FPS || 30), N = Number(process.env.WORKERS || 6), BITRATE = process.env.BITRATE || '12M';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.mjs': 'text/javascript' };
const server = http.createServer(async (req, res) => {
  try { const p = join(ROOT, decodeURIComponent(req.url.split('?')[0])); const body = await readFile(p); res.writeHead(200, { 'content-type': types[extname(p)] || 'application/octet-stream' }); res.end(body); }
  catch { res.writeHead(404); res.end(); }
}).listen(0);
const port = server.address().port;
const browser = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true, args: ['--force-color-profile=srgb', '--hide-scrollbars'] });

const probe = await browser.newPage();
await probe.goto(`http://localhost:${port}/promo.html`, { waitUntil: 'networkidle0' });
await probe.evaluate(() => window.ready);
const duration = await probe.evaluate(() => window.DURATION);
await probe.close();
const t0 = Number(process.env.FROM || 0), t1 = Number(process.env.TO || duration);
const total = Math.round((t1 - t0) * FPS);
const tmp = join(ROOT, '.parts'); await rm(tmp, { recursive: true, force: true }); await mkdir(tmp);
let doneFrames = 0;

async function worker(k) {
  const a = Math.floor(total * k / N), b = Math.floor(total * (k + 1) / N);
  const part = join(tmp, `part${k}.mp4`);
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
  page.on('pageerror', e => console.error('page error:', e.message));
  await page.goto(`http://localhost:${port}/promo.html`, { waitUntil: 'networkidle0' });
  await page.evaluate(() => window.ready);
  const ff = spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'h264_videotoolbox', '-b:v', BITRATE, '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-r', String(FPS), '-g', String(FPS * 2), part], { stdio: ['pipe', 'inherit', 'inherit'] });
  const closed = new Promise(r => ff.on('close', r));
  for (let i = a; i < b; i++) {
    await page.evaluate(t => window.renderAt(t), t0 + i / FPS);
    const buf = await page.screenshot({ type: 'jpeg', quality: 96 });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (++doneFrames % 100 === 0) console.error(`frames ${doneFrames}/${total}`);
  }
  ff.stdin.end(); await closed; await page.close();
  return part;
}
const parts = await Promise.all(Array.from({ length: N }, (_, k) => worker(k)));
await browser.close(); server.close();

await writeFile(join(tmp, 'list.txt'), parts.map(p => `file '${p}'`).join('\n'));
await new Promise((res, rej) => spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', join(tmp, 'list.txt'), '-c', 'copy', '-movflags', '+faststart', OUT], { stdio: 'inherit' }).on('close', c => c ? rej(new Error('concat failed')) : res()));
await rm(tmp, { recursive: true, force: true });
console.error('wrote', OUT);
