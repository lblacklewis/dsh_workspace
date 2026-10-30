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
      + Math.round(r.top + window.scrollY) + ' z=' + st.zIndex + ' pos=' + st.position
      + ' disp=' + st.display + ' vis=' + st.visibility + ' op=' + st.opacity
      + ' bg=' + st.backgroundColor + ' ovf=' + st.overflow
      + ' m=' + st.marginTop + ',' + st.marginRight + ',' + st.marginBottom + ',' + st.marginLeft
      + ' p=' + st.paddingTop + ',' + st.paddingBottom + ' r=' + st.borderRadius;
  }

  P('页面高度: ' + document.body.scrollHeight + '  视口 innerWidth=' + window.innerWidth);
  P('\n=== 保障条 ===');
  const tb = document.getElementById('sa-trustbar');
  P(tb ? line(tb) : '  没有 #sa-trustbar');
  if (tb) P('  outerHTML: ' + tb.outerHTML.replace(/\s+/g, ' ').slice(0, 300));

  P('\n=== 首屏区域（0~340）的所有一层块 ===');
  document.querySelectorAll('uni-page-body > *').forEach((e) => P('  ' + line(e)));

  P('\n=== .page_count 内部 depth 3 ===');
  const pc = document.querySelector('.page_count');
  (function walk(n, d) {
    if (d > 3) return;
    P('  '.repeat(d + 1) + line(n));
    Array.from(n.children).slice(0, 8).forEach((k) => walk(k, d + 1));
  })(pc, 0);

  P('\n=== 顶部那团文字到底是什么（取 y<90 的所有可见文本节点）===');
  document.querySelectorAll('*').forEach((e) => {
    const r = e.getBoundingClientRect();
    if (r.height < 1 || r.width < 1) return;
    if (r.top + window.scrollY > 90) return;
    if (e.children.length) return;
    const t = (e.textContent || '').trim();
    if (!t) return;
    const st = getComputedStyle(e);
    P('  y=' + Math.round(r.top + window.scrollY) + ' x=' + Math.round(r.left) + ' ['
      + Math.round(r.width) + 'x' + Math.round(r.height) + '] "' + t.slice(0, 20) + '" '
      + brief(e) + ' color=' + st.color + ' fs=' + st.fontSize + ' bg=' + st.backgroundColor);
  });

  P('\n=== .navTabBox / .tabNav 相关 ===');
  ['.navTabBox', '.tabNav', '.longItem', '#home', '.mp-header', '.my-main', '.bag-gradient'].forEach((s) => {
    document.querySelectorAll(s).forEach((e, i) => {
      if (i > 3) return;
      P('  ' + s + ' -> ' + line(e));
    });
  });

  P('\n=== 卡片化生效情况（模块一层块）===');
  document.querySelectorAll('uni-page-body > uni-view').forEach((e) => {
    const r = e.getBoundingClientRect();
    if (r.height < 5) return;
    const st = getComputedStyle(e);
    P('  ' + line(e));
  });
  return out.join('\n');
})()
