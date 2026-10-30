/* ============================================================
 * StorApp 视觉升级 — CDP 探查/截图小工具（零依赖）
 *
 * 为什么自己写：本机没有 puppeteer-core，且沙箱下 root 出网被拦，
 * npm 装不了包。Edge 自带 DevTools Protocol，Node 24 自带 WebSocket，
 * 两者对接即可，不需要任何第三方依赖。
 *
 * 用法:
 *   node cdp.js inspect          # 打印首页关键 DOM 结构
 *   node cdp.js shot home.png    # 截首页整页图
 * ============================================================ */
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const H5 = 'http://82.156.226.192:8092/';
const ADMIN = 'http://82.156.226.192/';
const PORT = 19222 + (Number(process.env.CDP_OFFSET) || 0);
const UD = path.join(os.tmpdir(), 'shot', 'ud' + (process.env.CDP_OFFSET || ''));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitJson() {
  for (let i = 0; i < 60; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const list = await r.json();
      const p = list.find((t) => t.type === 'page' && t.webSocketDebuggerUrl);
      if (p) return p;
    } catch {}
    await sleep(400);
  }
  throw new Error('Edge 调试端口没起来');
}

class CDP {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.waiters = new Map();
    ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.waiters.has(msg.id)) {
        const { res, rej } = this.waiters.get(msg.id);
        this.waiters.delete(msg.id);
        msg.error ? rej(new Error(JSON.stringify(msg.error))) : res(msg.result);
      }
    });
  }
  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((res, rej) => {
      this.waiters.set(id, { res, rej });
      setTimeout(() => {
        if (this.waiters.has(id)) { this.waiters.delete(id); rej(new Error(method + ' 超时')); }
      }, 60000);
    });
  }
  async eval(expr) {
    const r = await this.send('Runtime.evaluate', {
      expression: expr, returnByValue: true, awaitPromise: true,
    });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || '页面内异常');
    return r.result.value;
  }
}

