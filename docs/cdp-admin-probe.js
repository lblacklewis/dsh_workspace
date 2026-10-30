(async function () {
  const out = [];
  const P = (s) => out.push(s);

  function measure(tag) {
    const r = [];
    document.querySelectorAll('.layout-columns-aside li.layout-columns').forEach(function (li) {
      const d = li.querySelector('.font13');
      if (!d) return;
      const b = d.getBoundingClientRect();
      const rr = d.getBoundingClientRect();
      r.push('"' + d.textContent.trim() + '" w=' + Math.round(rr.width) + ' h=' + Math.round(rr.height)
        + ' scrollW=' + d.scrollWidth + ' scrollH=' + d.scrollHeight
        + (rr.height > 20 ? ' [换行了!]' : ''));
    });
    P(tag + ': ' + r.join('  |  '));
  }

  measure('修复前');

  // 试注入候选 CSS，看能不能把标签撑开且不换行
  const css = [
    '.layout-columns-aside li.layout-columns { padding: 0 4px; box-sizing: border-box; }',
    '.layout-columns-aside li.layout-columns .columns-horizontal { padding: 0 4px !important; gap: 4px; }',
    '.layout-columns-aside li.layout-columns .columns-horizontal > i { flex: 0 0 auto !important; margin-right: 0 !important; width: 14px; }',
    '.layout-columns-aside li.layout-columns .columns-horizontal > a { display: flex !important; min-width: 0; }',
    '.layout-columns-aside li.layout-columns .font13 { flex: 0 0 auto !important; white-space: nowrap !important; overflow: visible !important; font-size: 12px !important; line-height: 15px !important; word-break: keep-all !important; }',
    '.layout-columns-aside li.layout-columns .columns-vertical { display: flex !important; flex-direction: column; align-items: center; justify-content: center; }',
    '.layout-columns-aside li.layout-columns .columns-vertical .font13 { margin-top: 1px; }'
  ].join('\n');
  const st = document.createElement('style');
  st.id = 'tmp-probe';
  st.textContent = css;
  document.head.appendChild(st);
  await new Promise(function (r) { setTimeout(r, 400); });

  measure('修复后');

  P('\n=== 修复后逐项定位（确认没有重叠）===');
  document.querySelectorAll('.layout-columns-aside li.layout-columns').forEach(function (li, i) {
    const d = li.querySelector('.font13');
    const ic = li.querySelector('.columns-horizontal > i');
    const dr = d.getBoundingClientRect();
    const ir = ic.getBoundingClientRect();
    P('  [' + i + '] "' + d.textContent.trim() + '" icon x=' + Math.round(ir.left) + '..' + Math.round(ir.right)
      + ' (' + Math.round(ir.width) + ')  text x=' + Math.round(dr.left) + '..' + Math.round(dr.right)
      + ' (' + Math.round(dr.width) + ',h=' + Math.round(dr.height) + ')  li=' + Math.round(li.getBoundingClientRect().width));
  });

  P('\n=== 侧栏是否溢出（li 高度应都为 50）===');
  const hs = Array.from(document.querySelectorAll('.layout-columns-aside li.layout-columns'))
    .map(function (li) { return Math.round(li.getBoundingClientRect().height); });
  P('  高度: ' + hs.join(',') + '  最大=' + Math.max.apply(null, hs));

  P('\n=== 图标是否渲染出宽度 ===');
  document.querySelectorAll('.layout-columns-aside li.layout-columns .columns-horizontal > i').forEach(function (ic, i) {
    const r = ic.getBoundingClientRect();
    P('  [' + i + '] class=' + ic.className + ' w=' + Math.round(r.width) + ' h=' + Math.round(r.height));
  });

  document.getElementById('tmp-probe').remove();
  return out.join('\n');
})()
