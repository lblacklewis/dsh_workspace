(function () {
  const out = [];
  const P = (s) => out.push(s);
  function brief(el) {
    const c = el.getAttribute && el.getAttribute('class');
    return el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (c ? '.' + c.trim().split(/\s+/).join('.') : '');
  }
  function outline(el, depth, maxDepth, maxKids) {
    const lines = [];
    (function walk(n, d) {
      if (d > maxDepth) return;
      const kid = Array.from(n.children);
      const r = n.getBoundingClientRect();
      const st = getComputedStyle(n);
      let txt = '';
      if (!kid.length) txt = ' "' + (n.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 32) + '"';
      lines.push('  '.repeat(d) + brief(n)
        + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + ']'
        + ' y=' + Math.round(r.top + window.scrollY)
        + (st.display === 'none' ? ' NONE' : '')
        + ' pos=' + st.position
        + ' bg=' + st.backgroundColor
        + ' m=' + st.marginTop + ',' + st.marginBottom
        + ' p=' + st.paddingTop + ',' + st.paddingRight + ',' + st.paddingBottom + ',' + st.paddingLeft
        + txt);
      kid.slice(0, maxKids).forEach((k) => walk(k, d + 1));
      if (kid.length > maxKids) lines.push('  '.repeat(d + 1) + '… 另 ' + (kid.length - maxKids) + ' 个');
    })(el, depth);
    return lines.join('\n');
  }
  function box(s, note) {
    const el = document.querySelector(s);
    if (!el) { P('  ' + s + ' : 无'); return; }
    const r = el.getBoundingClientRect();
    const st = getComputedStyle(el);
    P('  ' + s + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + '] y='
      + Math.round(r.top + window.scrollY)
      + ' pos=' + st.position + ' bg=' + st.backgroundColor
      + ' bgimg=' + (st.backgroundImage === 'none' ? 'none' : st.backgroundImage.slice(0, 60))
      + ' m=' + st.marginTop + ',' + st.marginBottom
      + ' p=' + st.paddingTop + ',' + st.paddingBottom
      + ' r=' + st.borderRadius + (note || ''));
  }

  P('=== 顶部/背景相关 ===');
  ['.bag-gradient', '.my-main', '.mp-header', '.serch-box', '.page_count', '.uni-page-body',
    'uni-page-body', '.swiperBg', '.page_swiper', '.bg-img'].forEach((s) => box(s));

  P('\n=== 金刚区（装修组件 0/1）===');
  const menu = document.getElementById('id1772508227561000');
  P(menu ? outline(menu, 0, 4, 6) : '  无');
  P('\n  另一个 id1772508227561001：');
  const m2 = document.getElementById('id1772508227561001');
  P(m2 ? outline(m2, 0, 3, 6) : '  无');

  P('\n=== 商品选项卡（id1772508227561007）depth 4 ===');
  const t = document.getElementById('id1772508227561007');
  P(t ? outline(t, 0, 4, 6) : '  无');

  P('\n=== 富文本（id1772508227561008）depth 4 ===');
  const rt = document.getElementById('id1772508227561008');
  P(rt ? outline(rt, 0, 4, 6) : '  无');
  P('  outerHTML: ' + (rt ? rt.outerHTML.replace(/\s+/g, ' ').slice(0, 400) : ''));

  P('\n=== 商品列表（id1772508227561009）depth 3 ===');
  const gl = document.getElementById('id1772508227561009');
  P(gl ? outline(gl, 0, 3, 6) : '  无');

  P('\n=== 单个 wf-item 内部 depth 3 ===');
  const wf = document.querySelector('.wf-item');
  P(wf ? outline(wf, 0, 3, 8) : '  无');

  P('\n=== .title 元素都有哪些 ===');
  document.querySelectorAll('.title').forEach((e, i) => {
    const r = e.getBoundingClientRect();
    P('  [' + i + '] ' + brief(e) + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + '] "'
      + (e.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 30) + '"');
  });

  P('\n=== 我们样式表当前命中了什么 ===');
  ['.page', '.page-design', '.uni-page-body', '.list', '.goodList', '.item-box', '.item',
    '.price', '.name', '.info_box', '.product-window'].forEach((s) => {
    const n = document.querySelectorAll(s).length;
    P('  ' + s + ' : ' + n + ' 个');
  });
  return out.join('\n');
})()
