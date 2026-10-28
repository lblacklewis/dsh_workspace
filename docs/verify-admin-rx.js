// 后台处方审核页验证
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
  await page.setViewport({ width: 1600, height: 900 });
  const errors = [];
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push('CONSOLE: ' + m.text());
  });

  // 1. 登录
  await page.goto(ADMIN + '/', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(2500);
  const loginInfo = await page.evaluate(() => ({
    url: location.href,
    hasUser: !!document.querySelector('input'),
    text: document.body.innerText.replace(/\s+/g, ' ').substring(0, 150),
  }));
  console.log('  登录页: ' + loginInfo.url);
  console.log('  文字: ' + loginInfo.text);

  // 用接口登录再写 token，比点表单稳
  // 后台 token 存在 Cookie 里（utils/auth.js: TokenKey = 'Authori-zation'），不是 localStorage
  const token = process.argv[2];
  await page.setCookie({ name: 'Authori-zation', value: token, domain: '82.156.226.192', path: '/' });

  // 2. 直接打开处方审核页
  await page.goto(ADMIN + '/prescription/index', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(5000);

  const info = await page.evaluate(() => {
    const t = document.body.innerText.replace(/\s+/g, ' ');
    return {
      url: location.href,
      hasMenu: t.includes('处方管理'),
      hasTitle: t.includes('处方审核'),
      hasNotice: t.includes('执业药师审核通过'),
      hasPatient: t.includes('王女士'),
      hasStatus: t.includes('待审核') || t.includes('已驳回') || t.includes('已通过'),
      hasQuery: t.includes('查询'),
      snippet: t.substring(0, 400),
    };
  });
  console.log('  url: ' + info.url);
  console.log('  侧边栏含「处方管理」: ' + info.hasMenu);
  console.log('  含「处方审核」: ' + info.hasTitle);
  console.log('  含合规提示: ' + info.hasNotice);
  console.log('  含患者「王女士」: ' + info.hasPatient);
  console.log('  含状态标签: ' + info.hasStatus);
  console.log('  含查询按钮: ' + info.hasQuery);
  console.log('  页面文字: ' + info.snippet);

  await page.screenshot({ path: OUT + 'admin-rx.png', fullPage: true });
  console.log('  已截图 -> admin-rx.png');

  console.log('\n=== JS 错误 ===');
  console.log(errors.length ? errors.slice(0, 6).join('\n') : '  (无)');
  await browser.close();
})().catch((e) => {
  console.error('FATAL: ' + e.message);
  process.exit(1);
});
