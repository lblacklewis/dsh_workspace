# 复诊开方对接 — API 文档分析（桃子 / 100CBC）

> 文档：《复诊开方对接文档》20260729，36 页
> 提取文本：`复诊开方对接文档20260729_提取文本.md`
> 分析日期：2026-10-30
> 对方标识：文档内文案为「**桃子**」H5 / 桃子后台 / 桃子医生端，域名 `*.100cbc.com`

---

## 〇、关于这份 PDF 怎么读的（给下一个接手的人，省得踩同样的坑）

这份 PDF 是 **Word 导出**的，字体结构很刁钻：大量 **Type3 单字字体**
（一个字体对象只映射一个字符，例如 obj5 的 CMap 就是 `<B5> <590D>` = "复"），
且同一字体下**码的字面长度混用**（`<B5>` 是 1 字节码、`<0F53>` 是 2 字节码，
但它们的 CMap 都声明 `<00> <FF>`）。

我先手写了一个零依赖提取器（解 FlateDecode + 解析 ToUnicode），**踩了三个坑**：
1. 从「后代字体」而不是 Type0 字体对象取 `/ToUnicode`
2. 把所有字体的 CMap 合并成一张总表（子集化后同码不同字，互相覆盖）
3. 按 `codespacerange` 固定码宽切分十六进制串

最后手写版**只抽出 311 个中文字符**（约 1%），正文几乎全是缺字。
改用 **pdfjs-dist** 后一次拿到 3390 个中文字符，内容完整可读。

**结论：不要手写 PDF 文本提取器。** 直接用 pdfjs：
```bash
mkdir -p "$TEMP/sa-pdf-lib" && cd "$TEMP/sa-pdf-lib"
npm install pdfjs-dist@4.6.82          # 装在临时目录，不进项目依赖
node extract.js <pdf> <out.txt>
```

另外 **Edge 的 `--screenshot` 无法渲染 PDF**（截出来是白页），
要看某页长什么样得走 CDP：`node docs/pdf-render.js <pdf> <out.png>`。

---

## ⚠️ 一、先说一个必须马上处理的问题：文档里泄露了真实密钥

文档「签名Demo」章节里直接贴了**真实可用示例值**，不是占位符：

```java
String secretKey = "6927HsL30B9r132A2ZFvEFu15k8bi9";
String bizID     = "AUTO_2659878840021047001";
String clientID  = "25080709334378547181301150";
```

`secretKey` 是**接口签名密钥**，配合 `clientID` 就能构造合法签名、冒充客户方调他们的接口。
另外正文示例里还出现了另一个 clientID：`24120215160816171201301150`。

**建议**：正式联调开始前，让对方**为我们的 clientID 换发一套新密钥**，
并请他们**把这批示例值作废**（他们的文档已经外传，无法确认流向）。

> 我方拿到正式凭证后，**绝不写进代码/文档/git**，只进服务端配置（环境变量或加密配置表）。

---

## 二、对方系统概览

| 项 | 值 |
|---|---|
| 调用方式 | HTTPS |
| 提交方式 | POST |
| 数据格式 | `application/json` |
| 字符编码 | UTF-8 |
| **测试域名** | `https://rp-cs.jk.100cbc.com` |
| **生产域名** | `https://rp.jk.100cbc.com` |
| 鉴权 | 请求体 `sign` 字段 + header `version=v2.1` |

### 签名算法（v2.1）

拼接顺序**固定**（注意：是把字段名也拼进去的拼接法）：

```
secretKey + "bizID" + bizID值 + "clientID" + clientID值 + "timestamp" + timestamp值
```

然后 **MD5 → 转小写** 即 `sign`。

```java
secretKey + "bizID" + bizID + "clientID" + clientID + "timestamp" + timestamp_s
```

> ⚠️ 用的是 **MD5**，强度偏弱。这是对方的既定协议，我们只能照做；
> 但**我方对外提供的回调接口**应当做得更严（见第六节：要求对方对我们的回调也签名+校验来源 IP）。

