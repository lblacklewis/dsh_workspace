(function () {
  const out = [];
  const P = (s) => out.push(s);

  P('=== 目标元素当前的计算样式 ===');
  const cands = [];
  document.querySelectorAll('.page_count > uni-view').forEach((e) => cands.push(['.page_count > uni-view[' + Array.from(e.parentNode.children).indexOf(e) + ']', e]));
  document.querySelectorAll('.my-main').forEach((e) => {
    cands.push(['.my-main', e]);
    cands.push(['.my-main.parent', e.parentNode]);
  });
  document.querySelectorAll('.navTabBox').forEach((e) => cands.push(['.navTabBox', e]));
  document.querySelectorAll('.navTabBox .longItem').forEach((e, i) => { if (i < 2) cands.push(['.longItem[' + i + ']', e]); });
  document.querySelectorAll('#sa-trustbar').forEach((e) => cands.push(['#sa-trustbar', e]));

  cands.forEach(([name, e]) => {
    const st = getComputedStyle(e);
    P('  ' + name + ' bgc=' + st.backgroundColor + ' bgi=' + (st.backgroundImage === 'none' ? 'none' : st.backgroundImage.slice(0, 70))
      + ' color=' + st.color + ' fs=' + st.fontSize
      + ' inline="' + (e.getAttribute('style') || '').slice(0, 100) + '"');
  });

  P('\n=== 我们注入的 style 在哪、是否最后 ===');
  const head = document.head;
  const styles = Array.from(head.querySelectorAll('style, link'));
  styles.forEach((e, i) => {
    const id = e.id || (e.tagName.toLowerCase() === 'link' ? 'link:' + (e.getAttribute('href') || '').slice(-20) : '(无id)');
    P('  [' + i + '/' + (styles.length - 1) + '] ' + id + ' len=' + (e.textContent || '').length);
  });

  P('\n=== 我写的规则真的进浏览器了吗（在 sheet 里找）===');
  let found = { bagGrad: 0, pageCountChild: 0, navItem: 0, trustbar: 0, cardModule: 0 };
  for (const ss of Array.from(document.styleSheets)) {
    let rules;
    try { rules = ss.cssRules; } catch (e) { continue; }
    if (!rules) continue;
    const owner = ss.ownerNode && ss.ownerNode.id ? ss.ownerNode.id : '?';
    for (const r of Array.from(rules)) {
      if (!r.selectorText) continue;
      if (owner !== 'storapp-modern') continue;
      if (r.selectorText.includes('.bag-gradient')) found.bagGrad++;
      if (r.selectorText.includes('.page_count > uni-view')) found.pageCountChild++;
      if (r.selectorText.includes('.navTabBox')) found.navItem++;
      if (r.selectorText.includes('sa-trustbar')) found.trustbar++;
      if (r.selectorText.includes('.page-design.ysize > uni-view')) found.cardModule++;
    }
  }
  P('  ' + JSON.stringify(found));

  P('\n=== 逐条验证：这些选择器能匹配到元素吗 ===');
  const sels = [
    '.page_count .bag-gradient',
    '.page_count > uni-view > uni-view',
    '.page-design.ysize > uni-view',
    '.page_count .navTabBox .tabNav .longItem',
    '#sa-trustbar'
  ];
  sels.forEach((s) => {
    let n = 0; try { n = document.querySelectorAll(s).length; } catch (e) { n = -1; }
    P('  ' + s + ' -> ' + n + ' 个');
  });

  P('\n=== 实际命中的 CSS 规则（对第 2 个 .page_count > uni-view）===');
  const t = document.querySelectorAll('.page_count > uni-view')[1];
  if (t) {
    const inlineBg = t.getAttribute('style');
    P('  inline style = ' + inlineBg);
    // 用 getMatchedCSSRules 不可用，改为暴力扫描所有 sheet
    for (const ss of Array.from(document.styleSheets)) {
      let rules; try { rules = ss.cssRules; } catch (e) { continue; }
      if (!rules) continue;
      const owner = ss.ownerNode && ss.ownerNode.id ? ss.ownerNode.id : '?';
      for (const r of Array.from(rules)) {
        if (!r.selectorText) continue;
        try { if (t.matches(r.selectorText) && /background/.test(r.style.cssText)) {
          P('    [' + owner + '] ' + r.selectorText + ' { ' + r.style.cssText.slice(0, 110) + ' }');
        } } catch (e) {}
      }
    }
  }
  return out.join('\n');
})()
