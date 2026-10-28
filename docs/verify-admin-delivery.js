// 后台同城配送页验证
const OUT = (process.env.TEMP + '\\shot\\').replace(/\\\\/g, '\\');
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
  const errors = [];
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));

  // 后台 token 存在 Cookie 的 Authori-zation 键里（admin/src/utils/auth.js）
  const token = process.argv[2];
  await page.setCookie({ name: 'Authori-zation', value: token, domain: '82.156.226.192', path: '/' });

  await page.goto(ADMIN + '/delivery/index', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(6000);

  const info = await page.evaluate(() => {
    const t = document.body.innerText.replace(/\s+/g, ' ');
    return {
      url: location.href,
      hasProviders: t.includes('运力商'),
      hasMock: t.includes('本地模拟'),
      hasStatus: t.includes('配送状态'),
      hasDispatchBtn: t.includes('发单给骑手'),
      hasOrderCol: t.includes('订单号') && t.includes('运力单号'),
      hasWarn: t.includes('未接入的运力商即使启用也无法真正发单'),
      hasData: t.includes('李师傅') || t.includes('已送达') || t.includes('配送中'),
      snippet: t.substring(0, 500),
    };
  });
  console.log('  url: ' + info.url);
  console.log('  含「运力商」: ' + info.hasProviders);
  console.log('  含 mock 运力商: ' + info.hasMock);
  console.log('  含配送状态筛选: ' + info.hasStatus);
  console.log('  含发单按钮: ' + info.hasDispatchBtn);
  console.log('  含表格列: ' + info.hasOrderCol);
  console.log('  含未接入告警: ' + info.hasWarn);
  console.log('  含配送数据: ' + info.hasData);
  console.log('  页面文字: ' + info.snippet);

  await page.screenshot({ path: OUT + 'admin-delivery.png', fullPage: true });
  console.log('  已截图 -> admin-delivery.png');

  console.log('\n=== JS 错误 ===');
  console.log(errors.length ? errors.slice(0, 6).join('\n') : '  (无)');
  await browser.close();
})().catch((e) => {
  console.error('FATAL: ' + e.message);
  process.exit(1);
});
