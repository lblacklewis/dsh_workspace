// 用文档给的样例反推/验证签名算法
// 目的：确认 v2.1 的拼接规则，并检查 3.5(auditResult) 是否同一套
const crypto = require('crypto');
const md5 = (s) => crypto.createHash('md5').update(s, 'utf8').digest('hex');

console.log('===== 样例1：签名Demo（3.1 创建问诊单）=====');
const sk = '6927HsL30B9r132A2ZFvEFu15k8bi9';
const bizID = 'AUTO_2659878840021047001';
const clientID = '25080709334378547181301150';
const ts = '1754556531';

// 文档明确给出的规则
const rule = sk + 'bizID' + bizID + 'clientID' + clientID + 'timestamp' + ts;
console.log('  拼接串: ' + rule);
console.log('  MD5   : ' + md5(rule));
console.log('  （文档没给这条的预期值，只给了代码；规则以文档描述为准）');

console.log('\n===== 样例2：3.3 获取跳转链接（第14页 JSON）=====');
// bizID=2025120109353858279536, clientID=23030211535395335981301233,
// timestamp=1764552982169, sign=fbcd8f37a2e0bbcd3e949c615dec1a07
{
  const b = '2025120109353858279536';
  const c = '23030211535395335981301233';
  const t = '1764552982169';
  const expect = 'fbcd8f37a2e0bbcd3e949c615dec1a07';
  const cands = {
    'secretKey+字段名+值(文档规则)': sk + 'bizID' + b + 'clientID' + c + 'timestamp' + t,
    '字段名+值 无secretKey': 'bizID' + b + 'clientID' + c + 'timestamp' + t,
    '仅值拼接': b + c + t,
    'secretKey+仅值': sk + b + c + t,
    'key=value&形式': 'bizID=' + b + '&clientID=' + c + '&timestamp=' + t,
    'secretKey&key=value': sk + 'bizID=' + b + '&clientID=' + c + '&timestamp=' + t,
  };
  for (const [name, s] of Object.entries(cands)) {
    const h = md5(s);
    console.log('  ' + (h === expect ? '✅ 命中' : '   ') + ' ' + name + ' -> ' + h);
  }
  console.log('  期望值 -> ' + expect);
}

console.log('\n===== 样例3：3.5 审核结果（第20页 JSON）=====');
// bizID=4933236000030060, rpID=25072917011961818741329150,
// clientID=23071114250980305981301019, auditStatus=2,
// outPharmacistID=Trtys001, timestamp=1750647690
// sign=094e4238204173563fff45ab976c568c
{
  const b = '4933236000030060';
  const rp = '25072917011961818741329150';
  const c = '23071114250980305981301019';
  const t = '1750647690';
  const expect = '094e4238204173563fff45ab976c568c';
  const g = (v) => JSON.stringify(v); // 字符串加引号？试试两种
  const cands = {
    '文档规则（只拼 bizID/clientID/timestamp）': sk + 'bizID' + b + 'clientID' + c + 'timestamp' + t,
    '含 rpID': sk + 'bizID' + b + 'rpID' + rp + 'clientID' + c + 'timestamp' + t,
    '含全部字段': sk + 'bizID' + b + 'rpID' + rp + 'clientID' + c + 'auditStatus' + 2 + 'outPharmacistID' + 'Trtys001' + 'timestamp' + t,
    '键值按字典序': sk + 'auditStatus' + 2 + 'bizID' + b + 'clientID' + c + 'outPharmacistID' + 'Trtys001' + 'rpID' + rp + 'timestamp' + t,
    '仅值拼接': b + rp + c + 2 + 'Trtys001' + t,
  };
  for (const [name, s] of Object.entries(cands)) {
    const h = md5(s);
    console.log('  ' + (h === expect ? '✅ 命中' : '   ') + ' ' + name + ' -> ' + h);
  }
  console.log('  期望值 -> ' + expect);
  console.log('\n  注：若全部未命中，说明 sign 里的 secretKey 不是文档示例那个，');
  console.log('      或 3.5 用了不同的拼接规则 —— 需要向对方确认。');
}
