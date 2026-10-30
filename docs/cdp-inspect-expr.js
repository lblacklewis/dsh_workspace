(function () {
  const out = [];
  const P = (s) => out.push(s);

  function cls(el) {
    const c = el.getAttribute && el.getAttribute('class');
    return c ? '.' + c.trim().split(/\s+/).join('.') : '';
  }
  function brief(el) {
    let s = el.tagName.toLowerCase() + cls(el);
    if (el.id) s = '#' + el.id + s;
    return s;
  }
  function outline(el, depth, maxDepth, maxKids) {
    const lines = [];
    (function walk(n, d) {
      if (d > maxDepth) return;
      const kid = Array.from(n.children);
      const show = kid.slice(0, maxKids);
      const r = n.getBoundingClientRect ? n.getBoundingClientRect() : { width: 0, height: 0 };
      const st = getComputedStyle(n);
      let txt = '';
      if (!kid.length) txt = ' "' + (n.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 26) + '"';
      lines.push('  '.repeat(d) + brief(n)
        + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + ']'
        + (st.display === 'none' ? ' NONE' : '')
        + txt);
      show.forEach((k) => walk(k, d + 1));
      if (kid.length > maxKids) lines.push('  '.repeat(d + 1) + '… 另 ' + (kid.length - maxKids) + ' 个子节点');
    })(el, depth);
    return lines.join('\n');
  }

  P('URL      : ' + location.href);
  P('视口     : innerWidth=' + window.innerWidth + ' innerHeight=' + window.innerHeight + ' dpr=' + devicePixelRatio);
  P('页面高度 : ' + document.body.scrollHeight);
  P('HEAD 里的 style/link:');
  document.querySelectorAll('head style, head link[rel=stylesheet]').forEach((e) => {
    const n = e.tagName.toLowerCase();
    P('  - ' + (e.id ? '#' + e.id : n) + (n === 'style' ? ' len=' + e.textContent.length : ' href=' + e.getAttribute('href')));
  });

  // 首屏顶层骨架
  const body = document.querySelector('uni-app') || document.body;
  P('\n=== 顶层骨架（depth 3, 每层最多 12 个子节点）===');
  P(outline(body, 0, 3, 12));

  // 首页容器
  P('\n=== .page_count / .index 内容区（depth 4）===');
  const pc = document.querySelector('.page_count') || document.querySelector('.index');
  P(pc ? outline(pc, 0, 4, 12) : '  （没有 .page_count / .index）');

  // 轮播 + 金刚区 + 商品列表 的关键盒模型
  P('\n=== 关键区块盒模型 ===');
  const sels = ['.page_count', '.page_swiper', '.swiper', '.swiperBg', '.menu', '.grid-four',
    '.index-product-wrapper', '.list', '.goodList', '.page-footer', '.title', '.recommend',
    '.index-product', '.goods-list', '.product-list'];
  sels.forEach((s) => {
    const el = document.querySelector(s);
    if (!el) { P('  ' + s + ' : 无'); return; }
    const r = el.getBoundingClientRect();
    const st = getComputedStyle(el);
    P('  ' + s + ' ' + Math.round(r.width) + 'x' + Math.round(r.height)
      + ' @y=' + Math.round(r.top + window.scrollY)
      + ' display=' + st.display + ' bg=' + st.backgroundColor
      + ' margin=' + st.marginTop + '/' + st.marginBottom
      + ' padding=' + st.paddingTop + '/' + st.paddingBottom);
  });

  // 首页各直接子块的顺序 + 高度：用来判断"区块之间有没有分隔"
  P('\n=== 首页竖直排列的区块（按 y 排序）===');
  const rows = [];
  document.querySelectorAll('.page_count > *, .page-design > *, .index > *').forEach((el) => {
    const r = el.getBoundingClientRect();
    if (r.height < 1) return;
    rows.push({ y: Math.round(r.top + window.scrollY), h: Math.round(r.height), s: brief(el), bg: getComputedStyle(el).backgroundColor });
  });
  rows.sort((a, b) => a.y - b.y);
  rows.forEach((r) => P('  y=' + r.y + '  h=' + r.h + '  ' + r.s + '  bg=' + r.bg));

  // 提示文字
  P('\n=== 正文前 400 字 ===');
  P('  ' + document.body.innerText.replace(/\s+/g, ' ').slice(0, 400));
  return out.join('\n');
})()