### 注意事项
- header 必须带 `version=v2.1`
- **字段是否必填以文档为准；「为空」表示没有值也必须传空字符串，否则报错**
  —— 这一条很关键，序列化时不能省略 null 字段

---

## 三、接口清单（7 个）

方向说明：**「我方调对方」= outbound**；**「对方调我方」= 需要我方提供 URL**

| # | 名称 | 接口地址 | 方向 |
|---|---|---|---|
| 3.1 | 创建问诊单 | `/api/commonRp/h5inquiry/enter`（有患者信息页）<br>`/api/commonRp/h5inquiry/startInquiry`（跳过患者信息页） | **我方调对方** |
| 3.2 | 事件通知 / 处方推送 | **我方提供** | **对方调我方** |
| 3.3 | 获取跳转链接 | **我方提供** | **对方调我方** |
| 3.4 | 客户接收待审核处方（可选） | **我方提供** | **对方调我方** |
| 3.5 | 客户推送处方审核结果（可选） | `/api/apirp/simpleRp/auditResult` | **我方调对方** |
| 3.6 | 查询订单聊天记录 | `/api/commonRp/h5inquiry/getChatRecord` | **我方调对方** |
| 3.7 | 查询订单处方结果 | `/api/apirp/inquiryRp/getResult` | **我方调对方** |

### 3.1 创建问诊单（核心）

**请求参数要点**：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `clientID` | String(26) | 是 | 对方提供 |
| `bizID` | String(50) | 是 | **三方订单ID，保证唯一性**（我用我方订单号） |
| `userID` | String(50) | 是 | 三方用户ID |
| `providerID` / `providerName` | String(50) | 空 | 店铺ID/名称（可传空串） |
| `timestamp` | String | 是 | **秒级**时间戳 |
| `sign` | String | 是 | 签名 |
| `inquiryType` | Integer | 是 | `1:图文问诊` |
| `rpTypeID` | Integer | 是 | **`0:西药`，仅支持西药** |
| `feeType` | Integer | 是 | `1:自费`，**固定传 1** |
| `inquiryTimes` | Long | 是 | 下单时间，**毫秒级** |
| `deviceType` | String | 是 | `wechat` / `h5` / `ios` / `android` |
| `isEditPatient` | Int(4) | 否 | 患者信息是否可编辑 0/1 |
| `patientInfo` | Object | 是 | 见下 |
| `medicines` | List | 是 | 见下 |

**`patientInfo`（把我方已有数据映射进去）**：

| 字段 | 必填 | 说明 |
|---|---|---|
| `patientName` | 是 | 患者姓名 |
| `patientSex` | 是 | 1:男 2:女 |
| `patientAge` | 是 | 年龄 |
| `patientPhone` | 是 | 手机号 |
| `patientWeight` | 否 | 体重(kg) |
| `patientIdNoType` | 是 | 证件类型 0:身份证 99:其他（默认 0） |
| `patientIdNo` | 是 | 证件号码 |
| `guardianName` | 否 | **患者年龄<18 必填** |
| `guardianIdNo` | 否 | **<18 必填** |
| `guardianPhone` | 否 | **<18 必填** |
| `illDesc` | 是 | 病情描述（多个逗号分隔） |
| `historyOfAllergy` | 是 | 0:无 1:有 |
| `allergyDetail` | 空 | 为 1 时必传，否则传空串 |
| `historyOfSickness` | 是 | 0:无 1:有 |
| `sicknessDetail` | 空 | 为 1 时必传，否则传空串 |
| `liver` | 是 | 肝功能 0:正常 1:异常 |
| `renal` | 是 | 肾功能 0:正常 1:异常 |
| `pregnancy` | 是 | 0:否 1:备孕 2:怀孕 3:哺乳，**男性传 0** |
| `certificateUrl` | 空 | 凭证图片，**精神科必传**，多张用 `||` 分隔 |

**`medicines[]`（我方商品要映射过去）**：

