(function () {
  const out = [];
  const P = (s) => out.push(s);
  function brief(el) {
    const c = el.getAttribute && el.getAttribute('class');
    return el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (c ? '.' + c.trim().split(/\s+/).join('.') : '');
  }
  function line(n) {
    const r = n.getBoundingClientRect();
    const st = getComputedStyle(n);
    return brief(n) + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + '] y='
      + Math.round(r.top + window.scrollY) + ' bg=' + st.backgroundColor
      + ' m=' + st.marginTop + ',' + st.marginBottom + ' p=' + st.paddingTop + ',' + st.paddingBottom
      + ' ovf=' + st.overflow + ' r=' + st.borderRadius
      + ' inlineStyle="' + (n.getAttribute('style') || '').slice(0, 70) + '"';
  }
  function outline(el, maxDepth, maxKids) {
    const lines = [];
    (function walk(n, d) {
      if (d > maxDepth) return;
      lines.push('  '.repeat(d) + line(n));
      Array.from(n.children).slice(0, maxKids).forEach((k) => walk(k, d + 1));
      if (n.children.length > maxKids) lines.push('  '.repeat(d + 1) + '… 另 ' + (n.children.length - maxKids) + ' 个');
    })(el, 0);
    return lines.join('\n');
  }

  const body = document.querySelector('uni-page-body');
  P('=== uni-page-body 直接子节点（共 ' + body.children.length + '）===');
  Array.from(body.children).forEach((e, i) => P('  [' + i + '] ' + line(e) + ' parent=' + brief(e.parentNode)));

  P('\n=== .page_count 的父链 ===');
  let n = document.querySelector('.page_count');
  while (n && n.tagName !== 'HTML') {
    P('  ' + line(n));
    n = n.parentNode;
  }

  P('\n=== 保障条位置 ===');
  const tb = document.getElementById('sa-trustbar');
  P('  parent=' + brief(tb.parentNode) + ' next=' + brief(tb.nextSibling && tb.nextSibling.nodeType === 1 ? tb.nextSibling : (tb.nextElementSibling || {})));
  P('  ' + line(tb));

  P('\n=== 模块（.page 下）的 3 层包裹 ===');
  const page = document.querySelector('.page');
  P('page 直接子节点 ' + page.children.length + ' 个：');
  Array.from(page.children).forEach((e, i) => P('  [' + i + '] ' + line(e)));
  const m0 = page.children[1];
  if (m0) {
    P('\n第二个模块 outline depth 3：');
    P(outline(m0, 3, 4));
  }
  return out.join('\n');
})()
