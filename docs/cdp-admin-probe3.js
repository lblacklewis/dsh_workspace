(function () {
  const out = [];
  const P = (s) => out.push(s);

  const st = document.getElementById('storapp-admin');
  P('=== 我们的 style 元素 ===');
  if (!st) {
    P('  没找到 #storapp-admin');
  } else {
    P('  存在，长度 ' + st.textContent.length);
    const all = Array.from(document.head.querySelectorAll('style, link'));
    P('  在 head 里的位置: ' + (all.indexOf(st) + 1) + ' / ' + all.length);
    P('  含 layout-columns-aside: ' + st.textContent.includes('layout-columns-aside'));
    P('  含 108px: ' + st.textContent.includes('108px'));
  }

  P('\n=== 对这个 li 生效的、含 width/white-space 的全部规则（按 sheet 顺序）===');
  const li = document.querySelector('.layout-columns-aside li.layout-columns');
  const font = document.querySelector('.layout-columns-aside .font13');
  const targets = [['li', li], ['.font13', font], ['.columns-horizontal', document.querySelector('.layout-columns-aside .columns-horizontal')]];
  targets.forEach(function (pair) {
    P('--- ' + pair[0] + ' ---');
    for (const ss of Array.from(document.styleSheets)) {
      let rules; try { rules = ss.cssRules; } catch (e) { continue; }
      if (!rules) continue;
      const owner = (ss.ownerNode && ss.ownerNode.id) ? ss.ownerNode.id : (ss.href ? 'link' : 'build');
      for (const r of Array.from(rules)) {
        if (!r.selectorText || !r.style) continue;
        const css = r.style.cssText || '';
        if (!/width|white-space|flex|display/.test(css)) continue;
        let hit = false;
        try { hit = pair[1] && pair[1].matches(r.selectorText); } catch (e) {}
        if (!hit) continue;
        P('  [' + owner + '] ' + r.selectorText);
        P('      { ' + css.slice(0, 150) + ' }');
      }
    }
  });

  P('\n=== 我们那条规则在 sheet 里长什么样 ===');
  for (const ss of Array.from(document.styleSheets)) {
    if (!ss.ownerNode || ss.ownerNode.id !== 'storapp-admin') continue;
    let n = 0;
    for (const r of Array.from(ss.cssRules)) {
      if (!r.selectorText) continue;
      if (!/layout-columns-aside/.test(r.selectorText)) continue;
      n++;
      if (n <= 8) P('  ' + r.selectorText + ' { ' + (r.style.cssText || '').slice(0, 120) + ' }');
    }
    P('  该 sheet 里 layout-columns-aside 规则数: ' + n);
  }
  return out.join('\n');
})()
