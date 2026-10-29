const OUT = (process.env.TEMP + '\\shot\\').replace(/\\\\/g, '\\');
const H5 = 'http://82.156.226.192:8092';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const puppeteer = (await import('puppeteer-core')).default;
  const browser = await puppeteer.launch({
    executablePath: 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    headless: 'new',
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
  await page.goto(H5 + '/', { waitUntil: 'networkidle2', timeout: 60000 });
  await sleep(6000);
  // 滚到底触发懒加载，再回到顶部
  await page.evaluate(async () => {
    const h = document.body.scrollHeight;
    for (let y = 0; y < h; y += 300) { window.scrollTo(0, y); await new Promise(r => setTimeout(r, 180)); }
    window.scrollTo(0, 0);
  });
  await sleep(2500);
  await page.screenshot({ path: OUT + 'home-before.png', fullPage: true });

  const info = await page.evaluate(() => {
    const imgs = Array.from(document.querySelectorAll('img'));
    return {
      text: document.body.innerText.replace(/\s+/g, ' ').substring(0, 400),
      imgCount: imgs.length,
      broken: imgs.filter(i => i.naturalWidth === 0).length,
      height: document.body.scrollHeight,
    };
  });
  console.log('  页面文字: ' + info.text);
  console.log('  图片数: ' + info.imgCount + '  加载失败: ' + info.broken);
  console.log('  页面高度: ' + info.height + 'px');
  const cls = await page.evaluate(() => {
    const set = {};
    document.querySelectorAll('*').forEach(el => {
      const c = el.className;
      if (typeof c === 'string' && c && !c.includes('__')) {
        c.split(/\s+/).forEach(x => { if (x && x.length < 40) set[x] = (set[x] || 0) + 1; });
      }
    });
    return Object.entries(set).filter(([k,v]) => v >= 2 && /goods|product|price|name|title|tab|nav|item|card|list|home|index|wrap|con|box/i.test(k)).map(([k,v]) => k + '(' + v + ')').join(' ');
  });
  console.log('  关键类名: ' + cls);
  await browser.close();
})().catch((e) => { console.error('FATAL: ' + e.message); process.exit(1); });
