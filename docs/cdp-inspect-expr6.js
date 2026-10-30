(function () {
  const out = [];
  const P = (s) => out.push(s);
  function brief(el) {
    const c = el.getAttribute && el.getAttribute('class');
    return el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (c ? '.' + c.trim().split(/\s+/).join('.') : '');
  }
  function det(n) {
    const r = n.getBoundingClientRect();
    const st = getComputedStyle(n);
    return brief(n) + ' y=' + Math.round(r.top + window.scrollY) + ' x=' + Math.round(r.left)
      + ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + ']'
      + ' bg=' + st.backgroundColor
      + ' bgimg=' + (st.backgroundImage === 'none' ? 'none' : st.backgroundImage.slice(0, 90))
      + ' color=' + st.color + ' fs=' + st.fontSize + ' fw=' + st.fontWeight
      + ' op=' + st.opacity + ' z=' + st.zIndex
      + ' inline="' + (n.getAttribute('style') || '').slice(0, 80) + '"';
  }

  P('=== 视口前 320px 内、有任何非透明背景/背景图的元素 ===');
  document.querySelectorAll('*').forEach((e) => {
    const r = e.getBoundingClientRect();
    if (r.height < 2 || r.width < 2) return;
    if (r.top + window.scrollY > 320) return;
    const st = getComputedStyle(e);
    if (st.backgroundColor === 'rgba(0, 0, 0, 0)' && st.backgroundImage === 'none') return;
    P('  ' + det(e));
  });

  P('\n=== 顶部 tab 的文字与容器 (y=43 附近) ===');
  const nav = document.querySelector('.navTabBox');
  if (nav) {
    P('  ' + det(nav));
    P('  父链:');
    let n = nav.parentNode;
    for (let i = 0; i < 3 && n; i++) { P('    ' + det(n)); n = n.parentNode; }
    P('  子项:');
    Array.from(nav.querySelectorAll('.longItem')).forEach((e) => P('    ' + det(e)
      + ' text="' + (e.textContent || '').trim() + '"'));
    P('  outerHTML: ' + nav.outerHTML.replace(/\s+/g, ' ').slice(0, 420));
  } else { P('  没有 .navTabBox'); }

  P('\n=== 搜索框 ===');
  const sb = document.querySelector('.serch-wrapper');
  if (sb) {
    P('  ' + det(sb));
    P('  父链:');
    let n = sb.parentNode;
    for (let i = 0; i < 3 && n; i++) { P('    ' + det(n)); n = n.parentNode; }
  }

  P('\n=== .my-main / #home / .sys-head 的尺寸与背景 ===');
  ['.my-main', '#home', '.sys-head', '.mp-header', '.serch-box'].forEach((s) => {
    const e = document.querySelector(s);
    P('  ' + (e ? det(e) : s + ' 无'));
  });
  return out.join('\n');
})()
