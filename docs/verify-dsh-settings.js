// 验证同步过来的 settings.yaml 是否能被 YAML 解析器正确解析
// 顺带确认中文注释没有变成乱码（编码是否正确）
const fs = require('fs');
const path = 'D:/project/StorApp/crmeb_java/.dsh/settings.yaml';
const yaml = require('D:/project/StorApp/crmeb_java/admin/node_modules/js-yaml');

const buf = fs.readFileSync(path);
console.log('文件大小       : ' + buf.length + ' 字节');
console.log('前3字节(BOM?)  : ' + [...buf.slice(0, 3)].map(b => b.toString(16).padStart(2, '0')).join(' '));
console.log('按 UTF-8 解码  : ' + (buf.toString('utf8').includes('\uFFFD') ? '❌ 有替换字符(不是合法UTF-8)' : '✓ 合法 UTF-8'));
console.log('');

const text = buf.toString('utf8');
let doc;
try {
  doc = yaml.load(text);
  console.log('YAML 解析      : ✓ 成功');
} catch (e) {
  console.log('YAML 解析      : ❌ 失败 -> ' + e.message.split('\n')[0]);
  process.exit(1);
}

console.log('');
console.log('顶层配置项（共 ' + Object.keys(doc).length + ' 个）:');
for (const k of Object.keys(doc)) console.log('  - ' + k);

console.log('');
console.log('关键项核对:');
const checks = [
  ['agent-default-model', () => doc['agent-default-model']?.model],
  ['llm-deepseek.baseURL', () => doc['llm-deepseek']?.baseURL],
  ['llm-deepseek.streamIdleTimeoutMs', () => doc['llm-deepseek']?.streamIdleTimeoutMs],
  ['deepseek-v4.1-flash contextWindow', () => doc['llm-deepseek']?.models?.find(m => m.id === 'deepseek-v4.1-flash')?.contextWindow],
  ['llm-pi-ai.providers.local.baseURL', () => doc['llm-pi-ai']?.providers?.local?.baseURL],
  ['agent-presets.default', () => doc['agent-presets']?.default],
  ['remote-web-ui.enabled', () => doc['remote-web-ui']?.enabled],
];
let bad = 0;
for (const [name, fn] of checks) {
  let v;
  try { v = fn(); } catch (e) { v = undefined; }
  const ok = v !== undefined && v !== null;
  if (!ok) bad++;
  console.log('  ' + (ok ? '✓' : '❌') + ' ' + name.padEnd(38) + ' = ' + v);
}

console.log('');
console.log('中文注释编码检查:');
const m = text.match(/^#\s*(\S*(?:编码|备忘|坑|限制)\S*)/m);
console.log('  注释样例: ' + (m ? m[1] : '(未匹配到)'));
console.log('  含乱码字符(常见的 鈥/锛/閰): ' + /鈥|锛|閰|鍜|鏂/.test(text));
console.log('');
console.log(bad === 0 ? '✅ 全部关键项齐全' : '⚠️ 有 ' + bad + ' 项缺失');
