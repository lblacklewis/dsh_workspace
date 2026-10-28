// 真实登录后验证两个新页面
const ADMIN = 'http://82.156.226.192';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function realLogin(page) {
  await page.goto(ADMIN + '/login', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(3000);
  const inputs = await page.$$('input');
  await inputs[0].click({ clickCount: 3 });
  await inputs[0].type('admin', { delay: 30 });
  await inputs[1].click({ clickCount: 3 });
  await inputs[1].type('123456', { delay: 30 });
  const cbs = await page.$$('.el-checkbox__original, input[type=checkbox]');
  for (const cb of cbs) { try { await cb.click(); } catch (e) {} }
  await sleep(400);
  const btn = await page.$('.el-button--primary');
  if (btn) await btn.click();
  await sleep(6000);
}

async function check(page, path, label, probes) {
  await page.goto(ADMIN + path, { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(7000);
  const r = await page.evaluate((probes) => {
    const t = document.body.innerText.replace(/\s+/g, ' ');
    const out = { rows: document.querySelectorAll('.el-table__row').length, hit: {} };
    probes.forEach((p) => { out.hit[p] = t.includes(p); });
    out.snippet = t.substring(0, 300);
    return out;
  }, probes);
  console.log('\n=== ' + label + ' (' + path + ') ===');
  console.log('  表格行数: ' + r.rows);
  Object.keys(r.hit).forEach((k) => console.log('  含「' + k + '」: ' + r.hit[k]));
  console.log('  页面文字: ' + r.snippet);
}

(async () => {
  const puppeteer = (await import('puppeteer-core')).default;
  const browser = await puppeteer.launch({
    executablePath: 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    headless: 'new',
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1600, height: 1000 });
  page.on('pageerror', (e) => console.log('  [pageerror] ' + (e && e.message ? e.message : String(e)).substring(0, 200)));

  await realLogin(page);

  await check(page, '/delivery/index', '同城配送', ['运力商', '本地模拟', '微信即时配送', '美团配送', '蜂鸟即配', '发单给骑手']);
  await check(page, '/prescription/index', '处方审核', ['处方审核', '王女士', '高血压2级', '待审核', '执业药师']);

  await browser.close();
})().catch((e) => {
  console.error('FATAL: ' + e.message);
  process.exit(1);
});
