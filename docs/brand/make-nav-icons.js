// 金刚区图标重绘
//
// 之前是 48x48 扁平线稿，10 个图标风格不统一、笔画偏细、小尺寸下辨识度低。
// 这里统一模板重画：
//   - 统一 48x48 网格与安全边距
//   - 统一 stroke-width 2.2、圆头圆角
//   - 底色圆用极浅品牌色，让图标在白色卡片上有"落点"
//   - 每个品类形状一眼可辨，而不是一堆相似的抽象线条
//
// 用 Node 而不是 PowerShell：PowerShell 的 here-string 嵌套在哈希表里
// 会被解析器搞坏（已踩过），Node 的模板字符串没这个问题。
//
// 用法：node docs/brand/make-nav-icons.js

const fs = require('fs');
const path = require('path');

const OUT = __dirname;
const BRAND = '#0D9488';

const wrap = (glyph) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <circle cx="24" cy="24" r="23" fill="#E6FFFA"/>
  <g fill="none" stroke="${BRAND}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
${glyph}
  </g>
</svg>
`;

const icons = {
  // 感冒用药：斜置胶囊 + 中线 + 飞沫
  'ic-cold.svg': `
    <rect x="13" y="17.5" width="22" height="13" rx="6.5" transform="rotate(-38 24 24)"/>
    <line x1="19.5" y1="20" x2="28.5" y2="28" transform="rotate(-38 24 24)"/>
    <path d="M33 15.5c.9 0 1.6-.7 1.6-1.6S33.9 12.3 33 12.3s-1.6.7-1.6 1.6.7 1.6 1.6 1.6z"/>`,
  // 肠胃用药：胃形
  'ic-stomach.svg': `
    <path d="M17.5 12v8.2c0 2.1 1.1 3.4 3 4 3 1 5.2 2.3 5.2 5.5 0 3.8-3.1 6.8-6.9 6.8s-6.9-3-6.9-6.8"/>
    <path d="M17.5 12h7.6"/>
    <path d="M30.8 21.6c2.1 0 3.8 1.7 3.8 3.8s-1.7 3.8-3.8 3.8"/>`,
  // 皮肤用药：药膏管 + 涂抹点
  'ic-skin.svg': `
    <rect x="16.5" y="14.5" width="13.5" height="19.5" rx="3"/>
    <path d="M19.8 14.5v-2.8h6.9v2.8"/>
    <path d="M20.5 20.5h5.5M20.5 25h5.5"/>
    <path d="M34.2 26.8c1.7 0 3.1 1.4 3.1 3.1s-1.4 3.1-3.1 3.1-3.1-1.4-3.1-3.1 1.4-3.1 3.1-3.1z"/>`,
  // 慢病用药：心形 + 脉搏
  'ic-chronic.svg': `
    <path d="M24 36.2S11.4 29.2 11.4 21.5c0-4.2 3.2-7.3 7.2-7.3 2.3 0 4.2 1 5.4 2.8 1.2-1.8 3.1-2.8 5.4-2.8 4 0 7.2 3.1 7.2 7.3 0 7.7-12.6 14.7-12.6 14.7z"/>
    <path d="M15 22.4h4.6l1.9-3.7 2.9 7.6 2.3-3.9h6.4"/>`,
  // 医疗器械：血压计 + 袖带
  'ic-device.svg': `
    <rect x="11" y="16.5" width="16.5" height="20" rx="3"/>
    <path d="M14.4 21.6h9.7"/>
    <rect x="17" y="25.6" width="5.4" height="5.4" rx="1.4"/>
    <path d="M30.6 20v11.2a4 4 0 0 0 4 4h.9"/>
    <path d="M30.6 20h3.4a2.4 2.4 0 0 0 0-4.8h-1.5"/>`,
  // 药品分类：四宫格
  'ic-cate.svg': `
    <rect x="12.5" y="12.5" width="9.6" height="9.6" rx="2.6"/>
    <rect x="25.9" y="12.5" width="9.6" height="9.6" rx="2.6"/>
    <rect x="12.5" y="25.9" width="9.6" height="9.6" rx="2.6"/>
    <rect x="25.9" y="25.9" width="9.6" height="9.6" rx="2.6"/>`,
  // 健康资讯：文稿 + 行
  'ic-news.svg': `
    <path d="M15 11.5h18a2 2 0 0 1 2 2v21a2 2 0 0 1-2 2H15a2 2 0 0 1-2-2v-21a2 2 0 0 1 2-2z"/>
    <path d="M17.6 18h12.8M17.6 23.6h12.8M17.6 29.2h7.8"/>`,
  // 健康积分：星
  'ic-points.svg': `
    <path d="M24 12.6l3.6 7.3 8 1.2-5.8 5.7 1.4 8-7.2-3.8-7.2 3.8 1.4-8-5.8-5.7 8-1.2z"/>`,
  // 我的订单：回执单
  'ic-order.svg': `
    <path d="M15 11.5h18a2 2 0 0 1 2 2v21.6l-3.6-2.4-3.5 2.4-3.5-2.4-3.5 2.4-3.5-2.4-3.4 2.4V13.5a2 2 0 0 1 2-2z"/>
    <path d="M18.4 19h11.2M18.4 24.8h11.2"/>`,
  // 我的处方：处方笺 ℞
  'ic-rx.svg': `
    <path d="M15 11.5h18a2 2 0 0 1 2 2v21a2 2 0 0 1-2 2H15a2 2 0 0 1-2-2v-21a2 2 0 0 1 2-2z"/>
    <path d="M18.4 19.6h4.7a2.5 2.5 0 0 1 0 5h-4.7"/>
    <path d="M20.8 19.6v10.6M24 24.4l4.2 5.6"/>`,
};

let n = 0;
for (const name of Object.keys(icons)) {
  const p = path.join(OUT, name);
  fs.writeFileSync(p, wrap(icons[name]), 'utf8');
  console.log('  ' + name + '  ' + fs.statSync(p).size + 'B');
  n++;
}
console.log('\n  共生成 ' + n + ' 个图标');
console.log('  上传： scp docs/brand/ic-*.svg root@<host>:/opt/storapp/crmeb/crmebimage/brand/');
