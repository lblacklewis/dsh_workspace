// 轮播图重绘
//
// 为什么要重画：原来 3 张是 750x320（比例 2.34），但显示区实测是 362x189
// （比例 1.92）。按 cover 缩放后左右各裁掉一截，文案「处方药 · 凭方购买」
// 左边直接被切没了。所以 viewBox 必须按显示比例来定：750/1.9153 ≈ 392。
//
// 内容上的两处修正：
//   1. 原 banner-3 写着「满 99 减 20」，但营销模块已隐藏、这个优惠不存在。
//      demo 里放假促销是会被一眼看穿的，换成真实能力。
//   2. 补上「处方药凭方购买」——这是本项目的合规差异点（先方后药闸门 +
//      执业药师审核），比泛泛的"健康好物"更能说明产品是什么。
//
// 用法：node docs/brand/make-banners.js

const fs = require('fs');
const path = require('path');

const OUT = __dirname;
const W = 750, H = 392;
const FONT = "PingFang SC, Microsoft YaHei, Helvetica, sans-serif";

// 通用外壳：渐变底 + 柔和光晕 + 左侧文案 + 右侧图形
// 左右留白刻意放大到 64：轮播是"露出相邻卡片"的样式，文案贴边会被邻卡压住
function banner({ id, g1, g2, g3, badge, title, sub, pill, art, titleSize = 52 }) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">
  <defs>
    <linearGradient id="bg${id}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="${g1}"/>
      <stop offset="55%" stop-color="${g2}"/>
      <stop offset="100%" stop-color="${g3}"/>
    </linearGradient>
    <linearGradient id="w${id}" x1="0" y1="0" x2="0.6" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.97"/>
      <stop offset="100%" stop-color="#CCFBF1" stop-opacity="0.88"/>
    </linearGradient>
  </defs>

  <rect width="${W}" height="${H}" fill="url(#bg${id})"/>
  <circle cx="120" cy="${H - 20}" r="180" fill="#FFFFFF" opacity="0.05"/>
  <circle cx="700" cy="70" r="150" fill="#FFFFFF" opacity="0.06"/>
  <circle cx="676" cy="${H - 84}" r="112" fill="#FFFFFF" opacity="0.05"/>

  <rect x="64" y="46" width="${badge.length * 15 + 30}" height="30" rx="15" fill="#FFFFFF" opacity="0.2"/>
  <text x="79" y="66" font-family="${FONT}" font-size="14" font-weight="600"
        fill="#FFFFFF" letter-spacing="1.2">${badge}</text>

  <text x="64" y="152" font-family="${FONT}" font-size="${titleSize}" font-weight="700"
        fill="#FFFFFF" letter-spacing="1">${title}</text>
  <text x="64" y="200" font-family="${FONT}" font-size="23" font-weight="500"
        fill="#FFFFFF" opacity="0.95">${sub}</text>

  <rect x="64" y="230" width="${pill.length * 15 + 34}" height="46" rx="23" fill="#FFFFFF" opacity="0.18"/>
  <text x="85" y="260" font-family="${FONT}" font-size="18" font-weight="500"
        fill="#FFFFFF">${pill}</text>

  <g transform="translate(600,${H / 2 - 6})">${art}</g>
</svg>
`;
}

const A = {
  // 送药到家：配送箱 + 十字 + 速度线
  delivery: `
    <rect x="-92" y="-70" width="184" height="140" rx="24" fill="#FFFFFF" opacity="0.14"/>
    <rect x="-46" y="-34" width="92" height="74" rx="12" fill="url(#w1)"/>
    <rect x="-15" y="-46" width="30" height="13" rx="6.5" fill="url(#w1)"/>
    <rect x="-6" y="-16" width="12" height="36" rx="3" fill="#0D9488"/>
    <rect x="-18" y="-4" width="36" height="12" rx="3" fill="#0D9488"/>
    <rect x="-118" y="-16" width="36" height="8" rx="4" fill="#FFFFFF" opacity="0.5"/>
    <rect x="-110" y="2" width="26" height="8" rx="4" fill="#FFFFFF" opacity="0.36"/>
    <rect x="-100" y="20" width="18" height="8" rx="4" fill="#FFFFFF" opacity="0.24"/>`,
  // 处方药：处方笺 + ℞ + 审核勾
  rx: `
    <rect x="-104" y="-78" width="208" height="156" rx="26" fill="#FFFFFF" opacity="0.12"/>
    <rect x="-60" y="-56" width="112" height="112" rx="12" fill="url(#w2)"/>
    <text x="-44" y="-12" font-family="Georgia, 'Times New Roman', serif"
          font-size="40" font-weight="700" fill="#0D9488">R</text>
    <rect x="-20" y="-30" width="6" height="22" rx="3" fill="#0D9488"/>
    <rect x="-42" y="-22" width="50" height="6" rx="3" fill="#0D9488"/>
    <rect x="-46" y="12" width="86" height="7" rx="3.5" fill="#99F6E4"/>
    <rect x="-46" y="28" width="62" height="7" rx="3.5" fill="#CCFBF1"/>
    <rect x="-46" y="44" width="74" height="7" rx="3.5" fill="#CCFBF1"/>
    <circle cx="62" cy="52" r="30" fill="#10B981"/>
    <path d="M48 52 L59 63 L78 42" fill="none" stroke="#FFFFFF" stroke-width="7"
          stroke-linecap="round" stroke-linejoin="round"/>`,
  // 正品保障：盾牌 + 勾
  shield: `
    <path d="M0 -84 L70 -55 L70 6 C70 50 38 80 0 94 C-38 80 -70 50 -70 6 L-70 -55 Z"
          fill="url(#w3)"/>
    <path d="M0 -84 L70 -55 L70 6 C70 50 38 80 0 94 C-38 80 -70 50 -70 6 L-70 -55 Z"
          fill="none" stroke="#FFFFFF" stroke-width="3" stroke-opacity="0.5"/>
    <path d="M-29 2 L-9 23 L33 -22" fill="none" stroke="#0D9488" stroke-width="12"
          stroke-linecap="round" stroke-linejoin="round"/>`,
};

const list = [
  { file: 'banner-1.svg', id: 1, g1: '#14B8A6', g2: '#0D9488', g3: '#0F766E',
    badge: '同城急送', title: '送药到家', sub: '同城骑手配送 · 最快 30 分钟',
    pill: '24 小时营业 · 夜间也可下单', art: A.delivery },
  { file: 'banner-2.svg', id: 2, g1: '#0D9488', g2: '#0F766E', g3: '#134E4A',
    badge: '合规购药', title: '处方药 · 凭方购买', sub: '上传处方 · 执业药师审核',
    pill: '全程留痕 · 用药安全可追溯', art: A.rx, titleSize: 46 },
  { file: 'banner-3.svg', id: 3, g1: '#2DD4BF', g2: '#14B8A6', g3: '#0D9488',
    badge: '持证经营', title: '正品保障', sub: '药品经营许可证齐全 · 全程可追溯',
    pill: '每盒药品可查批号与效期', art: A.shield },
];

for (const b of list) {
  const p = path.join(OUT, b.file);
  fs.writeFileSync(p, banner(b), 'utf8');
  console.log('  ' + b.file + '  ' + fs.statSync(p).size + 'B  (' + W + 'x' + H + ')');
}
console.log('\n  比例 ' + (W / H).toFixed(3) + '  显示区实测 362x189 = ' + (362 / 189).toFixed(3) + '  -> 不再裁切');