| 字段 | 必填 | 说明 |
|---|---|---|
| `goodsID` | 空 | 商品ID |
| `medicineID` | 空 | 药品ID |
| `medicineClassID` | 是 | 0:西药(默认) 1:中药 2:中成药 3:保健品 |
| `medicineName` | 是 | 药品名称 |
| `specification` | 是 | 规格，如 `12片x3板` |
| `medicineAmount` | 是 | 数量 |
| `medicationDays` | 否 | 用药天数 |
| `unit` | 空 | 默认盒 |
| `unitPrice` | 否 | **单价(分)** |
| `approvalNo` | 空 | **批准文号**，如 `国药准字H41023075` |
| `formType` | 空 | 剂型（片/粒/mg） |
| `takeDose` | 空 | 服用剂量 |
| `takeFrequence` | 空 | 服用频次（见附件2） |
| `takeDirection` | 空 | 服用方式（见附件3） |

**响应**：`code`(0成功/1失败) + `message` + `data.url`（问诊链接）

返回的 URL 形如：
```
https://rph5pro-cs.100cbc.com?bizID=...&clientID=...&timestamp=...&sign=...&deviceType=wechat&redirectUrl
```

> 注意末尾有 `redirectUrl` 参数 —— **这是回跳地址，需要我方提供**。

### 3.2 事件通知 / 处方推送（对方调我方 —— 最重要）

**`code` 事件类型**：

| code | 含义 | 是否终态 |
|---|---|---|
| 1 | 医生已开处方 | |
| 2 | 医生拒绝开方 | ✅ **终态** |
| 3 | 药师审方通过 | |
| 4 | 药师审方不通过（会返回医生处理，客户无需关注） | |
| 5 | 处方签章完成 | ✅ **终态** |

> 文档明确：**2 和 5 是订单终态**，我方只需按需处理关心的事件。

**请求参数（对方推给我们）**：
`bizID`、`code`、`message`、`clientID`、`timestamp`(毫秒)、`data`

**`data` 内容（code=1 或 3 或 5 时）**：
- `orderID`：桃子问诊单号
- `doctorID` / `doctorName`（code=1）
- `rpID`：**处方ID**
- `isReduce`：药品是否减少 0/1
- `rpMedicineList[]`：药品列表（goodsID / medicineClassID / medicineClassName / medicineName / specification / medicineAmount / unit / formType / medicationDays / takeDose / takeFrequence / takeDirection）
- `patientInfo`：患者信息
- `rp`（处方对象，code=5 时完整）：
  - `clientID`、`rpTypeID`(0西药) / `rpTypeName`、`clientType`(0个人)
  - `rpSource`(0用户选购)
  - `providerID` / `providerName`
  - **`sectionCode` / `sectionName`：科室**
  - **`primaryDiagnosis`：主诊断**
  - `enjoin`：医嘱
  - `feeType`(1自费)
  - `recipeAllPrice`：处方总价(分)
  - **`rpStatus`：0开方中 1待审方 2审方通过 3审方不通过**
  - `notPassReason`
  - `retry`：重试次数
  - **`doctorName` / `doctorTime`：开方医师 + 开方时间**
  - **`pharmacistName` / `pharmacistTime`：审方药师 + 审方时间**
  - **`rpFileStampFileID` / `rpFileStampFileUrl`：处方 PDF 文件**
  - **`rpImgFileID` / `rpImgFileUrl`：处方图片**
  - `mcImgFileUrl`：电子病历图片（定制）

**我方必须返回**：
```json
{ "code": 0, "message": "成功" }
```

### 3.3 获取跳转链接（对方调我方）

对方传：`bizID`、`rpOrderID`(桃子订单ID)、`clientID`、`requireType`（`finishInquiry` = 结束问诊）、`deviceType`、`data`
我方返回：`{code:0, message:"success", data:{url:"..."}}`

> 示例里对方给的 `url` 是 `/pages/order/order-confirm/index?prescriptionLogId=...&source=` —— **相对路径**，说明他们接受我方返回自己的页面路由。

### 3.4 客户接收待审核处方（对方调我方，可选）

