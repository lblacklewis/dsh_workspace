/* ------------------------------------------------------------------
 * mockInsurance.js — 医保电子凭证的 mock 数据层
 *
 * ⚠️⚠️ 这是一个**演示用的假数据层**，不接任何真实医保接口 ⚠️⚠️
 *
 * 真实的医保电子凭证（医保码）是这样工作的：
 *   - 由「国家医保信息平台」统一签发，一人一码、全国通用、跨渠道通用
 *   - 采用实名 + 实人认证，国产加密算法（SM2/SM3/SM4），数据加密传输
 *   - 展码是「动态二维码」：**有效时间仅 1 分钟**，每次刷新都不同
 *   - **截图即失效** —— 动态码不能截图转发，静态图无法用于结算
 *   - 客户端（微信/支付宝小程序、国家医保服务平台 APP）只负责**展码**，
 *     二维码内容由平台签发，客户端不生成
 *
 * 所以本文件的定位是「把界面的数据形状先跑通」，用于客户演示：
 *   - 参保信息、账户余额、缴费基数、就医/购药记录 → 全部是编造的固定值
 *   - 动态二维码 → 用本项目的 saqr.js 把一段假 token 画成真二维码
 *     （形状是真的，能扫出字符串，但扫出来不通任何医保系统）
 *
 * 上线前必须做的事：
 *   1. 接入国家医保信息平台 / 省级医保信息平台的正式对接流程（需要资质与联调）
 *   2. 删除本文件，或把每个函数改为调用真实接口
 *   3. 参保人实名信息要走真实认证，不能用昵称兜底
 * ------------------------------------------------------------------ */

/* 医保码的动态刷新周期。官方口径：动态二维码有效时间 **1 分钟**。 */
export const CODE_TTL_SECONDS = 60;

/* 演示用的固定参保信息。
   真实场景这些字段全部来自医保平台，且需要用户完成实人认证。 */
const DEMO_PROFILE = {
  insuranceRegion: '北京市 · 市本级',
  insuranceType: '城镇职工基本医疗保险',
  insuranceStatus: '正常参保',
  insuranceStatusCode: 'normal',
  employer: '北京星云科技有限公司',
  employerShort: '星云科技',
  insuredMonths: 74,
  firstInsuredMonth: '2020-09',
  socialSecurityNo: '1101**********3721',
  employeeNo: 'BXY2020001743',
  // 医保个人账户
  accountBalance: 3862.47,
  accountCurrency: 'CNY',
  // 当年个人账户收支
  yearIncome: 6120.0,
  yearExpense: 2257.53,
  yearStart: '2026-01-01',
  // 缴费
  payBase: 12800.0,
  payBaseMonth: '2026-10',
  personalPay: 256.0,
  companyPay: 1152.0,
  lastPayMonth: '2026-10',
  // 就医统计
  visitCountYear: 7,
  visitTotalYear: 1834.6,
  fundPayYear: 1187.42,
  selfPayYear: 647.18,
};

/* 就诊 / 购药记录（mock）。type: outpatient 门诊 / pharmacy 购药 / inpatient 住院 */
const DEMO_VISITS = [
  {
    id: 'V202610180001',
    type: 'outpatient',
    typeDesc: '门诊',
    date: '2026-10-18',
    org: '北京协和医院',
    dept: '内分泌科',
    amount: 386.5,
    fundPay: 270.55,
    selfPay: 115.95,
    status: '已结算',
  },
  {
    id: 'V202610120007',
    type: 'pharmacy',
    typeDesc: '购药',
    date: '2026-10-12',
    org: 'StorApp 健康药房（朝阳门店）',
    dept: '医保定点药房',
    amount: 128.0,
    fundPay: 89.6,
    selfPay: 38.4,
    status: '已结算',
  },
  {
    id: 'V202609280013',
    type: 'outpatient',
    typeDesc: '门诊',
    date: '2026-09-28',
    org: '北京协和医院',
    dept: '心血管内科',
    amount: 542.3,
    fundPay: 379.61,
    selfPay: 162.69,
    status: '已结算',
  },
  {
    id: 'V202609150022',
    type: 'pharmacy',
    typeDesc: '购药',
    date: '2026-09-15',
    org: '北京同仁堂药店',
    dept: '医保定点药房',
    amount: 96.5,
    fundPay: 67.55,
    selfPay: 28.95,
    status: '已结算',
  },
  {
    id: 'V202608300005',
    type: 'outpatient',
    typeDesc: '门诊',
    date: '2026-08-30',
    org: '北京朝阳医院',
    dept: '呼吸内科',
    amount: 268.4,
    fundPay: 187.88,
    selfPay: 80.52,
    status: '已结算',
  },
  {
    id: 'V202608060019',
    type: 'inpatient',
    typeDesc: '住院',
    date: '2026-08-06',
    org: '北京友谊医院',
    dept: '普外科',
    amount: 1286.0,
    fundPay: 900.2,
    selfPay: 385.8,
    status: '已结算',
  },
  {
    id: 'V202607200031',
    type: 'pharmacy',
    typeDesc: '购药',
    date: '2026-07-20',
    org: 'StorApp 健康药房（海淀店）',
    dept: '医保定点药房',
    amount: 76.8,
    fundPay: 53.76,
    selfPay: 23.04,
    status: '已结算',
  },
];

