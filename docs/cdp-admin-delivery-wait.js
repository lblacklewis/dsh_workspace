(async function () {
  // 等卡片真正渲染出来再截图用（避免截到「请求还没回来」的空页面）
  var t0 = Date.now();
  while (Date.now() - t0 < 20000) {
    var grid = document.querySelector('.pv-grid');
    if (grid && grid.querySelectorAll('.pv-cell').length >= 5) {
      var cards = grid.querySelectorAll('.pv-cell');
      var tags = [];
      cards.forEach(function (c) {
        var t = c.querySelector('.el-tag');
        tags.push((c.querySelector('.pv-name') || {}).innerText + '=' + (t ? t.innerText : '?'));
      });
      return '  渲染完成 (' + (Date.now() - t0) + 'ms)  共 ' + cards.length + ' 张卡\n  ' + tags.join(' | ');
    }
    await new Promise(function (r) { setTimeout(r, 300); });
  }
  return '  ❌ 20 秒内没渲染出卡片';
})()