这是**待审核**状态就推给我方，让我方药师先看。包含：
`bizID`、`rpID`、**`rpPDFUrl`**、`patientInfo`、`rp`（含 doctorName/doctorTime/enjoin/pharmacistName/primaryDiagnosis）、`rpMedicineList[]`

### 3.5 客户推送处方审核结果（我方调对方，可选）

⚠️ **这个接口的语义要特别注意**：是**我方把审方结果推给桃子**。

```
接口地址：/api/apirp/simpleRp/auditResult
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `bizID` | 是 | 三方订单ID |
| `rpID` | 是 | 处方ID |
| `clientID` | 是 | 客户ID |
| **`auditStatus`** | 是 | **1 不通过 / 2 通过** |
| **`outPharmacistID`** | 是 | **客户审方药师ID** |
| `timestamp` | 是 | 秒级 |
| `sign` | 是 | 签名 |

**这意味着**：我方必须有一个「**执业药师**」实体和 ID 传给对方
（对应《处方药网络零售合规指南》第二十二条：处方审核必须由本企业执业药师开展）。
**我方目前没有这个数据结构** —— 见第五节缺口。

### 3.6 查询订单聊天记录
`/api/commonRp/h5inquiry/getChatRecord`，传 `bizID`/`clientID`/`timestamp`/`inquiryTime`/`sign`，
返回医生与患者的聊天记录列表。

### 3.7 查询订单处方结果（**兜底查询，很重要**）
`/api/apirp/inquiryRp/getResult`，传 `bizID`/`clientID`/`timestamp`/`orderTime`/`sign`

**返回 `code`**：
`-1 未查询到该订单` / `0 订单处理中` / `1 医生已开处方` / `2 医生已拒方` /
`3 药师审方通过` / `4 药师审方不通过` / `5 处方签章完成`

> ✅ **这就是我在材料清单里要求的「回调丢失时的兜底查询接口」**，对方提供了。
> 我方应实现定时补偿任务：对处于中间态的订单轮询此接口。

---

## 四、附件（可直接用）

### 科室代码表（节选，共到 52）
`01 预防保健科` `02 全科医疗科` `03 内科` `04 外科` `05 妇产科` `07 儿科`
`10 眼科` `11 耳鼻咽喉科` `12 口腔科` `13 皮肤科` `15 精神科`（精神科需传 certificateUrl）
`16 传染科` `19 肿瘤科` `26 麻醉科` `27 疼痛科` `50 中医科` `51 民族医学科` `52 中西医结合科`

### 用药频次表
`QD 每日1次` `BID 每日2次` `TID 每日3次` `QID 每日4次` `PID 每日5次`
`QH 每小时1次` `Q2H/Q3H/Q4H/Q6H/Q8H/Q12H` `QOD 隔日1次` `TD 每三日1次`
`BIW 每周2次` `TIW 每周3次` `QOW 隔周1次` `2W/3W/4W` `1m 每月1次` `8W 隔月1次` `ST 立即`

### 服用方法表
`KF 口服` `SXHF 舌下含服` `WY 外用` `CF 冲服` `XR 吸入` `HF 含服`
`CQ30FZKF 餐前30分钟口服` `CQ15FZKF 餐前15分钟口服` `LCZJK 两餐之间口服` `CH2XSKF 餐后2小时口服`
`THC 涂患处` `TYYNN 涂于眼睑内` `TYHC 贴于患处` `WKSCF 温开水冲服`
`JBYY 局部用药` `PHC 喷患处` `FHC 敷患处`

---

## 五、与我方现有代码的差距（这才是真正要干的活）

我方已有的抽象层（`PrescriptionProvider`）**大方向对得上**，但**有个结构性偏差必须改**：

### 5.1 结构性偏差：叫「创建问诊」但实际是「webhook 双向」

我原来的注释假设三种形态（跳转式/API式/只读式），
这个对接实际是 **「A + 双向 webhook」**：

```
我方出站  3.1 创建问诊单 ──────────► 桃子
                                     │
