// 诊断：运力商列表为什么没渲染
const ADMIN = 'http://82.156.226.192';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const puppeteer = (await import('puppeteer-core')).default;
  const browser = await puppeteer.launch({
    executablePath: 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    headless: 'new',
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1600, height: 1000 });

  const logs = [];
  page.on('console', (m) => logs.push('[' + m.type() + '] ' + m.text()));
  page.on('pageerror', (e) => logs.push('[pageerror] ' + e.message));
  page.on('requestfailed', (r) => logs.push('[reqfail] ' + r.url() + ' ' + (r.failure() || {}).errorText));
  page.on('response', async (r) => {
    if (r.url().includes('/delivery/')) {
      let body = '';
      try { body = (await r.text()).substring(0, 300); } catch (e) { body = '<unreadable>'; }
      logs.push('[resp] ' + r.status() + ' ' + r.url() + ' -> ' + body);
    }
  });

  const token = process.argv[2];
  await page.setCookie({ name: 'Authori-zation', value: token, domain: '82.156.226.192', path: '/' });
  await page.goto(ADMIN + '/delivery/index', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(6000);

  console.log('=== 与 delivery 相关的网络/日志 ===');
  const rel = logs.filter((l) => /delivery|运力|error|fail/i.test(l));
  console.log(rel.length ? rel.slice(0, 20).join('\n') : '  (无相关记录)');

  const st = await page.evaluate(() => {
    const cards = document.querySelectorAll('.pv-card');
    const bodies = document.querySelectorAll('.el-card__body');
    let bodyHtml = '';
    bodies.forEach((b, i) => { if (i < 2) bodyHtml += '  body' + i + ': ' + b.outerHTML.substring(0, 400) + '\n'; });
    return {
      cardCount: cards.length,
      rowCount: document.querySelectorAll('.el-row').length,
      bodyHtml,
      scripts: Array.from(document.querySelectorAll('script[src]')).map(s => s.src.split('/').pop()).join(', '),
    };
  });
  console.log('\n=== DOM 检查 ===');
  console.log('  .pv-card 数量: ' + st.cardCount);
  console.log('  .el-row 数量: ' + st.rowCount);
  console.log('  已加载脚本: ' + st.scripts);
  console.log('  card body:\n' + st.bodyHtml);

  await browser.close();
})().catch((e) => {
  console.error('FATAL: ' + e.message);
  process.exit(1);
});
