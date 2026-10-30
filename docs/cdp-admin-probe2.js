(async function () {
  const out = [];
  const P = (s) => out.push(s);
  const sleep = (ms) => new Promise(function (r) { setTimeout(r, ms); });

  function snapshot(tag) {
    const rows = [];
    document.querySelectorAll('.layout-columns-aside li.layout-columns').forEach(function (li) {
      const d = li.querySelector('.font13');
      const ic = li.querySelector('.columns-horizontal > i');
      const dr = d.getBoundingClientRect();
      const ir = ic.getBoundingClientRect();
      const lr = li.getBoundingClientRect();
      rows.push(d.textContent.trim() + ':li=' + Math.round(lr.width)
        + ',ic=' + Math.round(ir.width) + 'x' + Math.round(ir.height)
        + ',tx=' + Math.round(dr.width) + 'x' + Math.round(dr.height)
        + ',gap=' + Math.round(dr.left - ir.right)
        + (dr.right > lr.right - 1 ? ',溢出' : '')
        + (ir.height < 5 ? ',图标缺' : ''));
    });
    P(tag + ':');
    rows.forEach(function (r) { P('    ' + r); });
    const wrap = document.querySelector('.layout-aside');
    const menu = document.querySelector('.layout-aside .el-scrollbar, .layout-aside .el-menu');
    P('    侧栏: rail=' + Math.round(document.querySelector('.layout-columns-aside').getBoundingClientRect().width)
      + ' 二级=' + Math.round(wrap.getBoundingClientRect().width)
      + ' 二级x=' + Math.round(wrap.getBoundingClientRect().left));
  }

  snapshot('基线');

  function apply(id, css) {
    const old = document.getElementById(id);
    if (old) old.remove();
    const s = document.createElement('style');
    s.id = id;
    s.textContent = css;
    document.head.appendChild(s);
  }

  // 候选 A：加宽图标轨 + 修图标 + 标签不换行不裁切
  apply('pA', [
    '.layout-columns-aside { width: 108px !important; }',
    '.layout-columns-aside .el-scrollbar, .layout-columns-aside .el-scrollbar__view { width: 107px !important; }',
    '.layout-columns-aside ul li { width: 108px !important; }',
    '.layout-columns-aside ul li .columns-horizontal { width: 108px !important; padding: 0 6px !important; box-sizing: border-box !important; }',
    '.layout-columns-aside ul li .columns-horizontal > i { flex: 0 0 auto !important; margin-right: 5px !important; width: 15px !important; height: 15px !important; font-size: 15px !important; line-height: 15px !important; }',
    '.layout-columns-aside ul li .columns-horizontal > a { flex: 0 0 auto !important; display: flex !important; }',
    '.layout-columns-aside ul li .font13 { flex: 0 0 auto !important; white-space: nowrap !important; overflow: visible !important; font-size: 13px !important; word-break: keep-all !important; }',
    '.layout-columns-aside ul .columns-card { width: 108px !important; }',
    '.layout-columns-aside ul .columns-round { width: 92px !important; }',
    '.layout-columns-aside .el-icon-clipboard::before { content: "\\e78c" !important; }',
    '.layout-aside.layout-aside-width-default { width: 218px !important; }',
    '.layout-aside .el-menu-item, .layout-aside .el-submenu__title { white-space: nowrap !important; }'
  ].join('\n'));
  await sleep(500);
  snapshot('候选A(加宽 108px + 修图标)');

  document.getElementById('pA').remove();
  await sleep(300);

  // 候选 B：图标轨只留图标（隐藏文字），80px 不动
  apply('pB', [
    '.layout-columns-aside ul li .columns-horizontal > a { display: none !important; }',
    '.layout-columns-aside ul li .columns-horizontal { padding: 0 !important; }',
    '.layout-columns-aside ul li .columns-horizontal > i { margin-right: 0 !important; font-size: 19px !important; width: 19px !important; height: 19px !important; line-height: 19px !important; }',
    '.layout-columns-aside .el-icon-clipboard::before { content: "\\e78c" !important; }'
  ].join('\n'));
  await sleep(500);
  snapshot('候选B(80px 纯图标)');
  document.getElementById('pB').remove();

  P('\n=== 图标字体里有没有 clipboard 相关 glyph ===');
  const sheetInfo = [];
  for (const ss of Array.from(document.styleSheets)) {
    const href = ss.href || '';
    if (!/iconfont|element-icons|font/i.test(href)) continue;
    sheetInfo.push(href);
  }
  P('  字体样式表: ' + (sheetInfo.join(', ') || '（无）'));
  P('  el-icon-clipboard 计算 font-family: '
    + getComputedStyle(document.querySelector('.el-icon-clipboard') || document.body).fontFamily);
  P('  el-icon-menu 计算 font-family: '
    + getComputedStyle(document.querySelector('.el-icon-menu') || document.body).fontFamily);
  return out.join('\n');
})()
