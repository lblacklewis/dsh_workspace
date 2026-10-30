/* ------------------------------------------------------------------
 * saqr.js — 自包含 QR 码生成器（零依赖）
 *
 * 为什么自己写：
 *   项目里没有任何 qrcode 库（package.json 只有 mp-html 一个 dependencies），
 *   本地也没有安装权限，而医保电子凭证的核心就是「动态二维码」。
 *   所以这里实现一个够用的最小 QR 编码器：字节模式，版本 1..10，纠错等级 L/M/Q/H。
 *   生成结果是 canvas 用的 data URL 字符串，可直接喂给 <image :src>。
 *
 * 支持范围（够 cleartext 的医保码 token 用了）：
 *   版本 1..10  →  字节模式容量约 17 ~ 271 字节（L 级）
 *
 * ⚠️ 这是给演示环境用的编码器，**不是**给生产用的：
 *   真实医保电子凭证的二维码由「国家医保信息平台」签发（国产加密算法 SM2/SM4），
 *   客户端只负责展码，不负责生成。这里只是把一段 mock token 画成二维码。
 *
 * 算法依据：ISO/IEC 18004。关键表（纠错块结构、对齐图形位置、格式信息）
 * 是硬编码的常量表，改版本范围时要连表一起改。
 * ------------------------------------------------------------------ */

/* ---------- GF(256) 有限域 ---------- */
const EXP = new Array(512);
const LOG = new Array(256);
(function initGF() {
  let x = 1;
  for (let i = 0; i < 255; i++) {
    EXP[i] = x;
    LOG[x] = i;
    x <<= 1;
    if (x & 0x100) x ^= 0x11d; // 本原多项式 x^8+x^4+x^3+x^2+1
  }
  for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];
})();

function gfMul(a, b) {
  if (a === 0 || b === 0) return 0;
  return EXP[LOG[a] + LOG[b]];
}

/* 生成多项式 g(x) = (x-a^0)(x-a^1)...(x-a^(ecCount-1)) */
function rsGeneratorPoly(ecCount) {
  let poly = [1];
  for (let i = 0; i < ecCount; i++) {
    const next = new Array(poly.length + 1).fill(0);
    for (let j = 0; j < poly.length; j++) {
      next[j] ^= poly[j];
      next[j + 1] ^= gfMul(poly[j], EXP[i]);
    }
    poly = next;
  }
  return poly;
}

/* 对 data 求 ecCount 个纠错码字 */
function rsEncode(data, ecCount) {
  const gen = rsGeneratorPoly(ecCount);
  const res = new Array(ecCount).fill(0);
  for (let i = 0; i < data.length; i++) {
    const factor = data[i] ^ res[0];
    res.shift();
    res.push(0);
    if (factor !== 0) {
      for (let j = 0; j < ecCount; j++) {
        res[j] ^= gfMul(gen[j + 1], factor);
      }
    }
  }
  return res;
}

/* ---------- 纠错等级 ---------- */
const EC_LEVEL = { L: 0, M: 1, Q: 2, H: 3 };

/* 每个版本每个等级的：每块纠错码字数、块分组 [块数, 每块数据码字数] */
const EC_TABLE = {
  1: { L: [7, [[1, 19]]], M: [10, [[1, 16]]], Q: [13, [[1, 13]]], H: [17, [[1, 9]]] },
  2: { L: [10, [[1, 34]]], M: [16, [[1, 28]]], Q: [22, [[1, 22]]], H: [28, [[1, 16]]] },
  3: { L: [15, [[1, 55]]], M: [26, [[1, 44]]], Q: [18, [[2, 17]]], H: [22, [[2, 13]]] },
  4: { L: [20, [[1, 80]]], M: [18, [[2, 32]]], Q: [26, [[2, 24]]], H: [16, [[4, 9]]] },
  5: { L: [26, [[1, 108]]], M: [24, [[2, 43]]], Q: [18, [[2, 15], [2, 16]]], H: [22, [[2, 11], [2, 12]]] },
  6: { L: [18, [[2, 68]]], M: [16, [[4, 27]]], Q: [24, [[4, 19]]], H: [28, [[4, 15]]] },
  7: { L: [20, [[2, 78]]], M: [18, [[4, 31]]], Q: [18, [[2, 14], [4, 15]]], H: [26, [[4, 13], [1, 14]]] },
  8: { L: [24, [[2, 97]]], M: [22, [[2, 38], [2, 39]]], Q: [22, [[4, 18], [2, 19]]], H: [26, [[4, 14], [2, 15]]] },
  9: { L: [30, [[2, 116]]], M: [22, [[3, 36], [2, 37]]], Q: [20, [[4, 16], [4, 17]]], H: [24, [[4, 12], [4, 13]]] },
  10: { L: [18, [[2, 68], [2, 69]]], M: [26, [[4, 43], [1, 44]]], Q: [24, [[6, 19], [2, 20]]], H: [28, [[6, 15], [2, 16]]] },
};