/* 个人账户消费明细（mock）。direction: out 支出 / in 划入 */
const DEMO_ACCOUNT_LOG = [
  { id: 'A202610180001', date: '2026-10-18', title: '协和医院 门诊结算',     direction: 'out', amount: 115.95 },
  { id: 'A202610150002', date: '2026-10-15', title: '单位缴费个人账户划入',   direction: 'in',  amount: 256.0 },
  { id: 'A202610120007', date: '2026-10-12', title: 'StorApp 健康药房 购药', direction: 'out', amount: 38.4 },
  { id: 'A202609280013', date: '2026-09-28', title: '协和医院 门诊结算',     direction: 'out', amount: 162.69 },
  { id: 'A202609150022', date: '2026-09-15', title: '同仁堂药店 购药',       direction: 'out', amount: 28.95 },
  { id: 'A202609150003', date: '2026-09-15', title: '单位缴费个人账户划入',   direction: 'in',  amount: 256.0 },
  { id: 'A202608300005', date: '2026-08-30', title: '朝阳医院 门诊结算',     direction: 'out', amount: 80.52 },
  { id: 'A202608060019', date: '2026-08-06', title: '友谊医院 住院结算',     direction: 'out', amount: 385.8 },
  { id: 'A202608150004', date: '2026-08-15', title: '单位缴费个人账户划入',   direction: 'in',  amount: 256.0 },
  { id: 'A202607200031', date: '2026-07-20', title: 'StorApp 健康药房 购药', direction: 'out', amount: 23.04 },
];

/* ---------- 实名信息脱敏 ---------- */

/** 姓名脱敏：张三 → 张*；欧阳修 → 欧**；只有姓时原样返回 */
export function maskName(name) {
  const s = String(name || '').trim();
  if (!s) return '';
  if (s.length === 1) return s;
  return s[0] + '*'.repeat(s.length - 1);
}

/**
 * 身份证号脱敏：保留前 6 位（地区码）和后 4 位，中间全星号。
 * 真实医保码页面一般只显示后 4 位，这里保留地区码是为了让演示看起来有信息量。
 */
export function maskCardId(cardId) {
  const s = String(cardId || '').replace(/\s/g, '');
  if (s.length < 8) return s ? s[0] + '*'.repeat(Math.max(0, s.length - 1)) : '';
  return s.slice(0, 6) + '*'.repeat(s.length - 10) + s.slice(-4);
}

/** 手机号脱敏：138****8000 */
export function maskPhone(phone) {
  const s = String(phone || '').replace(/\s/g, '');
  if (s.length !== 11) return s;
  return s.slice(0, 3) + '****' + s.slice(-4);
}

/* ---------- 参保信息 ---------- */

/**
 * 取参保信息。
 * @param {object} user 会员信息（来自 store.state.app.userInfo，可能为空）
 * @returns {object} 已脱敏、可安全渲染的对象（不含原始身份证号）
 */
export function getInsuranceProfile(user) {
  const u = user || {};
  const rawName = u.realName || u.nickname || '';
  const rawCard = u.cardId || '';
  // 演示会员没填实名时的兜底，保证页面不空
  const name = rawName || '张*';
  const cardId = rawCard || '1101**********3721';

  return {
    // 实名（脱敏后）
    maskedName: maskName(name),
    maskedCardId: maskCardId(cardId),
    maskedPhone: maskPhone(u.phone || '13800138000'),
    hasRealName: !!u.realName,
    // 参保
    insuranceRegion: DEMO_PROFILE.insuranceRegion,
    insuranceType: DEMO_PROFILE.insuranceType,
    insuranceStatus: DEMO_PROFILE.insuranceStatus,
    insuranceStatusCode: DEMO_PROFILE.insuranceStatusCode,
    employer: DEMO_PROFILE.employer,
    employerShort: DEMO_PROFILE.employerShort,
    insuredMonths: DEMO_PROFILE.insuredMonths,
    firstInsuredMonth: DEMO_PROFILE.firstInsuredMonth,
    // 凭证号（演示）
    socialSecurityNo: DEMO_PROFILE.socialSecurityNo,
    employeeNo: DEMO_PROFILE.employeeNo,
  };
}