用户                    ┌────────────┘
浏览器 ──► 桃子H5问诊 ──► 医生开方 ──► 药师审方 ──► 签章
                                     │
我方入站  ◄── 3.2 事件推送（code 1/3/5）/ 3.3 跳转链接 / 3.4 待审处方
我方出站  3.5 审方结果 ──────────► 桃子
```

**所以要改的**：
1. `PrescriptionProvider` 需要增加**「推审方结果」**能力（现在没有）
2. 需要**接收多个方向相反的入站接口**（现在是 `parseCallback` 单一入口）
3. `createConsult()` 返回的 `redirectUrl` **就是这个 `data.url`** —— 这一点现有设计能装下 ✅

### 5.2 字段对照

| 我方 `eb_prescription` 字段 | 桃子字段 | 能否对上 |
|---|---|---|
| `outer_rx_no` | `rpID` | ✅ |
| `outer_order_no` | `data.orderID`（问诊单号） | ✅ **本次已加字段** |
| `patient_name` | `patientInfo.patientName` | ✅ |
| `patient_idcard` | `patientInfo.patientIdNo` | ✅（我方已 AES-GCM 加密） |
| `diagnosis` | `rp.primaryDiagnosis` | ✅ |
| `section_code` / `section_name` | `rp.sectionCode` / `rp.sectionName` | ✅ **本次已加字段** |
| `doctor_name` | `rp.doctorName` | ✅ |
| `doctor_hospital` | ❌ **对方不提供** | ⚠️ 需向对方索取，或从我方合作医院信息补 |
| `pharmacist_id` / `pharmacist_name` | 对方给 `pharmacistName`；并要求我方回传 `outPharmacistID` | ✅ **本次已建药师档案** |
| `audit_source` | — | ✅ **本次已加**，区分「我方药师审」与「平台药师审」 |
| `audit_status` | `rp.rpStatus`（0/1/2/3） | ✅ 映射即可 |
| `images` | `rp.rpImgFileUrl` + `rpFileStampFileUrl`(PDF) | ✅ |
| `valid_start` / `valid_end` | ❌ 对方不提供 | ✅ **不是缺口**，见下方更正 |

> ### ⚠️ 更正：我上一版说「处方有效期是缺口」，这个结论是**错的**
>
> 我当时只看了 API 文档，没去看我方现有代码。
> 实际 `PrescriptionServiceImpl` **早就实现了有效期**：
> ```java
> /** 处方有效期默认 3 天（多数地区对互联网处方有效期的通行做法，按实际监管要求调整） */
> private static final int VALID_DAYS = 3;
>
> // 审方通过时
> rx.setValidStart(new Date());
> rx.setValidEnd(daysLater(VALID_DAYS));
> ```
> 而且 `checkRxProductsCovered` 里也已经在用 `valid_end` 做过滤：
> ```java
> .and(w -> w.isNull(Prescription::getValidEnd).or().ge(Prescription::getValidEnd, now))
> ```
>
> 所以**有效期不是我方缺口**。真正要问对方的只是：
> 「你们平台内部对处方有效期的定义是几天？」——
> 如果我方 3 天比对方严格，是安全的（宁可早失效）；如果我方更宽松，才需要收紧。
> **这一条从"缺口"降级为"确认项"。**

### 5.3 必须新增的数据结构（✅ 2026-10-30 已完成）

**A. 执业药师实体** ✅
对方接口 `3.5` 要求传 `outPharmacistID`（客户审方药师ID）。
我方原来只有 `pharmacist_id`（后台管理员id），**没有真正的药师档案**。
按《处方药网络零售合规指南》第八条、第二十二条，这套是必须建的。

已建 `eb_pharmacist` 表 + 后台 CRUD + 前端公示接口，详见第八节。

**B. 配置表** `eb_prescription_provider` ✅
原来 `currentProvider()` 硬编码 `providerFactory.get("mock")`，
已改成从配置表读（与配送模块同构），并沿用「跳过代码未实现的平台」防护。

### 5.4 我方可提供的能力（对方需要的）

我要给对方 **3 个 URL**：
1. `3.2` 事件推送接收地址
2. `3.3` 获取跳转链接地址
3. `3.4` 待审核处方接收地址（可选，但我方要自己审方，**建议启用**）

**并需给对方 `redirectUrl`**（问诊结束回跳我方的页面）。

这三项已落成 `eb_prescription_provider` 的 `callback_url` / `redirect_url` / `audit_url` 三个字段，
填上即可。

⚠️ 这 3 个 URL **必须是公网 HTTPS**。
我方域名还在 ICP 备案 —— **这是当前唯一的硬阻塞**。

---

## 六、合规对照（依据《处方药网络零售合规指南》药监综药管函〔2026〕282号）

| 条款 | 要求 | 本对接是否满足 |
|---|---|---|
| 第十九条 | 凭处方销售，来源真实可靠，**实名制** | ✅ 对方给 `patientIdNo` + `patientName`，可实名核验 |
| 第二十条 | 执业药师**逐项检查处方要素** | ✅ 对方给诊断/医师/药品明细/科室；⚠️ **缺有效期** |
| **第二十二条** | 审方必须**本企业执业药师**，**不得由他人或 AI 代劳** | ⚠️ **对方也审方（`rpStatus=2`），但我方仍须自审**；且需回传 `outPharmacistID` |
| 第二十一条 | 审核前不得提供购买服务；**避免处方重复使用**；处方存档备查 | ⚠️ 需我方实现：`rpID` 唯一约束防重 + 处方 PDF/图片**转存归档** |
| 第二十四条 | 对**伪造/已篡改/已使用/含禁售药品**的处方拒绝调配 | ✅ 对方给 `rpStatus`、`notPassReason`；可据此拒绝 |
| 第十八条 | 未成年人需监护人同意 | ✅ 对方强制 `<18` 传监护人信息，与我方要求一致 |
| 第十五条 | 充分告知用药风险并经确认 | 我方前台已有风险提示，需与对方问诊告知衔接 |
| 第三十一条 | 妥善保存购药处方、在线药学服务记录 | 需实现归档 + 与订单关联 |

### ⚠️ 三个必须补的合规动作

1. **建执业药师档案 + 公示**（第八条、第二十二条）
2. **处方有效期**：对方不提供。要么向对方索取，要么我方按「开方时间 + N 天」自行计算并写进配置
   —— 但**自行推定有效期有合规风险，优先向对方确认他们的有效期规则**
3. **处方重复使用防护**：`rpID` 加唯一索引，已用过的处方号拒绝再次下单

---

## 七、还需向对方确认的问题（文档没写清）

1. ⚠️ **密钥轮换**：示例里的 secretKey/clientID 是否还有效？请为我方换发正式凭证并作废示例值
2. ⚠️ **处方有效期**：处方有效期规则是什么？接口里为何没有有效期字段？
3. ⚠️ **`doctor_hospital`（医师所属医院）** 能否提供？（处方留存要素）
4. ⚠️ **`providerID`/`providerName`** 对我方（无连锁门店概念）该传什么？
5. **回调重试策略**：3.2 推送失败重试几次？间隔？是否幂等（同一 rpID 会重复推吗）？
6. **回调验签**：对方调我方时，**是否也带 `sign`**？我方按什么规则校验？
   （文档 3.2 的请求参数列表里**没有 sign 字段**，但正文示例里有一个 `sign` —— 需确认）
7. **回调来源 IP**：是否可提供固定出口 IP 段供我方做白名单？
8. **沙箱**：`rp-cs.jk.100cbc.com` 是否就是测试环境？测试环境的 clientID/secretKey 单独给吗？
9. **`rpTypeID` 仅支持西药 0** —— 我方若卖中成药/保健品，是否可通过 `medicineClassID` 传？还是完全不能在处方里出现？
10. **处方 PDF/图片 URL 有效期**：`rpFileStampFileUrl` / `rpImgFileUrl` 是否长期有效？
    是否允许我方**下载转存**？（法规要求我方存档备查）
11. **`3.5` 的 `outPharmacistID`**：格式有要求吗？我方自建药师档案的 ID 可否直接用？
12. **联调安排**：测试环境是否已为我方开通？是否需要我方先提供 3 个回调 URL 才能联调？

---

## 八、实施进度（2026-10-30 更新）

| 阶段 | 事项 | 状态 |
|---|---|---|
| **0** | 要对方换发正式密钥；确认下面 9 个问题 | ⏳ **等对方** |
| 1 | 建执业药师档案表 + 后台 CRUD + 公示接口 | ✅ **已完成** |
| 2 | 建 `eb_prescription_provider` 配置表，`secretKey` 加密存储 | ✅ **已完成**（表 + 模型，密钥待填） |
| 3 | 签名工具类 `TaozhiSignService`（MD5，拼接顺序照文档） | ✅ **已完成**（⚠️ 见下方自验说明） |
| 4 | `currentProvider()` 改为从配置读 + 启动自检 + 审方人资格校验 | ✅ **已完成** |
| 5 | 实现 `TaozhiPrescriptionProvider`（3.1/3.5/3.6/3.7 出站） | ⏳ 等正式凭证 |
| 6 | 实现 3 个入站接口（3.2/3.3/3.4） | ⏳ 等域名 HTTPS |
| 7 | 处方归档（下载 PDF/图片转存） | ⏳ |
| 8 | 处方防重 + 药品明细逐项比对 | ⏳ 部分已有 |
| 9 | 联调 + 回归 | ⏳ |

### 关于签名工具类的自验结果（**重要，别误判**）

文档给了 Java 示例代码，但**给的示例值互相之间算不通**。我用文档第 14 页的
`sign=fbcd8f37a2e0bbcd3e949c615dec1a07` 反推，试了 6 种常见拼法（含文档写明的规则）
**全部不匹配**；第 20 页 `auditResult` 的 `sign` 试了 5 种也不匹配。

脚本留存：`docs/verify-taozhi-sign.js`

**结论**：
1. 文档里的 `secretKey` 只是「格式示例」，与示例 JSON 里的 clientID **不是同一套**
2. 我方**无法离线自验签名**，必须等对方给正式凭证后在沙箱验证
3. 文档只写明了 3.1 的拼接顺序（`secretKey + bizID + clientID + timestamp`），
   **3.5/3.6/3.7 字段更多，但文档没说要不要把那些字段也拼进签名**
   —— 所以 `TaozhiSignService.signWithOrder()` 把字段顺序做成**可传参**，
   拿到对方确认后只改配置，不用改调用方

### 已实测验证的合规控制（不是"写了就算"）

| 验证项 | 结果 |
|---|---|
| 开启审方权限但不填注册单位 | ❌ 被拒：`开启审方权限前必须填写执业注册单位` |
| 注册有效期已过期仍开启审方权限 | ❌ 被拒：`执业注册有效期已过期，不能开启审方权限` |
| 无审方权限却要前台公示 | ❌ 被拒：`只有具备审方权限的药师才能在商城前台公示` |
| 新建药师时身份证落库形态 | ✅ `enc:cUiC6p66…`（68 字符密文），**全库无明文命中** |
| 后台列表返回身份证 | ✅ 显示「已加密」，不返回密文也不返回明文 |
| **有合格药师时用非药师账号审方** | ❌ **被拦截**：`该药师当前不可用于审方…: 6`（admin 的 id=6） |
| 启动自检 | ✅ `处方平台自检：代码已实现=[mock] 配置需清理=[taozhi] 当前生效=mock` |

> **审方人资格校验采用「自激活」策略**：
> 只要 `eb_pharmacist` 里存在可审方药师就**强制校验**，一条都没有时放行但打 ERROR 点名。
> 这样不会把演示环境打死，同时**上线前录入药师后自动开始强制**，不依赖谁记得打开开关。
> 上面第 6 条就是录入药师后**真实被拦住**的证据。

---

## 九、还需向对方确认（**已从 12 条压缩到 9 条**）

原先我列的 12 条里，有 3 条我**自己就能查证/已解决**，不用麻烦对方：

| 原来列的 | 处理结果 |
|---|---|
| ~~处方有效期规则~~ | ✅ 我方代码已有 `VALID_DAYS=3` + `valid_end` 过滤。**降级为确认项**（见问题 6） |
| ~~回调是否带 sign~~ | ⚠️ 文档自相矛盾（字段列表无 sign、JSON 示例有 sign），**仍要问**（见问题 4） |
| ~~处方图片 URL 是否可下载~~ | ⚠️ 仍需问（见问题 5） |

### 必须问的 9 条

| # | 问题 | 为什么必须问 |
|---|---|---|
| 1 | ⚠️ **文档示例里的 `secretKey`/`clientID` 是否还有效？请为我方换发正式凭证并作废示例值** | 文档已外传，示例密钥泄露；且实测示例值互相算不通 |
| 2 | ⚠️ **3.5 / 3.6 / 3.7 的 sign 拼接规则**：是否也按「secretKey + 字段名 + 字段值…」？参与签名的字段有哪些、顺序如何？ | 文档只写了 3.1 的规则，其余接口字段更多却没说 |
| 3 | ⚠️ **回调（3.2）你们调我方时，sign 放在哪、用哪个 key 签、什么顺序？** | 文档字段列表里**没有 sign**，但 JSON 示例里**有** —— 自相矛盾。这直接决定我方能不能验签、敢不敢放行 |
| 4 | **回调重试策略**：失败重试几次、间隔多久？同一 `rpID` 会不会重复推送（幂等）？ | 决定我方要不要做更激进的兜底轮询 |
| 5 | **处方 PDF/图片 URL 是否长期有效？是否允许我方下载转存归档？** | 法规要求我方**存档备查**，对方 URL 过期我留不下证据 |
| 6 | **你们平台内部对处方有效期的定义是几天？** | 我方现用 3 天；若我方比对方宽，需收紧 |
| 7 | **`doctor_hospital`（医师所属医院）能否提供？** | 处方留存要素，我方表里有这个字段但目前拿不到值 |
| 8 | **`providerID`/`providerName`** 对我方（无连锁门店概念）该传什么？传空串可以吗？ | 文档标"空"（可选），但要求"没有值必须传空字符串"，需确认 |
| 9 | **沙箱**：`rp-cs.jk.100cbc.com` 是测试环境吗？会给独立测试凭证吗？能否**先用 IP+HTTP** 联调（我方域名在备案）？ | 备案期间想先联调 |

> 另有 2 条**可以等**（不急，但迟早要问）：
> - `rpTypeID` 仅支持西药 0 —— 我方若卖中成药/保健品，是靠 `medicineClassID` 传还是完全不能进处方？
> - `3.5` 的 `outPharmacistID` 格式有要求吗？我方自建药师档案的 ID 可直接用吗？

---

## 十、一句话结论

**这份文档质量不错、接口设计完整**（7 个接口 + 兜底查询 + 完整附件码表），
**我方的数据模型能覆盖绝大部分字段**。

**已完成（不依赖对方、不依赖备案）**：
1. ✅ 执业药师档案 + 后台 CRUD + 前台公示（合规第八条、第二十二条）
2. ✅ 处方平台配置表 + `secretKey` 加密存储 + 「跳过未实现平台」防护
3. ✅ 签名工具类（字段顺序可配）+ 签名样例反向验证（**证明文档示例值算不通**）
4. ✅ 审方人资格**自激活式**强制校验 —— **已实测拦住非药师审方**

**两个真正的阻塞**：
1. **公网 HTTPS**（ICP 备案）—— 3 个入站接口都要
2. **正式凭证**（clientID/secretKey）—— 没有就没法联调

**一个安全提醒**：文档里贴了真实密钥，请对方换发。

**一个自我更正**：我上一版说"处方有效期是缺口"，查了代码后发现**早就实现了**，是我看漏了。