/* 对齐图形中心坐标（版本 n 取 EC_TABLE 里的版本号） */
const ALIGN_POS = {
  1: [],
  2: [6, 18],
  3: [6, 22],
  4: [6, 26],
  5: [6, 30],
  6: [6, 34],
  7: [6, 22, 38],
  8: [6, 24, 42],
  9: [6, 26, 46],
  10: [6, 28, 50],
};

/* 格式信息（15 bit）：BCH(15,5)，再与 0x5412 异或 */
function formatBits(level, mask) {
  const data = (EC_LEVEL[level] << 3) | mask;
  let rem = data;
  for (let i = 0; i < 10; i++) {
    rem = (rem << 1) ^ ((rem >> 9) * 0x537);
  }
  return (((data << 10) | rem) ^ 0x5412) & 0x7fff;
}

/* 版本信息（18 bit，版本 >= 7 才需要）*/
function versionBits(version) {
  let rem = version;
  for (let i = 0; i < 12; i++) {
    rem = (rem << 1) ^ ((rem >> 11) * 0x1f25);
  }
  return (version << 12) | rem;
}

const MASKS = [
  (r, c) => (r + c) % 2 === 0,
  (r) => r % 2 === 0,
  (r, c) => c % 3 === 0,
  (r, c) => (r + c) % 3 === 0,
  (r, c) => (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0,
  (r, c) => ((r * c) % 2) + ((r * c) % 3) === 0,
  (r, c) => (((r * c) % 2) + ((r * c) % 3)) % 2 === 0,
  (r, c) => (((r + c) % 2) + ((r * c) % 3)) % 2 === 0,
];

/* ---------- 主流程 ---------- */

/** UTF-8 编码成字节数组 */
function toUtf8Bytes(str) {
  const out = [];
  for (let i = 0; i < str.length; i++) {
    let c = str.charCodeAt(i);
    if (c < 0x80) out.push(c);
    else if (c < 0x800) {
      out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
    } else if (c >= 0xd800 && c <= 0xdbff && i + 1 < str.length) {
      // 代理对
      const c2 = str.charCodeAt(++i);
      c = 0x10000 + ((c - 0xd800) << 10) + (c2 - 0xdc00);
      out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 0x3f), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
    } else {
      out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
    }
  }
  return out;
}

/** 选一个能装下的最小版本 */
function pickVersion(byteLen, level) {
  for (let v = 1; v <= 10; v++) {
    const [ecCount, groups] = EC_TABLE[v][level];
    const totalData = groups.reduce((s, [n, k]) => s + n * k, 0);
    // 模式(4bit) + 字符计数 + 数据 + 终止符，都要塞进 totalData 个码字
    const capacityBits = totalData * 8;
    const needBits = 4 + 8 + byteLen * 8; // 版本 1..9 的字节模式计数是 8 bit
    if (needBits + 4 <= capacityBits) return { version: v, ecCount, groups, totalData };
  }
  throw new Error('saqr: 内容过长，超出支持的版本范围(1..10)');
}

/** 编码成最终交错的码字序列 */
function encodeCodewords(bytes, level) {
  const { version, ecCount, groups, totalData } = pickVersion(bytes.length, level);

  const bits = [];
  // ⚠️ 只往 bits 里推位；长度在调用处单独算，别在这里混用（早期写错过一次）
  const push = (val, len) => {
    for (let i = len - 1; i >= 0; i--) bits.push((val >> i) & 1);
  };

  push(0b0100, 4); // 字节模式
  push(bytes.length, 8); // 版本 1..9
  bytes.forEach((b) => push(b, 8));

  // 终止符最多 4 个 0
  const capacityBits = totalData * 8;
  const remain = capacityBits - bits.length;
  push(0, Math.min(4, remain));
  // 补零到字节边界
  while (bits.length % 8 !== 0) bits.push(0);

  const dataCw = [];
  for (let i = 0; i < bits.length; i += 8) {
    let b = 0;
    for (let j = 0; j < 8; j++) b = (b << 1) | bits[i + j];
    dataCw.push(b);
  }
  // 交替填充 0xEC / 0x11
  const pads = [0xec, 0x11];
  let pi = 0;
  while (dataCw.length < totalData) dataCw.push(pads[pi++ % 2]);

  // 分块 + 各自算纠错
  const dataBlocks = [];
  const ecBlocks = [];
  let off = 0;
  groups.forEach(([count, k]) => {
    for (let i = 0; i < count; i++) {
      const blk = dataCw.slice(off, off + k);
      off += k;
      dataBlocks.push(blk);
      ecBlocks.push(rsEncode(blk, ecCount));
    }
  });

  // 交错：先按列取数据码字，再按列取纠错码字
  const out = [];
  const maxDataLen = Math.max(...dataBlocks.map((b) => b.length));
  for (let i = 0; i < maxDataLen; i++) {
    dataBlocks.forEach((b) => {
      if (i < b.length) out.push(b[i]);
    });
  }
  for (let i = 0; i < ecCount; i++) {
    ecBlocks.forEach((b) => out.push(b[i]));
  }
  return { version, codewords: out };
}

