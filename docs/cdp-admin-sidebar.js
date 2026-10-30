(function () {
  const out = [];
  const P = (s) => out.push(s);
  function B(el) {
    const c = typeof el.className === 'string' ? el.className.trim().split(/\s+/).join('.') : '';
    return el.tagName.toLowerCase() + (c ? '.' + c : '');
  }
  function line(n) {
    const r = n.getBoundingClientRect();
    const st = getComputedStyle(n);
    return B(n) + ' w=' + Math.round(r.width) + ' h=' + Math.round(r.height)
      + ' x=' + Math.round(r.left) + ' y=' + Math.round(r.top)
      + ' | css w=' + st.width + ' wrap=' + st.whiteSpace + ' wordBreak=' + st.wordBreak
      + ' disp=' + st.display + ' flexWrap=' + st.flexWrap + ' align=' + st.alignItems
      + ' box=' + st.boxSizing + ' p=' + st.padding + ' m=' + st.margin
      + ' fs=' + st.fontSize + ' ls=' + st.letterSpacing + ' minW=' + st.minWidth;
  }

  P('=== 前 4 个侧栏项逐层量 ===');
  Array.from(document.querySelectorAll('.layout-columns-aside li.layout-columns')).slice(0, 4).forEach((li, i) => {
    P('--- 第 ' + (i + 1) + ' 项 ---');
    P('  ' + line(li));
    Array.from(li.children).forEach((c) => {
      P('    ' + line(c));
      Array.from(c.children).forEach((g) => {
        P('      ' + line(g) + '  text="' + (g.textContent || '').trim() + '"');
      });
    });
  });

  P('\n=== ul / el-scrollbar__view 宽度 ===');
  ['.layout-columns-aside', '.layout-columns-aside ul', '.layout-columns-aside .el-scrollbar',
   '.layout-columns-aside .el-scrollbar__view'].forEach((s) => {
    const e = document.querySelector(s);
    P('  ' + s + ' -> ' + (e ? line(e) : '无'));
  });

  P('\n=== .font13 的全部计算样式（关键几条）===');
  const f = document.querySelector('.layout-columns-aside .font13');
  if (f) {
    const st = getComputedStyle(f);
    ['width','height','display','position','flex','flexWrap','alignItems','justifyContent',
     'whiteSpace','wordBreak','overflowWrap','fontSize','lineHeight','padding','margin',
     'textAlign','boxSizing','minWidth','maxWidth','overflow'].forEach((k) => {
      P('  ' + k + ' = ' + st[k]);
    });
  }

  P('\n=== 侧栏 li 的父链（谁给的宽度约束）===');
  let n = document.querySelector('.layout-columns-aside li.layout-columns');
  if (n) {
    n = n.parentNode;
    for (let i = 0; i < 5 && n; i++) {
      P('  '.repeat(i) + line(n));
      n = n.parentNode;
    }
  }

  P('\n=== 命中的相关 CSS 规则（宽/换行相关）===');
  const seen = new Set();
  for (const ss of Array.from(document.styleSheets)) {
    let rules; try { rules = ss.cssRules; } catch (e) { continue; }
    if (!rules) continue;
    for (const r of Array.from(rules)) {
      if (!r.selectorText) continue;
      if (!/layout-columns|columns-vertical|columns-horizontal|font13|layout-aside/.test(r.selectorText)) continue;
      const t = r.style.cssText;
      if (!/width|white-space|flex|display|wrap/.test(t)) continue;
      const key = r.selectorText + t;
      if (seen.has(key)) continue;
      seen.add(key);
      P('  ' + r.selectorText + ' { ' + t.slice(0, 130) + ' }');
    }
  }
  P('  共 ' + seen.size + ' 条');
  return out.join('\n');
})()
