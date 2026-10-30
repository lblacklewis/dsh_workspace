(async function () {
  var out = [];
  var P = function (s) { out.push(s); };
  var sleep = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };

  P('  当前页: ' + location.pathname);

  var el = document.querySelector('.mi-entry');
  if (!el) { P('  ❌ 找不到 .mi-entry'); return out.join('\n'); }
  var r = el.getBoundingClientRect();
  P('  入口位置 y=' + Math.round(r.top + scrollY) + '  h=' + Math.round(r.height));

  // 确认入口在 DOM 里排在版权图之前
  var host = el.parentNode;
  var kids = Array.prototype.map.call(host.children, function (c) {
    return c.tagName + (typeof c.className === 'string' && c.className ? '.' + c.className.trim().split(/\s+/)[0] : '');
  });
  P('  宿主子节点顺序: ' + kids.join(' | '));

  // 模拟真实点击（不是直接调方法，验证事件链通不通）
  P('\n  模拟点击…');
  el.click();
  await sleep(2500);
  P('  点击后 location: ' + location.pathname);

  if (location.pathname.indexOf('medical') < 0) {
    P('  ⚠️ 没跳过去，改用直接调 vm.goInsurance() 再试');
    try {
      var pages = getCurrentPages();
      var vm = pages[pages.length - 1].$vm;
      if (vm && vm.goInsurance) { vm.goInsurance(); await sleep(2500); P('  调用后 location: ' + location.pathname); }
      else P('  ❌ 拿不到 goInsurance');
    } catch (e) { P('  调用失败: ' + e.message); }
  }

  var ok = location.pathname.indexOf('medical') >= 0;
  P('\n  === ' + (ok ? '✅ 入口点击能进入医保凭证页' : '❌ 入口点击无法跳转') + ' ===');
  if (ok) {
    await sleep(1500);
    var t = (document.body.innerText || '').replace(/\s+/g, ' ');
    P('  凭证页文本: ' + t.slice(0, 160));
    P('  有二维码图: ' + !!document.querySelector('.mi-code-img'));
    P('  倒计时: ' + (document.querySelector('.mi-code-sec') || {}).textContent + ' 秒');
  }
  return out.join('\n');
})()
