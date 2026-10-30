// 用 CDP 打开本地 PDF 并截图（Edge 的 --screenshot 对 PDF 不работает，必须走 CDP 等渲染）
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const pdfPath = process.argv[2];
const outPath = process.argv[3] || path.join(os.tmpdir(), 'pdf-render.png');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const port = 9333;
  const profile = path.join(os.tmpdir(), 'sa-pdfprof-' + Date.now());
  const proc = spawn(EDGE, [
    '--headless=new', '--no-sandbox', '--disable-crash-reporter', '--disable-breakpad',
    '--remote-debugging-port=' + port, '--user-data-dir=' + profile,
    '--window-size=1240,1754', 'about:blank',
  ], { stdio: 'ignore' });

  const base = 'http://127.0.0.1:' + port;
  let ws = null;
  for (let i = 0; i < 40; i++) {
    await sleep(500);
    try {
      const r = await fetch(base + '/json/list');
      const list = await r.json();
      const pg = list.find((t) => t.type === 'page');
      if (pg && pg.webSocketDebuggerUrl) { ws = pg.webSocketDebuggerUrl; break; }
    } catch (e) {}
  }
  if (!ws) { console.log('  ❌ 连不上 Edge'); proc.kill(); process.exit(1); }

  // Node 24 自带 WebSocket（本仓库所有 cdp 脚本都这么用，不装 ws 包）
  const sock = new WebSocket(ws);
  let id = 0;
  const pending = new Map();
  sock.addEventListener('message', (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  });
  await new Promise((r) => sock.addEventListener('open', r));
  const send = (method, params) => new Promise((res, rej) => {
    const i = ++id;
    pending.set(i, (m) => (m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result)));
    sock.send(JSON.stringify({ id: i, method, params: params || {} }));
  });

  await send('Page.enable');
  await send('Page.navigate', { url: 'file:///' + pdfPath.replace(/\\/g, '/').replace(/^([A-Za-z]):/, '$1:') });
  await sleep(9000); // PDF 插件需要时间渲染

  const { data } = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  fs.writeFileSync(outPath, Buffer.from(data, 'base64'));
  console.log('  已保存 ' + outPath + '  ' + fs.statSync(outPath).size + ' 字节');

  const title = await send('Runtime.evaluate', { expression: 'document.title', returnByValue: true }).catch(() => null);
  console.log('  标题: ' + (title && title.result ? title.result.value : '?'));

  sock.close();
  proc.kill();
})().catch((e) => { console.error('FATAL: ' + e.message); process.exit(1); });
