(function () {
  const out = [];
  const P = (s) => out.push(s);

  P('=== 逐点扫描 y=0..84，看每一行到底是谁在画 ===');
  for (const y of [45, 48, 52, 55, 58, 62]) {
    const hits = [];
    for (const x of [27, 60, 100, 160, 220, 285, 340, 386]) {
      const e = document.elementFromPoint(x, y);
      if (!e) { hits.push(x + ':无'); continue; }
      const st = getComputedStyle(e);
      hits.push(x + ':' + e.tagName.toLowerCase()
        + (e.className && typeof e.className === 'string' ? '.' + e.className.trim().split(/\s+/)[0] : '')
        + '{' + st.fontSize + ',' + st.color + ',"' + (e.textContent || '').trim().slice(0, 8) + '"}');
    }
    P('  y=' + y + '  ' + hits.join('  '));
  }

  P('\n=== .longItem 的完整父链（含 scroll-view 中间层）===');
  const li = document.querySelector('.page_count .navTabBox .longItem');
  let n = li;
  for (let i = 0; i < 8 && n; i++) {
    const st = getComputedStyle(n);
    P('  '.repeat(i) + n.tagName.toLowerCase()
      + (n.id ? '#' + n.id : '')
      + (n.className && typeof n.className === 'string' && n.className ? '.' + n.className.trim().split(/\s+/).join('.') : '')
      + ' fs=' + st.fontSize + ' color=' + st.color + ' overflow=' + st.overflow
      + ' scrollW=' + n.scrollWidth + ' clientW=' + n.clientWidth);
    n = n.parentNode;
  }

  P('\n=== .longItem 内部结构 ===');
  P('  ' + (li ? li.outerHTML.replace(/\s+/g, ' ').slice(0, 300) : '无'));

  P('\n=== 我的 8-6 规则是否匹配 .longItem ===');
  const sels = [
    '.page_count .navTabBox .longItem',
    '.page_count .navTabBox .longItem.click',
    '.page_count .navTabBox .longItem:first-child',
    '.page_count .navTabBox .longItem .uni-text',
    '.page_count .navTabBox .longItem span'
  ];
  sels.forEach((s) => {
    let m = 0, tot = 0;
    document.querySelectorAll('.page_count .navTabBox .longItem').forEach((e) => { tot++; if (e.matches(s)) m++; });
    P('  ' + s + ' -> 命中 ' + m + '/' + tot);
  });

  P('\n=== 所有 sheet 里匹配 .longItem 且设了 font-size/color 的规则（按优先级顺序列出）===');
  const list = [];
  for (const ss of Array.from(document.styleSheets)) {
    let rules; try { rules = ss.cssRules; } catch (e) { continue; }
    if (!rules) continue;
    const owner = ss.ownerNode && ss.ownerNode.id ? ss.ownerNode.id : 'build';
    for (const r of Array.from(rules)) {
      if (!r.selectorText) continue;
      if (!/longItem/.test(r.selectorText)) continue;
      if (!/font-size|color/.test(r.style.cssText)) continue;
      list.push('[' + owner + '] ' + r.selectorText + ' { '
        + (r.style.fontSize ? 'font-size:' + r.style.fontSize + ';' : '')
        + (r.style.color ? 'color:' + r.style.color + ';' : '')
        + (r.style.cssText.includes('!important') ? ' !important' : '') + ' }');
    }
  }
  list.forEach((s) => P('  ' + s));
  P('  共 ' + list.length + ' 条');
  return out.join('\n');
})()
