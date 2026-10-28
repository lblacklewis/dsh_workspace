// 对照：原有页面（商品管理）能否渲染异步数据
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

  page.on('console', (m) => { if (m.type() === 'error') console.log('  [console.error] ' + m.text().substring(0, 300)); });
  page.on('pageerror', (e) => console.log('  [pageerror] ' + e.message.substring(0, 300)));
  page.on('response', async (r) => {
    if (r.url().includes('/store/product/list')) {
      let b = '';
      try { b = (await r.text()).substring(0, 220); } catch (e) { b = '<unreadable>'; }
      console.log('  [XHR] ' + r.status() + ' ' + r.url().replace('http://82.156.226.192', '') + '\n        -> ' + b);
    }
  });

  const token = process.argv[2];
  await page.setCookie({ name: 'Authori-zation', value: token, domain: '82.156.226.192', path: '/' });

  // 商品管理：库里一定有商品，是判断"整体是否正常"的好对照
  await page.goto(ADMIN + '/store/index', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(7000);

  const info = await page.evaluate(() => {
    const t = document.body.innerText.replace(/\s+/g, ' ');
    const rows = document.querySelectorAll('.el-table__row, .el-table__body tr').length;
    return {
      url: location.href,
      rows,
      hasEmpty: t.includes('暂无数据'),
      snippet: t.substring(0, 320),
    };
  });
  console.log('  url: ' + info.url);
  console.log('  表格行数: ' + info.rows);
  console.log('  含「暂无数据」: ' + info.hasEmpty);
  console.log('  页面文字: ' + info.snippet);

  await browser.close();
})().catch((e) => {
  console.error('FATAL: ' + e.message);
  process.exit(1);
});
