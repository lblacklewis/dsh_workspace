// 用真实 UI 登录（不绕过登录流程），再检查列表是否渲染
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
  page.on('pageerror', (e) => console.log('  [pageerror] ' + (e && e.message ? e.message : String(e)).substring(0, 300)));
  page.on('console', (m) => { if (m.type() === 'error') console.log('  [console.error] ' + m.text().substring(0, 300)); });

  await page.goto(ADMIN + '/login', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(3000);

  // 真实登录：填表 + 点按钮
  const inputs = await page.$$('input');
  console.log('  表单输入框数量: ' + inputs.length);
  if (inputs.length >= 2) {
    await inputs[0].click({ clickCount: 3 });
    await inputs[0].type('admin', { delay: 30 });
    await inputs[1].click({ clickCount: 3 });
    await inputs[1].type('123456', { delay: 30 });
  }
  // 勾选用户协议（CRMEB 登录页通常有）
  const cbs = await page.$$('.el-checkbox__original, input[type=checkbox]');
  for (const cb of cbs) {
    try { await cb.click(); } catch (e) {}
  }
  await sleep(500);

  const btn = await page.$('.el-button--primary');
  if (btn) await btn.click();
  await sleep(6000);
  console.log('  登录后 url: ' + page.url());

  // 进商品页
  await page.goto(ADMIN + '/store/index', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(8000);
  const info = await page.evaluate(() => {
    const t = document.body.innerText.replace(/\s+/g, ' ');
    return {
      rows: document.querySelectorAll('.el-table__row').length,
      hasEmpty: t.includes('暂无数据'),
      snippet: t.substring(0, 260),
    };
  });
  console.log('  商品页 表格行数: ' + info.rows);
  console.log('  含「暂无数据」: ' + info.hasEmpty);
  console.log('  页面文字: ' + info.snippet);

  await browser.close();
})().catch((e) => {
  console.error('FATAL: ' + e.message);
  process.exit(1);
});
