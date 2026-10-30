(function () {
  const out = [];
  const P = (s) => out.push(s);
  P('=== 注入结果 ===');
  P('  #sa-trustbar : ' + !!document.getElementById('sa-trustbar'));
  P('  #sa-knowledge: ' + !!document.getElementById('sa-knowledge'));
  P('  .sa-tags 数  : ' + document.querySelectorAll('.sa-tags').length);
  P('  .sa-panel-more 数: ' + document.querySelectorAll('.sa-panel-more').length);
  P('  window.__saInjectV2: ' + !!window.__saInjectV2);

  P('\n=== .page-design 的直接子节点 ===');
  const pd = document.querySelector('.page-design.ysize');
  if (pd) {
    Array.from(pd.children).forEach((e, i) => {
      const r = e.getBoundingClientRect();
      P('  [' + i + '] ' + e.tagName.toLowerCase() + (e.id ? '#' + e.id : '')
        + (typeof e.className === 'string' && e.className ? '.' + e.className.trim().split(/\s+/).slice(0, 2).join('.') : '')
        + ' y=' + Math.round(r.top + window.scrollY) + ' h=' + Math.round(r.height));
    });
  } else {
    P('  没有 .page-design.ysize');
  }

  P('\n=== .goodList 的父链（placeKnowledge 靠这条链找插入点）===');
  let n = document.querySelector('.goodList');
  if (!n) P('  没有 .goodList');
  let depth = 0;
  while (n && depth < 8) {
    const r = n.getBoundingClientRect();
    P('  '.repeat(depth) + n.tagName.toLowerCase() + (n.id ? '#' + n.id : '')
      + (typeof n.className === 'string' && n.className ? '.' + n.className.trim().split(/\s+/).slice(0, 2).join('.') : '')
      + ' h=' + Math.round(r.height));
    if (n === pd) { P('  ^ 到达 page-design'); break; }
    n = n.parentNode;
    depth++;
  }

  P('\n=== 页面高度 + 最后一个块 ===');
  P('  scrollHeight = ' + document.body.scrollHeight);
  const body = document.querySelector('uni-page-body');
  if (body) {
    Array.from(body.children).forEach((e, i) => {
      const r = e.getBoundingClientRect();
      P('  [' + i + '] ' + e.tagName.toLowerCase() + (e.id ? '#' + e.id : '')
        + ' y=' + Math.round(r.top + window.scrollY) + ' h=' + Math.round(r.height));
    });
  }
  return out.join('\n');
})()
