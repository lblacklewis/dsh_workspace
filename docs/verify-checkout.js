// 结算页「同城配送」验证 + 加购链路验证
// 注意 1：新版 puppeteer-core 是 ESM-only，必须用动态 import()
// 注意 2：:8092 只是静态服务器，API 在 80 端口。发错端口会被 SPA 兜底返回 index.html，
//         报错是 "Unexpected token '<'"，很容易误判成接口坏了。
// 注意 3：cart/save 的 productAttrUnique 字段名有误导性——后端实际是按 attr_value.id 查的
//         （StoreProductAttrValueServiceImpl.getListByProductIdAndAttrId 里 eq(getId, attrId)），
//         传 unique 字符串会报「未找到对应的商品SKU」。
const OUT = process.env.TEMP + '\\shot';
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
  page.on('console', m => { if (m.type() === 'error') errors.push('CONSOLE: ' + m.text()); });

  const token = process.argv[2];
  await page.goto(H5, { waitUntil: 'networkidle2', timeout: 60000 });
  await page.evaluate(t => localStorage.setItem('LOGIN_STATUS_TOKEN', t), token);

  const api = (path, method, body) => page.evaluate(async (base, p, m, b, tk) => {
    const r = await fetch(base + p, {
      method: m,
      headers: { 'Content-Type': 'application/json', 'Authori-zation': tk },
      body: b ? JSON.stringify(b) : undefined
    });
    return await r.text();
  }, API, path, method, body, token);
  const J = async (p, m, b) => { try { return JSON.parse(await api(p, m, b)); } catch (e) { return null; } };

  const pid = (await J(P + '/products?page=1&limit=1', 'GET')).data.list[0].id;
  const detail = await J(P + '/product/detail/' + pid, 'GET');
  const pv = detail.data.productValue || {};
  const k = Object.keys(pv)[0];
  const attrValueId = pv[k].id;
  console.log('  商品 id=' + pid + ' 规格="' + k + '" attrValueId=' + attrValueId);

  const addRes = await J(P + '/cart/save', 'POST',
    { productId: pid, productAttrUnique: String(attrValueId), cartNum: 1 });
  console.log('  加购: code=' + addRes.code + ' msg=' + addRes.message);

  const cart = await J(P + '/cart/list?isValid=true', 'GET');
  let cartIds = [];
  const d = cart.data;
  if (d && Array.isArray(d.list)) cartIds = d.list.map(i => i.id);
  else if (Array.isArray(d)) cartIds = d.map(i => i.id);
  else if (d && Array.isArray(d.valid)) cartIds = d.valid.map(i => i.id);
  console.log('  购物车 ids = ' + JSON.stringify(cartIds));

  const pre = await J(P + '/order/pre/order', 'POST', {
    preOrderType: 'shoppingCart',
    orderDetails: cartIds.map(id => ({ shoppingCartId: id, productNum: 1 }))
  });
  console.log('  预下单: code=' + pre.code + ' msg=' + pre.message);
  const preOrderNo = pre.data ? pre.data.preOrderNo : '';
  if (!preOrderNo) { console.log('  [!] 没拿到 preOrderNo'); await browser.close(); return; }
  console.log('  preOrderNo = ' + preOrderNo);

  await page.goto(H5 + '/pages/order/order_confirm/index?preOrderNo=' + preOrderNo,
    { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(5000);

  await page.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 400) {
      window.scrollTo(0, y); await new Promise(r => setTimeout(r, 120));
    }
    window.scrollTo(0, 0);
  });
  await sleep(1200);
  const info = await page.evaluate(() => {
    const txt = document.body.innerText;
    return {
      url: location.href,
      hasRow: txt.includes('配送方式'),
      hasInstant: txt.includes('同城配送'),
      hasExpress: txt.includes('快递发货'),
      snippet: txt.replace(/\s+/g, ' ').substring(0, 320)
    };
  });
  console.log('  url: ' + info.url);
  console.log('  含「配送方式」: ' + info.hasRow + '   含「同城配送」: ' + info.hasInstant + '   含「快递发货」: ' + info.hasExpress);
  console.log('  页面文字: ' + info.snippet);
  await page.screenshot({ path: OUT + '\co-confirm.png', fullPage: true });
  console.log('  已截图(切换前)');

  // 点「配送方式」行，验证能否切到同城配送
  const clicked = await page.evaluate(() => {
    const els = Array.from(document.querySelectorAll('uni-view,div'));
    const cands = els.filter(e => (e.innerText || '').trim().startsWith('配送方式'));
    if (!cands.length) return 'no-candidate';
    cands.sort((a, b) => a.innerText.length - b.innerText.length);
    const row = cands[0];
    const detail = 'len=' + row.innerText.length + ' cls=' + (row.className || '');
    row.click();
    return detail;
  });
  console.log('  点击「配送方式」行: ' + clicked);
  await sleep(4500);
  const after = await page.evaluate(() => {
    const t = document.body.innerText.replace(/\s+/g, " ");
    return { instant: t.includes('同城配送'), fee: t.includes('同城配送费'), snippet: t.substring(0, 300) };
  });
  console.log('  切换后含「同城配送」: ' + after.instant + '   含「同城配送费」: ' + after.fee);
  console.log('  切换后页面: ' + after.snippet);
  await page.screenshot({ path: OUT + '\co-instant.png', fullPage: true });
  console.log('  已截图(切换后) -> co-instant.png');
  console.log('  已截图 -> co-confirm.png');

  console.log('\n=== JS 错误 ===');
  console.log(errors.length ? errors.slice(0, 6).join('\n') : '  (无)');
  await browser.close();
})().catch(e => { console.error('FATAL: ' + e.message); process.exit(1); });
