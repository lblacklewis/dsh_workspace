// 处方面页验证：首页入口 + 我的处方列表 + 上传页
// 注意：puppeteer-core 是 ESM-only，必须动态 import()
// 注意：:8092 是静态服务器，API 在 80 端口
// 注意：H5 是 history 路由，URL 不带 #
const OUT = (process.env.TEMP + '\\shot\\').replace(/\\\\/g, '\\');
const H5 = 'http://82.156.226.192:8092';
const API = 'http://82.156.226.192';
const P = '/front-api/api/front';
const sleep = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  const puppeteer = (await import('puppeteer-core')).default;
  const browser = await puppeteer.launch({
    executablePath: 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    headless: 'new',
    args: ['--no-sandbox', '--disable-dev-shm-usage']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
  const errors = [];
  page.on('pageerror', e => errors.push('PAGEERROR: ' + e.message));

  const token = process.argv[2];
  await page.goto(H5, { waitUntil: 'networkidle2', timeout: 60000 });
  await page.evaluate(t => localStorage.setItem('LOGIN_STATUS_TOKEN', t), token);

  const api = (path, method, body) => page.evaluate(async (base, p, m, b, tk) => {
    const r = await fetch(base + p, {
      method: m, headers: { 'Content-Type': 'application/json', 'Authori-zation': tk },
      body: b ? JSON.stringify(b) : undefined
    });
    return await r.text();
  }, API, path, method, body, token);

  // 造两条数据：一条待审核、一条已通过（先上传再走后台审核）
  const mk = async (name, diag) => {
    const r = JSON.parse(await api(P + '/prescription/upload', 'POST', {
      patientName: name, idcard: '610113199001011234',
      images: JSON.stringify(['/crmebimage/brand/ic-rx.svg']), diagnosis: diag
    }));
    return r.data ? r.data.id : 0;
  };
  const id1 = await mk('张先生', '上呼吸道感染');
  const id2 = await mk('李女士', '慢性胃炎');
  console.log('  已造处方 id=' + id1 + ',' + id2 + '（均为待审核）');

  // 首页：确认金刚区出现「我的处方」
  await page.goto(H5, { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(3500);
  const home = await page.evaluate(() => {
    const t = document.body.innerText.replace(/\s+/g, ' ');
    return { hasRx: t.includes('我的处方'), hasCoupon: t.includes('领优惠券') };
  });
  console.log('  首页含「我的处方」: ' + home.hasRx + '   含「领优惠券」: ' + home.hasCoupon);
  await page.screenshot({ path: OUT + 'rx-home.png', fullPage: true });

  // 我的处方列表
  await page.goto(H5 + '/pages/prescription/index', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(3500);
  const list = await page.evaluate(() => {
    const t = document.body.innerText.replace(/\s+/g, ' ');
    return {
      url: location.href,
      hasNotice: t.includes('处方药需凭处方购买'),
      hasTabs: ['全部', '待审核', '已通过', '未通过'].every(x => t.includes(x)),
      hasRxNo: t.includes('处方号'),
      hasPatient: t.includes('张先生'),
      hasCs: t.includes('上传处方'),
      hasConsult: t.includes('在线问诊'),
      snippet: t.substring(0, 400)
    };
  });
  console.log('  url: ' + list.url);
  console.log('  合规提示=' + list.hasNotice + ' 筛选标签=' + list.hasTabs + ' 处方号=' + list.hasRxNo +
    ' 患者=' + list.hasPatient + ' 上传按钮=' + list.hasCs + ' 问诊按钮=' + list.hasConsult);
  console.log('  页面文字: ' + list.snippet);
  await page.screenshot({ path: OUT + 'rx-list.png', fullPage: true });

  // 上传页
  await page.goto(H5 + '/pages/prescription/upload', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(3000);
  const up = await page.evaluate(() => {
    const t = document.body.innerText.replace(/\s+/g, ' ');
    return {
      hasNotice: t.includes('处方药需实名购买'),
      hasName: t.includes('患者姓名'),
      hasId: t.includes('身份证号'),
      hasPhoto: t.includes('处方照片'),
      hasDiag: t.includes('临床诊断'),
      hasSubmit: t.includes('提交审核'),
      snippet: t.substring(0, 380)
    };
  });
  console.log('  实名提示=' + up.hasNotice + ' 姓名=' + up.hasName + ' 身份证=' + up.hasId +
    ' 照片=' + up.hasPhoto + ' 诊断=' + up.hasDiag + ' 提交=' + up.hasSubmit);
  console.log('  页面文字: ' + up.snippet);
  await page.screenshot({ path: OUT + 'rx-upload.png', fullPage: true });

  // 空校验：不填直接提交
  const c = await page.evaluate(() => {
    const els = Array.from(document.querySelectorAll('uni-view,div'));
    const btn = els.filter(e => (e.innerText || '').trim() === '提交审核')
      .sort((a, b) => a.innerText.length - b.innerText.length)[0];
    if (btn) { btn.click(); return true; }
    return false;
  });
  await sleep(1200);
  const toast = await page.evaluate(() => document.body.innerText.replace(/\s+/g, ' '));
  console.log('  点提交按钮=' + c + ' 是否提示校验: ' + /请填写|请输入|请上传/.test(toast));
  await page.screenshot({ path: OUT + 'rx-validate.png', fullPage: true });

  console.log('\n=== JS 错误 ===');
  console.log(errors.length ? errors.slice(0, 6).join('\n') : '  (无)');
  await browser.close();
})().catch(e => { console.error('FATAL: ' + e.message); process.exit(1); });
