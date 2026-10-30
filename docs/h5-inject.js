/* ============================================================
 * StorApp H5 — 运行时 DOM 注入层（重绘版）
 *
 * 注入三块内容：
 *   1. #sa-trustbar   服务保障条（轮播下方、金刚区上方）
 *   2. 商品卡角标      OTC / 处方药 / 24h发货，逐卡贴标
 *   3. #sa-knowledge  健康科普区（商品列表之后），并在「为你推荐」加「查看全部」
 *
 * 为什么走运行时注入，而不是改 home_data：
 *   eb_theme.home_data 的 JSON 当前解析是坏的（交接文档第三节），
 *   动首页结构会让后台一保存就整页崩。所以结构改动只用「注入 + 幂等」这条路。
 *
 * 幂等：按 id 建元素；重复执行只跳过。SPA 路由回来若被清掉会自动补回。
 * 回滚：删掉那个带专属 data 属性的脚本块即可，样式留着不报错。
 *
 * ⚠️ 命名禁忌：注入脚本的挂载属性名**只能出现在下方脚本块被拼接的地方**。
 *   这个文件正文里绝不能出现那个属性名的字面量（包括注释），
 *   否则 apply-h5-override.ps1 的计数断言会变 2、报「DOM 注入脚本数不对」。
 * ============================================================ */
