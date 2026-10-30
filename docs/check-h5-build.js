// 校验 H5 构建产物：入口哈希名、页面路由、chunk 引用完整性
const fs = require('fs');
const path = require('path');
const dist = process.argv[2] || 'D:\\project\\StorApp\\crmeb_java\\app\\dist\\build\\h5';
const jsDir = path.join(dist, 'static', 'js');

const files = fs.readdirSync(jsDir);
const entry = files.find((f) => /^index\.[0-9a-f]+\.js$/.test(f)) || files.find((f) => f === 'index.js');
if (!entry) {
  console.log('  ❌ 找不到入口 js');
  process.exit(1);
}
const s = fs.readFileSync(path.join(jsDir, entry), 'utf8');
console.log('  入口: ' + entry + '  (' + s.length + ' 字符)');

const probes = ['/pages/medical/insurance', 'pages-medical-insurance', '/pages/prescription/index'];
probes.forEach((p) => console.log('  ' + p + ' -> ' + (s.split(p).length - 1) + ' 次'));

// 入口引用的所有 js 是否都存在
const refs = [...s.matchAll(/static\/js\/([A-Za-z0-9._-]+\.js)/g)].map((m) => m[1]);
const uniq = [...new Set(refs)];
const missing = uniq.filter((f) => !fs.existsSync(path.join(jsDir, f)));
console.log('  入口引用的 js: ' + uniq.length + ' 个，缺失: ' + (missing.length ? missing.join(', ') : '无'));

// html 引用的入口是否都存在
const html = fs.readFileSync(path.join(dist, 'index.html'), 'utf8');
const htmlRefs = [...html.matchAll(/\/static\/js\/([A-Za-z0-9._-]+\.js)/g)].map((m) => m[1]);
const htmlMissing = htmlRefs.filter((f) => !fs.existsSync(path.join(jsDir, f)));
console.log('  index.html 引用: ' + htmlRefs.join(', ') + '  缺失: ' + (htmlMissing.length ? htmlMissing.join(', ') : '无'));

// 所有页面 chunk 是否都被引用了（即入口知道它们）
const pageChunks = files.filter((f) => /^pages-/.test(f));
const unreferenced = pageChunks.filter((f) => s.indexOf(f) < 0);
console.log('  页面 chunk: ' + pageChunks.length + ' 个，入口未引用: ' + (unreferenced.length ? unreferenced.join(', ') : '无'));
console.log('  medical chunk 存在: ' + pageChunks.some((f) => f.includes('medical')));