async function main() {
  const argv = process.argv.slice(2);
  // --admin 切到 PC 后台（1440x900），默认是 H5 手机端（390x844）
  const admin = argv.includes('--admin');
  // --h5login：先给 H5 端登录再截图（医保凭证这类页面不登录只显示「请先登录」）。
  // H5 的 token 存在 localStorage 的 LOGIN_STATUS_TOKEN，store 初始化时读它，
  // 所以必须在**加载应用之前**写好 —— 等应用起来再写就晚了。
  const h5login = argv.includes('--h5login');
  const args = argv.filter((a) => a !== '--admin' && a !== '--h5login');
  const mode = args[0] || 'inspect';
  const out = args[1] || 'home.png';
  const URL = admin ? ADMIN : H5;
  const VW = admin ? 1440 : 390;
  const VH = admin ? 900 : 844;

  // ⚠️ 每次都清空 profile 再起：复用 profile 时 Edge 会直接从缓存返回**旧的 index.html**，
  //    导致「服务端已经改了、DOM 里却完全没有」的假象 —— 排查这个坑花了很多时间。
  fs.rmSync(UD, { recursive: true, force: true });
  fs.mkdirSync(UD, { recursive: true });

  const child = spawn(EDGE, [
    '--headless=new', `--remote-debugging-port=${PORT}`, `--user-data-dir=${UD}`,
    '--no-first-run', '--no-default-browser-check', '--disable-gpu',
    '--no-sandbox', '--disable-crash-reporter', '--disable-breakpad',
    '--disable-dev-shm-usage',
    `--window-size=${VW},${VH}`, '--hide-scrollbars', 'about:blank',
  ], { stdio: 'ignore' });

  let cdp;
  try {
    const target = await waitJson();
    const ws = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((res, rej) => {
      ws.addEventListener('open', res);
      ws.addEventListener('error', rej);
    });
    cdp = new CDP(ws);
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Network.enable');
    await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
    // 设备视口：H5 按 750rpx 渲染，390 宽 + dsf2 才是真实手机观感
    await cdp.send('Emulation.setDeviceMetricsOverride', {
      width: VW, height: VH, deviceScaleFactor: admin ? 1 : 2, mobile: !admin,
    });

    console.log('navigate -> ' + URL);
    // ⚠️ 必须用 addScriptToEvaluateOnNewDocument 在「文档开始解析之前」装观察器，
    //    否则 navigation 已经跑完，head 的增删全都看不到（踩过）。
    if (admin) {
      await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
        source: `(function(){
          window.__saTrace = [];
          window.__saErrs = [];
          function watch(){
            try {
              if (!document.head) return setTimeout(watch, 0);
              new MutationObserver(function(muts){
                muts.forEach(function(m){
                  m.addedNodes.forEach(function(n){
                    if (n.nodeName === 'LINK' || n.nodeName === 'SCRIPT' || n.nodeName === 'STYLE')
                      window.__saTrace.push('+' + n.nodeName + (n.id ? '#' + n.id : '')
                        + ((n.getAttribute && n.getAttribute('href')) ? '(' + n.getAttribute('href') + ')' : ''));
                  });
                  m.removedNodes.forEach(function(n){
                    if (n.nodeName === 'LINK' || n.nodeName === 'SCRIPT' || n.nodeName === 'STYLE')
                      window.__saTrace.push('-' + n.nodeName + (n.id ? '#' + n.id : '')
                        + ((n.getAttribute && n.getAttribute('href')) ? '(' + n.getAttribute('href') + ')' : ''));
                  });
                });
              }).observe(document.head, { childList: true });
              // 记录 head 被整体替换的情况
              document.addEventListener('DOMContentLoaded', function(){
                window.__saTrace.push('DOMContentLoaded link#storapp-admin=' + !!document.getElementById('storapp-admin'));
              });
            } catch (e) { window.__saTrace.push('observer 装不上: ' + e.message); }
          }
          watch();
          // 细粒度轮询：head 存在的瞬间就盯住 #storapp-admin，
          // 抓「它到 DOMContentLoaded 之间消失」的确切时刻
          var t0 = Date.now(), last = null, poll = setInterval(function () {
            var has = !!document.getElementById('storapp-admin');
            var hasScript = !!document.querySelector('script[data-sa-admin]');
            var cur = has + '/' + hasScript;
            if (cur !== last) {
              window.__saTrace.push('t+' + (Date.now() - t0) + 'ms link/script=' + cur
                + ' readyState=' + document.readyState);
              last = cur;
            }
            if (Date.now() - t0 > 8000) clearInterval(poll);
          }, 20);
          window.addEventListener('error', function(e){
            window.__saErrs.push((e.message || '') + ' @ ' + (e.filename || '') + ':' + (e.lineno || ''));
          }, true);
        })();`,
      });
    }
    // H5 登录必须在 navigate 之前：先把 token 写进 localStorage，再加载应用
    if (h5login) {
      console.log('  H5 登录中…');
      await cdp.send('Page.navigate', { url: H5 });
      await sleep(1500);
      const res = await cdp.eval(`(async()=>{
        try {
          // H5 端接口前缀是 /front-api（见 app/config/app.js 的 domain）
          const r = await fetch('/front-api/api/front/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ account: '13800138000', password: '123456', spread_spid: 0 })
          });
          const j = await r.json();
          if (!j || !j.data || !j.data.token) return 'NO_TOKEN: ' + JSON.stringify(j).slice(0, 220);
          localStorage.setItem('LOGIN_STATUS_TOKEN', j.data.token);
          if (j.data.uid) localStorage.setItem('UID', String(j.data.uid));
          const ui = j.data.userInfo || j.data.user || j.data;
          if (ui) localStorage.setItem('USER_INFO', JSON.stringify(ui));
          return 'OK token=' + String(j.data.token).slice(0, 12) + '… uid=' + j.data.uid
            + ' 实名=' + ((ui && (ui.realName || ui.nickname)) || '无');
        } catch (e) { return 'ERR: ' + e.message; }
      })()`);
      console.log('  ' + res);
      await sleep(400);
    }

    await cdp.send('Page.navigate', { url: URL });
    await sleep(7000);

    if (admin) {
      // 后台要先登录：填账号密码 -> 点登录 -> 等控制台渲染
      console.log('  登录中…');
      const filled = await cdp.eval(`(function(){
        var a = document.querySelector('input[name="username"]');
        var p = document.querySelector('input[name="pwd"]');
        if (!a || !p) return 'no-form';
        function set(el, v) {
          el.value = v;
          el.dispatchEvent(new Event('input', {bubbles:true}));
          el.dispatchEvent(new Event('change', {bubbles:true}));
        }
        set(a, 'admin'); set(p, '123456');
        return 'ok';
      })()`);
      console.log('  表单: ' + filled);
      await sleep(600);
      await cdp.eval(`(function(){
        var btns = Array.from(document.querySelectorAll('button'));
        var b = btns.find(function(x){ return /登\\s*录/.test(x.innerText); }) || btns[0];
        if (b) b.click();
        return !!b;
      })()`);
      await sleep(7000);
      await cdp.eval(`(async()=>{for(let i=0;i<40;i++){ if(location.pathname!=='/login' && document.querySelector('.dashboard-editor-container,.app-container')) return 1; await new Promise(r=>setTimeout(r,500)); } return 0;})()`);
      await sleep(5000);
      const st = await cdp.eval(`JSON.stringify({url:location.href,title:document.title,
        hasDash:!!document.querySelector('.dashboard-editor-container'),
        menus:Array.from(document.querySelectorAll('.el-menu-item,.el-submenu__title')).slice(0,24).map(function(e){return e.innerText.trim();})})`);
      console.log('  ' + st);
      const msgs = await cdp.eval(`Array.from(document.querySelectorAll('.el-message,.el-notification')).map(function(e){return e.innerText.trim();}).join(' | ')`);
      console.log('  页面提示: ' + (msgs || '（无）'));
      const tr = await cdp.eval(`JSON.stringify({link:!!document.getElementById('storapp-admin'),
        railW:Math.round((document.querySelector('.layout-columns-aside')||{getBoundingClientRect:function(){return{width:0}}}).getBoundingClientRect().width),
        nav:(function(){var n=performance.getEntriesByType('navigation')[0]||{};return {transferSize:n.transferSize,decodedBodySize:n.decodedBodySize};})(),
        trace:(window.__saTrace||[]).slice(0,25), errs:(window.__saErrs||[]).slice(0,5)})`);
      console.log('  样式层探针: ' + tr);
    }

    // 滚到底触发懒加载（后台是 PC 布局，不需要）
    if (!admin) {
      await cdp.eval(`(async()=>{const h=document.body.scrollHeight;
        for(let y=0;y<h;y+=300){window.scrollTo(0,y);await new Promise(r=>setTimeout(r,150));}
        window.scrollTo(0,0);return h;})()`);
      await sleep(2500);
    }

    if (mode === 'inspect') {
      // 注意：这里必须用过滤过 --admin 的 args，不能用 process.argv，
      // 否则带 --admin 时下标整体错位（踩过）
      // 可选第二个参数是路径：`inspect x expr.js /pages/user/index`
      // 不给路径时停默认落点（H5 是首页、后台是 /dashboard）。
      // ⚠️ 少了这个参数就会「以为在查某页，其实查的是首页」，白排查半天（踩过）。
      const inspectPath = args[3];
      if (inspectPath) {
        const origin = await cdp.eval('location.origin');
        await cdp.send('Page.navigate', { url: origin + inspectPath });
        await sleep(4000);
        console.log('  已切到 ' + (await cdp.eval('location.pathname')));
      }
      const exprFile = args[2] || 'cdp-inspect-expr.js';
      const info = await cdp.eval(fs.readFileSync(path.join(__dirname, exprFile), 'utf8'));
      console.log(info);
    } else if (mode === 'pix') {
      // 像素探针：把首屏画到 canvas 上量真实颜色，用来判断「那块发灰的青色」到底还在不在。
      // 用法: node cdp.js pix [y] [rows...]
      const y0 = Number(args[1] || 0);
      const rows = (args[2] || '2,20,40,70,84,100,150,200,260,290,310').split(',').map(Number);
      const png = (await cdp.send('Page.captureScreenshot', {
        format: 'png', clip: { x: 0, y: y0, width: 390, height: 844, scale: 1 },
      })).data;
      const info = await cdp.eval(`(async()=>{
        const img = new Image();
        img.src = 'data:image/png;base64,${png}';
        await img.decode();
        const c = document.createElement('canvas');
        c.width = img.width; c.height = img.height;
        const g = c.getContext('2d');
        g.drawImage(img, 0, 0);
        // ⚠️ 这个 png 实际是 2 倍图（780x1688）：Emulation 设了 deviceScaleFactor:2，
        // captureScreenshot 的 clip.scale 不会把它降回 1。所以下面所有坐标都要 ÷2
        // 才是 CSS 像素。之前探针读错行就是这个原因（踩过）。
        const S = c.width / 390;
        const rows = ${JSON.stringify(rows)};
        const out = ['canvas ' + c.width + 'x' + c.height + ' 倍率=' + S];
        for (const y of rows) {
          const d = g.getImageData(0, Math.round(y * S), c.width, 1).data;
          const cols = [];
          for (const x of [3, 20, 45, 100, 195, 300, 370, 386]) {
            const i = Math.round(x * S) * 4;
            cols.push(x + ':#' + [d[i],d[i+1],d[i+2]].map(v=>v.toString(16).padStart(2,'0')).join(''));
          }
          out.push('y=' + y + '  ' + cols.join(' '));
        }
        const d0 = g.getImageData(0, 0, c.width, Math.round(90 * S)).data;
        let teal = 0, tot = 0;
        for (let i = 0; i < d0.length; i += 4) {
          if (d0[i+1] > d0[i] + 6 && d0[i+2] > d0[i] + 6) teal++;
          tot++;
        }
        out.push('首屏 0-90px 青色调像素占比: ' + (100 * teal / tot).toFixed(1) + '%');
        const band = g.getImageData(0, Math.round(42 * S), c.width, Math.round(30 * S));
        let minL = 999, minX = -1, minY = -1, minRGB = '', dark = 0;
        for (let yy = 0; yy < band.height; yy++) {
          for (let xx = 0; xx < band.width; xx++) {
            const i = (yy * band.width + xx) * 4;
            const r = band.data[i], gg = band.data[i+1], bb = band.data[i+2];
            const l = 0.299*r + 0.587*gg + 0.114*bb;
            if (l < 120) dark++;
            if (l < minL) { minL = l; minX = xx; minY = yy; minRGB = '#' + [r,gg,bb].map(v=>v.toString(16).padStart(2,'0')).join(''); }
          }
        }
        out.push('tab 带(42-72) 最暗像素: ' + minRGB + ' 亮度=' + minL.toFixed(0)
          + ' at CSS x=' + (minX / S).toFixed(0) + ' y=' + (42 + minY / S).toFixed(0));
        out.push('tab 带深色像素数: ' + dark + '（>0 表示深色文字已经画出来了）');
        return out.join('\\n');
      })()`);
      console.log(info);
    } else if (mode === 'nav') {
      // 深链导航 + 分段截图。
      // cdp.js 默认只打开站点根路径，看不到子页面（比如 /pages/medical/insurance）。
      // 用法: node cdp.js nav /pages/medical/insurance mi 0,844 800,844
      //       —— args[1]=路径, args[2]=输出前缀, args[3..]=y,h 分段（不给就整页一张）
      const target = args[1];
      if (!target) throw new Error('nav 模式需要路径参数，例如 /pages/medical/insurance');
      const prefix = args[2] || 'nav';
      const origin = await cdp.eval('location.origin');
      const url = target.startsWith('http') ? target : origin + target;
      await cdp.send('Page.navigate', { url });
      await sleep(3500); // SPA 首屏 + 接口
      const before = await cdp.eval('location.href');
      const title = await cdp.eval('document.title');
      console.log('  导航到 ' + before + (title ? '  title=' + title : ''));
      const warns = await cdp.eval(`(()=>{const t=document.body.innerText.slice(0,120).replace(/\\s+/g,' ');return t;})()`);
      console.log('  页面文本开头: ' + warns);
      const segs = process.argv.slice(6).length ? process.argv.slice(6) : process.argv.slice(5);
      if (segs.length && /\d+\s*,\s*\d+/.test(segs[0])) {
        for (const seg of segs) {
          const [y, h] = seg.split(',').map(Number);
          await cdp.eval(`window.scrollTo(0, ${y})`);
          await sleep(900);
          const name = `${prefix}-y${y}.png`;
          const { data } = await cdp.send('Page.captureScreenshot', {
            format: 'png', clip: { x: 0, y, width: VW, height: h || 844, scale: 1 },
          });
          fs.writeFileSync(path.join(os.tmpdir(), 'shot', name), Buffer.from(data, 'base64'));
          console.log('  已保存 ' + name + '  (y=' + y + ' h=' + (h || 844) + ')');
        }
      } else {
        // 整页截图前先做两件事，否则截出来的图会骗人：
        //  1. 隐藏 fixed 定位的「隐藏弹层」（H5 的加购弹窗 .product-window 即使没打开
        //     也有高度，captureBeyondViewport 会把它一起画进去 —— 看上去像页面坏了）。
        //     ⚠️ 它靠 transform 移出屏幕，display/visibility/opacity 都是正常的，
        //     所以只能按类名直接压掉，不能靠「看起来是不是隐藏」来判断（踩过）。
        //  2. 高的小程序页用 documentElement.scrollHeight，body.scrollHeight 有时偏小
        await cdp.eval(`(()=>{
          var kill = ['.product-window', '.page-footer-fixed'];
          var n = 0;
          kill.forEach(function(sel){
            document.querySelectorAll(sel).forEach(function(e){
              if (e.getAttribute('data-sa-hidden')) return;
              e.setAttribute('data-sa-hidden','1');
              e.style.setProperty('display','none','important');
              n++;
            });
          });
          return n;
        })()`);
        await sleep(400);
        const h = await cdp.eval('Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)');
        const name = `${prefix}.png`;
        const { data } = await cdp.send('Page.captureScreenshot', {
          format: 'png', captureBeyondViewport: true,
          clip: { x: 0, y: 0, width: VW, height: Math.min(h, 6000), scale: 1 },
        });
        fs.writeFileSync(path.join(os.tmpdir(), 'shot', name), Buffer.from(data, 'base64'));
        console.log('  已保存 ' + name + '  ' + VW + 'x' + Math.min(h, 6000));
      }
    } else if (mode === 'page') {
      // 整页截图（后台 PC 布局用这个：视口 1440x900 一次拍下，不做分段）
      const name = args[1] || 'page.png';
      const h = admin ? VH : await cdp.eval('document.body.scrollHeight');
      const { data } = await cdp.send('Page.captureScreenshot', {
        format: 'png', captureBeyondViewport: true,
        clip: { x: 0, y: 0, width: VW, height: h, scale: 1 },
      });
      fs.writeFileSync(path.join(os.tmpdir(), 'shot', name), Buffer.from(data, 'base64'));
      console.log('  已保存 ' + name + '  ' + VW + 'x' + h);
    } else if (mode === 'shots') {
      // 分段视口截图：fullPage 会把 position:fixed 画在视口位置（交接文档坑 5），
      // 且 2 倍图整页高度超过模型 8192px 上限。按 y 分段落，每段一张。
      // 用法: node cdp.js shots prefix 0,900 900,900 ...
      const prefix = process.argv[3] || 'shot';
      const dir = path.join(os.tmpdir(), 'shot');
      for (const seg of process.argv.slice(4)) {
        const [y, h] = seg.split(',').map(Number);
        await cdp.eval(`window.scrollTo(0, ${y})`);
        await sleep(900);
        const name = `${prefix}-y${y}.png`;
        const { data } = await cdp.send('Page.captureScreenshot', {
          format: 'png',
          clip: { x: 0, y, width: 390, height: h || 844, scale: 1 },
        });
        fs.writeFileSync(path.join(dir, name), Buffer.from(data, 'base64'));
        console.log('  已保存 ' + name + '  (y=' + y + ' h=' + (h || 844) + ')');
      }
    } else {
      const h = await cdp.eval('document.body.scrollHeight');
      const { data } = await cdp.send('Page.captureScreenshot', {
        format: 'png', captureBeyondViewport: true,
        clip: { x: 0, y: 0, width: 390, height: h, scale: 2 },
      });
      fs.writeFileSync(path.join(os.tmpdir(), 'shot', out), Buffer.from(data, 'base64'));
      console.log('  已保存 ' + out + '  高度 ' + h + 'px');
    }
  } finally {
    try { cdp && cdp.send('Browser.close'); } catch {}
    await sleep(500);
    try { child.kill(); } catch {}
  }
}

main().catch((e) => { console.error('FATAL: ' + e.message); process.exit(1); });