/** 建矩阵：功能图形 + 数据 + 选掩码 */
function buildMatrix(version, codewords, level) {
  const size = version * 4 + 17;
  const m = Array.from({ length: size }, () => new Array(size).fill(null));
  const reserved = Array.from({ length: size }, () => new Array(size).fill(false));

  const setF = (r, c, v) => {
    if (r < 0 || c < 0 || r >= size || c >= size) return;
    m[r][c] = v;
    reserved[r][c] = true;
  };

  // 定位图形 + 分隔符
  const finder = (r0, c0) => {
    for (let r = -1; r <= 7; r++) {
      for (let c = -1; c <= 7; c++) {
        const rr = r0 + r;
        const cc = c0 + c;
        if (rr < 0 || cc < 0 || rr >= size || cc >= size) continue;
        const inRing = (r >= 0 && r <= 6 && (c === 0 || c === 6)) || (c >= 0 && c <= 6 && (r === 0 || r === 6));
        const inCore = r >= 2 && r <= 4 && c >= 2 && c <= 4;
        setF(rr, cc, inRing || inCore ? 1 : 0);
      }
    }
  };
  finder(0, 0);
  finder(0, size - 7);
  finder(size - 7, 0);

  // 定位辅助（timing）
  for (let i = 8; i < size - 8; i++) {
    const v = i % 2 === 0 ? 1 : 0;
    setF(6, i, v);
    setF(i, 6, v);
  }

  // 对齐图形
  const pos = ALIGN_POS[version] || [];
  pos.forEach((r) => {
    pos.forEach((c) => {
      // 跳过与定位图形重叠的三个角
      if ((r <= 8 && c <= 8) || (r <= 8 && c >= size - 9) || (r >= size - 9 && c <= 8)) return;
      for (let dr = -2; dr <= 2; dr++) {
        for (let dc = -2; dc <= 2; dc++) {
          const isEdge = Math.max(Math.abs(dr), Math.abs(dc)) === 2;
          const isCenter = dr === 0 && dc === 0;
          setF(r + dr, c + dc, isEdge || isCenter ? 1 : 0);
        }
      }
    });
  });

  // 固定黑点
  setF(size - 8, 8, 1);

  // 预留格式信息区
  for (let i = 0; i <= 8; i++) {
    if (!reserved[8][i]) setF(8, i, 0);
    if (!reserved[i][8]) setF(i, 8, 0);
  }
  for (let i = 0; i < 8; i++) {
    if (!reserved[8][size - 1 - i]) setF(8, size - 1 - i, 0);
    if (!reserved[size - 1 - i][8]) setF(size - 1 - i, 8, 0);
  }
  // 版本信息区（>= 7）
  if (version >= 7) {
    for (let i = 0; i < 18; i++) {
      const r = Math.floor(i / 3);
      const c = i % 3;
      if (!reserved[r][size - 11 + c]) setF(r, size - 11 + c, 0);
      if (!reserved[size - 11 + c][r]) setF(size - 11 + c, r, 0);
    }
  }

  // 数据位填充：从右下角开始，两列一组成 Z 字形向上/向下交替
  const dataBits = [];
  codewords.forEach((cw) => {
    for (let i = 7; i >= 0; i--) dataBits.push((cw >> i) & 1);
  });

  let bitIdx = 0;
  let upward = true;
  for (let col = size - 1; col > 0; col -= 2) {
    if (col === 6) col--; // 跳过 timing 列
    for (let i = 0; i < size; i++) {
      const row = upward ? size - 1 - i : i;
      for (let k = 0; k < 2; k++) {
        const c = col - k;
        if (reserved[row][c]) continue;
        const bit = bitIdx < dataBits.length ? dataBits[bitIdx++] : 0;
        m[row][c] = bit;
      }
    }
    upward = !upward;
  }

  // 选最优掩码（按 ISO 的罚分规则）
  let best = null;
  for (let mask = 0; mask < 8; mask++) {
    const test = m.map((row) => row.slice());
    applyMask(test, reserved, mask);
    writeFormat(test, level, mask, size);
    if (version >= 7) writeVersion(test, version, size);
    const score = penalty(test, size);
    if (!best || score < best.score) best = { score, mask, matrix: test };
  }
  return best.matrix;
}