/* ---------- 个人账户 ---------- */

export function getInsuranceAccount() {
  const p = DEMO_PROFILE;
  return {
    balance: p.accountBalance,
    currency: p.accountCurrency,
    yearIncome: p.yearIncome,
    yearExpense: p.yearExpense,
    yearStart: p.yearStart,
    yearEnd: '2026-12-31',
    payBase: p.payBase,
    payBaseMonth: p.payBaseMonth,
    personalPay: p.personalPay,
    companyPay: p.companyPay,
    lastPayMonth: p.lastPayMonth,
    visitCountYear: p.visitCountYear,
    visitTotalYear: p.visitTotalYear,
    fundPayYear: p.fundPayYear,
    selfPayYear: p.selfPayYear,
  };
}

/* ---------- 就医 / 购药记录 ---------- */

/**
 * @param {string} [filter] '' | 'outpatient' | 'pharmacy' | 'inpatient'
 */
export function getVisitRecords(filter) {
  const f = filter || '';
  const list = f ? DEMO_VISITS.filter((v) => v.type === f) : DEMO_VISITS;
  return list.map((v) => Object.assign({}, v));
}

/** 记录页顶部的分类与计数 */
export function getVisitFilters() {
  return [
    { label: '全部', value: '', count: DEMO_VISITS.length },
    { label: '门诊', value: 'outpatient', count: DEMO_VISITS.filter((v) => v.type === 'outpatient').length },
    { label: '购药', value: 'pharmacy', count: DEMO_VISITS.filter((v) => v.type === 'pharmacy').length },
    { label: '住院', value: 'inpatient', count: DEMO_VISITS.filter((v) => v.type === 'inpatient').length },
  ];
}

/* ---------- 个人账户消费明细 ---------- */

export function getAccountLog() {
  return DEMO_ACCOUNT_LOG.map((v) => Object.assign({}, v));
}

/** 汇总：明细页顶部的收入/支出合计 */
export function getAccountLogSummary() {
  let income = 0;
  let expense = 0;
  DEMO_ACCOUNT_LOG.forEach((v) => {
    if (v.direction === 'in') income += v.amount;
    else expense += v.amount;
  });
  return {
    income: Math.round(income * 100) / 100,
    expense: Math.round(expense * 100) / 100,
  };
}

/* ---------- 动态二维码 ---------- */

/** 稳定哈希：让同一个用户在同一个 60 秒窗口里的码是确定的（方便演示时复现） */
function hashCode(str) {
  let h = 0;
  const s = String(str);
  for (let i = 0; i < s.length; i++) {
    h = (h << 5) - h + s.charCodeAt(i);
    h |= 0;
  }
  return Math.abs(h);
}

/** 32 位十六进制随机串（不用 Math.random 之外的依赖） */
function hex32(seed) {
  let out = '';
  let x = seed >>> 0;
  for (let i = 0; i < 8; i++) {
    // xorshift32
    x ^= x << 13;
    x >>>= 0;
    x ^= x >> 17;
    x ^= x << 5;
    x >>>= 0;
    out += ('00000000' + x.toString(16)).slice(-8);
  }
  return out.slice(0, 32);
}

/**
 * 生成一段**假的**医保码 token —— 形状模仿真实动态码，但不通任何系统。
 *
 * 真实码的结构属于平台内部规范，客户端不解析；这里只是为了让二维码看起来合理：
 *   YBBH + 地区码 + 窗口序号 + 校验片段
 *
 * @param {string} uid  会员 id（决定这个人的码是稳定的）
 * @param {number} [nowMs] 当前时间戳（测试用）
 * @returns {{token:string, expiresAt:number, secondsLeft:number, seq:number}}
 */
export function getDynamicCode(uid, nowMs) {
  const now = nowMs || Date.now();
  const seq = Math.floor(now / (CODE_TTL_SECONDS * 1000));
  const expiresAt = (seq + 1) * CODE_TTL_SECONDS * 1000;
  const secondsLeft = Math.max(0, Math.ceil((expiresAt - now) / 1000));
  const base = hashCode('sa-ybj-' + (uid || 'guest') + '-' + seq);
  const token = 'YBBH' + '1101' + String(seq % 100000000).padStart(8, '0') + hex32(base).slice(0, 12);
  return { token, expiresAt, secondsLeft, seq };
}

export default {
  CODE_TTL_SECONDS,
  maskName,
  maskCardId,
  maskPhone,
  getInsuranceProfile,
  getInsuranceAccount,
  getVisitRecords,
  getVisitFilters,
  getAccountLog,
  getAccountLogSummary,
  getDynamicCode,
};