(function () {
  var TRUST_ID = 'sa-trustbar';
  var KNOW_ID = 'sa-knowledge';
  if (window.__saInjectV2) return;
  window.__saInjectV2 = 1;

  /* ---------- 通用：线性图标（viewBox 24×24，stroke 跟随 currentColor）---------- */
  var ICONS = {
    shield: '<path d="M12 3.2 5 6v5.4c0 4 2.9 7.6 7 9 4.1-1.4 7-5 7-9V6l-7-2.8Z"/><path d="m9.2 12 2 2 3.6-3.8"/>',
    doctor: '<circle cx="12" cy="8" r="3.4"/><path d="M5.2 20.4c0-3.4 3-5.6 6.8-5.6s6.8 2.2 6.8 5.6"/><path d="M12 13.4v3.2M10.4 15h3.2"/>',
    lock:   '<rect x="4.6" y="10" width="14.8" height="10.2" rx="2.4"/><path d="M8.2 10V7.6a3.8 3.8 0 0 1 7.6 0V10"/><path d="M12 14v2.4"/>',
    truck:  '<path d="M3 6.6h10.2v9.2H3z"/><path d="M13.2 9.8h3.6l3 3.1v2.9h-6.6z"/><circle cx="7.4" cy="17.6" r="1.9"/><circle cx="16.6" cy="17.6" r="1.9"/>',
    pill:   '<path d="M8.6 4.6h6.8a4 4 0 0 1 4 4v6.8a4 4 0 0 1-4 4H8.6a4 4 0 0 1-4-4V8.6a4 4 0 0 1 4-4Z"/><path d="M12 8.4v7.2"/>',
    drop:   '<path d="M12 3.4c2.9 3.4 4.6 5.9 4.6 8.2a4.6 4.6 0 0 1-9.2 0c0-2.3 1.7-4.8 4.6-8.2Z"/>',
    heart:  '<path d="M12 20.2s-6.6-4.1-6.6-8.7a3.7 3.7 0 0 1 6.6-2.4 3.7 3.7 0 0 1 6.6 2.4c0 4.6-6.6 8.7-6.6 8.7Z"/>',
    book:   '<path d="M5 4.6h9.4a2.6 2.6 0 0 1 2.6 2.6v12.2H7.6A2.6 2.6 0 0 1 5 16.8Z"/><path d="M8.4 8.6h5.2M8.4 12h5.2"/>',
    chevron:'<path d="m9.6 6.6 5 5.4-5 5.4"/>'
  };

  function svg(name, cls) {
    return '<svg class="' + (cls || '') + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
      + 'stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
      + ICONS[name] + '</svg>';
  }

  /* ---------- 1. 服务保障条 ---------- */
  var TRUST_ITEMS = [
    ['shield', '正品保障', '假一赔十'],
    ['doctor', '药师审核', '专业把关'],
    ['lock',   '隐私配送', '包装无标识'],
    ['truck',  '24h 发货', '同城速达']
  ];

  function buildTrust() {
    var el = document.createElement('div');
    el.id = TRUST_ID;
    el.setAttribute('role', 'list');
    el.setAttribute('aria-label', '服务保障');
    el.innerHTML = '<div class="sa-trustbar-inner">'
      + TRUST_ITEMS.map(function (it) {
        return '<div class="sa-trustbar-item">'
          + '<span class="sa-trustbar-ic">' + svg(it[0]) + '</span>'
          + '<span class="sa-trustbar-tx"><b>' + it[1] + '</b><i>' + it[2] + '</i></span>'
          + '</div>';
      }).join('')
      + '</div>';
    return el;
  }

  /* 插到首屏之后、金刚区之前：轮播 → 保障条 → 金刚区。
     用 getElementById 定位（装修块 id 是 home_data 生成的雪花 id，别写死）。 */
  function placeTrust() {
    var prev = document.getElementById(TRUST_ID);
    var menu = document.getElementById('id1772508227561001');
    if (!menu) return false;
    var want = menu.parentNode;
    if (!want) return false;
    if (prev && prev.parentNode === want && prev.nextSibling === menu) return false;
    if (prev && prev.parentNode) prev.parentNode.removeChild(prev);
    want.insertBefore(buildTrust(), menu);
    return true;
  }

  /* ---------- 2. 商品卡角标 ----------
   * 处方药/OTC 的区分来自人手维护的白名单（首页 7 个药的 id ↔ 品种是已知且固定的）。
   * ⚠️ 没有写任何促销标签（原 banner 的「满 99 减 20」是假促销，已改掉）。
   * ⚠️ 药品上架前必须过执业药师，这里的分类只是 demo 展示用，上线前要按批准文号核对。 */
  var RX = [159, 102];          // 处方药：布洛芬缓释胶囊、云南白药创可贴
  var OTC = [101, 167, 168, 170, 100];  // OTC / 器械

  /* 首页装修里的商品是快照，卡上没有商品 id，用名字匹配 */
  var NAME_HINT = {
    '布洛芬缓释胶囊': 'rx', '云南白药创可贴': 'rx',
    '感冒灵颗粒': 'otc', '健胃消食片': 'otc', '蒙脱石散': 'otc',
    '维生素C咀嚼片': 'otc', '电子血压计': 'dev'
  };

  function classify(name) {
    if (!name) return '';
    var key = name.replace(/\s+/g, '');
    for (var k in NAME_HINT) {
      if (key.indexOf(k) >= 0) return NAME_HINT[k];
    }
    return '';
  }

  function decorateCards() {
    // 首页商品卡：.wf-item（商品列表）与 .item-box 内的卡
    var cards = document.querySelectorAll('.wf-item, .goodList .item');
    var done = 0;
    Array.prototype.forEach.call(cards, function (card) {
      if (card.querySelector('.sa-tags')) return;
      var info = card.querySelector('.info_box') || card;
      var nameEl = info.querySelector('.text, .name, uni-view[class*="line2"]');
      var kind = classify(nameEl ? nameEl.textContent : '');
      if (!kind) return;

      var box = document.createElement('div');
      box.className = 'sa-tags';
      if (kind === 'rx') {
        box.innerHTML = '<span class="sa-tag sa-tag--rx">处方药</span><span class="sa-tag sa-tag--ship">24h发货</span>';
      } else if (kind === 'otc') {
        box.innerHTML = '<span class="sa-tag sa-tag--otc">OTC</span><span class="sa-tag sa-tag--ship">24h发货</span>';
      } else {
        box.innerHTML = '<span class="sa-tag sa-tag--otc">器械</span><span class="sa-tag sa-tag--ship">24h发货</span>';
      }
      // 插在药名之前
      var title = info.querySelector('.w-full.line2, .text, .name');
      if (title && title.parentNode === info) info.insertBefore(box, title);
      else info.insertBefore(box, info.firstChild);
      done++;
    });
    return done;
  }

  /* ---------- 3. 健康科普区 ----------
   * ⚠️ 这三条是通用用药常识，属于科普不是诊疗建议，都带了免责声明。
   * 库里 eb_article 只有演示文章，没有药学科普内容，所以这里写固定文案 + 链到资讯列表。
   * 上线前必须让执业药师审核文案（尤其是「漏服」「储存」这类容易误导的点）。 */
  var SECTIONS = [
    {
      icon: 'book', tone: 'teal', title: '家庭药箱怎么收纳才安全',
      desc: '内服与外用分开、保留说明书，每 6 个月清一次过期药',
      tags: ['家庭常备']
    },
    {
      icon: 'drop', tone: 'blue', title: '漏服了一次，要不要补双倍剂量',
      desc: '多数药物不建议自行加倍，按说明书或咨询药师处理',
      tags: ['用药安全']
    },
    {
      icon: 'heart', tone: 'rose', title: '降压药为什么不能自己停',
      desc: '血压回正常是药物在起作用，擅自停药容易反弹',
      tags: ['慢病管理']
    }
  ];

  function buildKnowledge() {
    var el = document.createElement('div');
    el.id = KNOW_ID;
    el.innerHTML = '<div class="sa-panel-head">'
      + '<span class="sa-panel-title">用药科普</span>'
      + '<a class="sa-panel-more" href="/pages/news/index">全部资讯' + svg('chevron') + '</a>'
      + '</div>'
      + '<div class="sa-know-list">'
      + SECTIONS.map(function (s) {
        return '<a class="sa-know-item" href="/pages/news/index">'
          + '<span class="sa-know-ic is-' + s.tone + '">' + svg(s.icon) + '</span>'
          + '<span class="sa-know-tx">'
          + '<b>' + s.title + '</b>'
          + '<i>' + s.desc + '</i>'
          + '<span class="sa-know-tags">'
          + s.tags.map(function (t) { return '<em>' + t + '</em>'; }).join('')
          + '</span>'
          + '</span>'
          + '</a>';
      }).join('')
      + '</div>'
      + '<p class="sa-disclaimer">以上为通用用药常识，不构成诊疗建议；具体用药请遵医嘱或咨询执业药师。</p>';
    return el;
  }

  /* 插在商品列表模块之后（首页专用） */
  function placeKnowledge() {
    // ⚠️ 必须限定首页：个人中心也有 .page-design.ysize，不判断的话科普区会跑到「我的」页面上
    if (!isHome()) {
      var stray = document.getElementById(KNOW_ID);
      if (stray && stray.parentNode) stray.parentNode.removeChild(stray);
      return false;
    }
    var prev = document.getElementById(KNOW_ID);
    var pageDesign = document.querySelector('.page-design.ysize');
    if (!pageDesign) return false;
    // 找一个稳定的锚：商品列表模块（goodList 所在的那一层）
    var host = document.querySelector('.goodList');
    if (!host) return false;
    var top = host;
    while (top && top.parentNode && top.parentNode !== pageDesign) top = top.parentNode;
    if (!top || top.parentNode !== pageDesign) return false;
    if (prev && prev.parentNode === pageDesign && prev.previousSibling === top) return false;
    if (prev && prev.parentNode) prev.parentNode.removeChild(prev);
    if (top.nextSibling) pageDesign.insertBefore(buildKnowledge(), top.nextSibling);
    else pageDesign.appendChild(buildKnowledge());
    return true;
  }

  /* ---------- 个人中心：医保电子凭证入口 ----------
   * ⚠️ 入口本身写在源码里（pages/user/index.vue 的 .mi-entry-wrap），这里**不重复注入**。
   *    之前试过运行时再插一个，结果同一位置出现两份（源码一份 + 运行时一份）。
   *    这里只做一件事：源码那块被排在装修内容之后、页面很靠下的位置，
   *    运行时把它**挪到版权图之前**，这样它紧跟最后一屏装修内容，用户看得到。
   * 样式就在 pages/user/index.vue 的 scoped <style> 里（.mi-entry 系列）；
   * scoped 是按编译后的属性选择器实现的，元素换个父节点照样命中，不用另写一份。 */
  var ENTRY_SEL = '.mi-entry-wrap';

  function placeEntry() {
    if (!isUserPage()) return false;
    var el = document.querySelector(ENTRY_SEL);
    if (!el || !el.parentNode) return false;
    var host = el.parentNode;
    // 找版权图（img.support）当锚，把入口挪到它前面
    var anchor = null;
    Array.prototype.forEach.call(host.children, function (c) {
      if (!anchor && c !== el && c.tagName === 'UNI-IMAGE') anchor = c;
      if (!anchor && c !== el && c.tagName === 'IMG') anchor = c;
    });
    if (!anchor) return false;
    if (el.nextSibling === anchor) return false; // 已在位
    host.insertBefore(el, anchor);
    return true;
  }

  /** 当前是不是首页 */
  function isHome() {
    var p = location.pathname;
    return p === '/' || p.indexOf('/pages/index/index') >= 0;
  }

  /** 当前是不是个人中心 */
  function isUserPage() {
    return location.pathname.indexOf('/pages/user/index') >= 0;
  }

  /* 「为你推荐」右侧补一个「查看全部 >」 */
  function decorateRichTitle() {
    var rich = document.querySelector('.richText');
    if (!rich) return false;
    var host = rich.parentNode;
    if (!host || host.querySelector('.sa-panel-more')) return true;
    var more = document.createElement('a');
    more.className = 'sa-panel-more sa-panel-more--inline';
    more.href = '/pages/goods_search/index';
    more.innerHTML = '查看全部' + svg('chevron');
    // 富文本标题自带「—— 为你推荐 ——」装饰，把「查看全部」绝对定位到右侧
    if (getComputedStyle(host).position === 'static') host.style.position = 'relative';
    host.appendChild(more);
    return true;
  }

  /* ---------- 调度 ---------- */
  var busy = false;
  function boot() {
    if (busy) return;
    busy = true;
    try {
      decorateCards();
      decorateRichTitle();
      placeTrust();
      placeKnowledge();
      placeEntry();
    } catch (e) {
      /* 注入失败不能影响页面本身 */
    }
    busy = false;
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
  // 装修块和商品列表都是接口回来后才渲染的，多试几次兜底
  [300, 900, 1800, 3000, 5000, 8000].forEach(function (t) { setTimeout(boot, t); });

  // SPA 路由切换 / 节点重建时持续补：
  // 注意不能直接观测 body 的 childList 就 recalc——先看当前页需要什么
  try {
    new MutationObserver(function () {
      if (isHome() && (!document.getElementById(TRUST_ID) || !document.getElementById(KNOW_ID))) boot();
      else if (isUserPage()) placeEntry();
    }).observe(document.body, { childList: true, subtree: true });
  } catch (e) {}
})();
