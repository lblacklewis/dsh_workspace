(function () {
  const out = [];
  const P = (s) => out.push(s);
  function B(el) {
    const c = typeof el.className === 'string' ? el.className.trim().split(/\s+/).join('.') : '';
    return el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (c ? '.' + c : '');
  }
  function line(n) {
    const r = n.getBoundingClientRect();
    const st = getComputedStyle(n);
    return B(n) + ' x=' + Math.round(r.left) + ' y=' + Math.round(r.top)
      + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + ']'
      + ' pos=' + st.position + ' z=' + st.zIndex + ' disp=' + st.display
      + ' ovf=' + st.overflow + ' bg=' + st.backgroundColor
      + ' p=' + st.padding + ' m=' + st.margin;
  }

  P('=== 布局关键容器 ===');
  ['.layout-container', '.layout-columns-aside', '.layout-columns-warp', '.layout-aside',
   '.el-aside', '.layout-backtop', '.el-scrollbar', '.layout-breadcrumb-seting',
   '.layout-aside-pc', '.aside', '.layout-aside-width-default'].forEach((s) => {
    document.querySelectorAll(s).forEach((e, i) => { if (i < 2) P('  ' + s + ' -> ' + line(e)); });
  });

  P('\n=== 侧边栏内部层级（.layout-columns-aside 下 depth 4）===');
  const aside = document.querySelector('.layout-columns-aside');
  if (aside) {
    (function walk(n, d) {
      if (d > 4) return;
      P('  '.repeat(d + 1) + line(n));
      Array.from(n.children).slice(0, 8).forEach(function (k) { walk(k, d + 1); });
    })(aside, 0);
  }

  P('\n=== 侧边栏里的可见文本块（前 30 个）===');
  let cnt = 0;
  document.querySelectorAll('.layout-columns-aside *').forEach((e) => {
    if (cnt > 30) return;
    const t = (e.textContent || '').trim();
    if (!t) return;
    if (e.children.length && e.children.length > 0) return;
    const r = e.getBoundingClientRect();
    P('  x=' + Math.round(r.left) + ' y=' + Math.round(r.top) + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + '] "'
      + t.slice(0, 14) + '" ' + B(e) + ' fs=' + getComputedStyle(e).fontSize
      + ' color=' + getComputedStyle(e).color);
    cnt++;
  });

  P('\n=== 搜索框/用户区（右上）===');
  document.querySelectorAll('.layout-navbars-container, .navbar, .right-menu, .el-dropdown').forEach((e, i) => {
    if (i < 6) P('  ' + line(e) + '  text="' + (e.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 50) + '"');
  });

  P('\n=== 面包屑 / 顶部栏 ===');
  document.querySelectorAll('.layout-breadcrumb, .breadcrumb, .el-breadcrumb').forEach((e, i) => {
    if (i < 4) P('  ' + line(e) + '  text="' + (e.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) + '"');
  });

  P('\n=== 主内容区卡片（前 12 个 .el-card）===');
  Array.from(document.querySelectorAll('.el-card')).slice(0, 12).forEach((e, i) => {
    P('  [' + i + '] ' + line(e) + '  text="' + (e.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 40) + '"');
  });

  P('\n=== 控制台组件根 ===');
  ['.dashboard-editor-container', '.dashboard', '.home', '.index'].forEach((s) => {
    const e = document.querySelector(s);
    if (e) P('  ' + s + ' -> ' + line(e));
  });
  const appMain = document.querySelector('.layout-backtop');
  if (appMain) {
    P('\n.layout-backtop 直接子节点：');
    Array.from(appMain.children).forEach((e) => P('  ' + line(e)));
  }
  return out.join('\n');
})()