function applyMask(m, reserved, mask) {
  const size = m.length;
  const fn = MASKS[mask];
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      if (reserved[r][c]) continue;
      if (fn(r, c)) m[r][c] ^= 1;
    }
  }
}

function writeFormat(m, level, mask, size) {
  const bits = formatBits(level, mask);
  for (let i = 0; i < 15; i++) {
    const bit = (bits >> i) & 1;
    // 左上
    if (i < 6) m[8][i] = bit;
    else if (i < 8) m[8][i + 1] = bit;
    else if (i === 8) m[7][8] = bit;
    else m[14 - i][8] = bit;
    // 右上 / 左下
    if (i < 8) m[size - 1 - i][8] = bit;
    else m[8][size - 15 + i] = bit;
  }
  m[size - 8][8] = 1; // 固定黑点
}

function writeVersion(m, version, size) {
  const bits = versionBits(version);
  for (let i = 0; i < 18; i++) {
    const bit = (bits >> i) & 1;
    const r = Math.floor(i / 3);
    const c = i % 3;
    m[r][size - 11 + c] = bit;
    m[size - 11 + c][r] = bit;
  }
}

/* 掩码罚分：ISO/IEC 18004 §8.8.2 的四条规则 */
function penalty(m, size) {
  let score = 0;
  // 规则1：同色连续 >= 5
  const runScore = (line) => {
    let s = 0;
    let run = 1;
    for (let i = 1; i < line.length; i++) {
      if (line[i] === line[i - 1]) run++;
      else {
        if (run >= 5) s += 3 + (run - 5);
        run = 1;
      }
    }
    if (run >= 5) s += 3 + (run - 5);
    return s;
  };
  for (let i = 0; i < size; i++) {
    score += runScore(m[i]);
    score += runScore(m.map((row) => row[i]));
  }
  // 规则2：2x2 同色块
  for (let r = 0; r < size - 1; r++) {
    for (let c = 0; c < size - 1; c++) {
      const v = m[r][c];
      if (v === m[r][c + 1] && v === m[r + 1][c] && v === m[r + 1][c + 1]) score += 3;
    }
  }
  // 规则3：出现 1011101 0000 之类的模式
  const pat1 = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0];
  const pat2 = [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1];
  const matches = (line, pat, at) => pat.every((p, i) => line[at + i] === p);
  for (let i = 0; i < size; i++) {
    const row = m[i];
    const col = m.map((r) => r[i]);
    for (let j = 0; j <= size - 11; j++) {
      if (matches(row, pat1, j) || matches(row, pat2, j)) score += 40;
      if (matches(col, pat1, j) || matches(col, pat2, j)) score += 40;
    }
  }
  // 规则4：黑白比例偏离 50%
  let dark = 0;
  for (let r = 0; r < size; r++) for (let c = 0; c < size; c++) if (m[r][c]) dark++;
  const total = size * size;
  const ratio = (dark * 100) / total;
  score += Math.floor(Math.abs(ratio - 50) / 5) * 10;
  return score;
}

/* ---------- 对外接口 ---------- */

/**
 * 生成二维码
 * @param {string} text  要编码的内容
 * @param {object} [opt] { level: 'L'|'M'|'Q'|'H'（默认 M）, size: 导出像素尺寸（默认 480）, margin: 静区模块数（默认 4） }
 * @returns {string} canvas data URL（image/png）
 */
export function saQrDataUrl(text, opt) {
  const o = opt || {};
  const level = o.level || 'M';
  const margin = o.margin === undefined ? 4 : o.margin;
  const outSize = o.size || 480;

  const bytes = toUtf8Bytes(String(text));
  const { version, codewords } = encodeCodewords(bytes, level);
  const matrix = buildMatrix(version, codewords, level);

  const n = matrix.length;
  const dim = n + margin * 2;
  const scale = Math.max(1, Math.round(outSize / dim));
  const px = dim * scale;

  // 用 uni-app 的 canvas 接口画 → 导出 data URL。
  // 非 H5 平台没有 document，这里直接用离屏 canvas（浏览器 H5 是本项目唯一目标）。
  const canvas = document.createElement('canvas');
  canvas.width = px;
  canvas.height = px;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, px, px);
  ctx.fillStyle = '#000000';
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      if (matrix[r][c]) {
        ctx.fillRect((c + margin) * scale, (r + margin) * scale, scale, scale);
      }
    }
  }
  return canvas.toDataURL('image/png');
}

/** 跳过画布、直接拿 0/1 矩阵（写测试时用） */
export function saQrMatrix(text, level) {
  const { version, codewords } = encodeCodewords(toUtf8Bytes(String(text)), level || 'M');
  return { version, matrix: buildMatrix(version, codewords, level || 'M') };
}

export default { saQrDataUrl, saQrMatrix };
