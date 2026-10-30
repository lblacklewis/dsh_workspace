(async function () {
  const out = [];
  const P = (s) => out.push(s);
  const token = (document.cookie.match(/token=([^;]+)/) || [])[1] || '';
  P('登录态: ' + location.href + '  token=' + (token ? token.slice(0, 12) + '…' : '无'));

  async function call(url) {
    const r = await fetch(url, { headers: { 'Authori-zation': token } });
    const t = await r.text();
    let brief = t.slice(0, 160);
    try { const j = JSON.parse(t); brief = 'code=' + j.code + ' message=' + j.message + ' data=' + JSON.stringify(j.data).slice(0, 90); } catch (e) {}
    return brief;
  }
  P('\n=== 报错的两个接口 ===');
  P('  user/overview -> ' + await call('/dev-api/api/admin/statistics/user/overview?dateLimit=lately7'));
  P('  user/channel  -> ' + await call('/dev-api/api/admin/statistics/user/channel'));

  P('\n=== 控制台其它接口 ===');
  for (const p of ['statistics/home/index', 'statistics/home/chart/user',
                   'statistics/home/chart/order', 'statistics/home/operating/data']) {
    P('  ' + p + ' -> ' + await call('/dev-api/api/admin/' + p));
  }

  P('\n=== 控制台可见文本（前 600 字）===');
  P('  ' + (document.body.innerText || '').replace(/\s+/g, ' ').slice(0, 600));

  P('\n=== 控制台卡片/区块 DOM ===');
  const cands = ['.dashboard-editor-container', '.app-container', '.main-container', '.el-card',
                 '.dashboard', '.index', '.home', '.base-info', '.grid-menu', '.user-overview'];
  cands.forEach((s) => {
    const n = document.querySelectorAll(s).length;
    if (n) P('  ' + s + ' : ' + n);
  });

  P('\n=== 侧边栏菜单 ===');
  document.querySelectorAll('.el-menu-item,.el-submenu__title,.el-sub-menu__title').forEach((e) => {
    P('  - ' + e.innerText.trim());
  });

  P('\n=== 主内容区顶层结构 ===');
  const main = document.querySelector('.app-main') || document.querySelector('.main-container') || document.querySelector('#app');
  if (main) {
    (function walk(n, d) {
      if (d > 3) return;
      const r = n.getBoundingClientRect();
      P('  '.repeat(d + 1) + n.tagName.toLowerCase()
        + (n.id ? '#' + n.id : '')
        + (typeof n.className === 'string' && n.className ? '.' + n.className.trim().split(/\s+/).slice(0, 3).join('.') : '')
        + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + ']');
      Array.from(n.children).slice(0, 6).forEach(function (k) { walk(k, d + 1); });
    })(main, 0);
  }
  return out.join('\n');
})()
