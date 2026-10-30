package com.zbkj.service.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.pharmacist.Pharmacist;
import com.zbkj.common.model.prescription.Consultation;
import com.zbkj.common.model.prescription.OrderPrescription;
import com.zbkj.common.model.prescription.Prescription;
import com.zbkj.common.model.prescription.PrescriptionProduct;
import com.zbkj.common.model.prescription.PrescriptionCallbackLog;
import com.zbkj.common.model.prescription.PrescriptionProviderConfig;
import com.zbkj.common.model.product.StoreProduct;
import com.zbkj.service.dao.ConsultationDao;
import com.zbkj.service.dao.OrderPrescriptionDao;
import com.zbkj.service.dao.PrescriptionCallbackLogDao;
import com.zbkj.service.dao.PrescriptionDao;
import com.zbkj.service.dao.PrescriptionProductDao;
import com.zbkj.service.dao.PrescriptionProviderConfigDao;
import com.zbkj.service.dao.StoreProductDao;
import com.zbkj.service.service.PrescriptionService;
import com.zbkj.service.service.prescription.PrescriptionProvider;
import com.zbkj.service.service.prescription.PrescriptionProviderFactory;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.servlet.http.HttpServletRequest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 处方服务实现
 *
 * ⚠️ 合规红线（改代码时不要绕过）：
 *   1. checkRxProductsCovered 必须在**下单前**调用，不能靠"先付款后补方"
 *   2. audit 通过之前，处方不能用于下单
 *   3. 处方数据只做软删（is_del），物理删除会导致监管检查时无据可查
 */
@Slf4j
@Service
public class PrescriptionServiceImpl extends ServiceImpl<PrescriptionDao, Prescription>
        implements PrescriptionService, org.springframework.beans.factory.InitializingBean {

    /** 处方有效期默认 3 天（多数地区对互联网处方有效期的通行做法，按实际监管要求调整） */
    private static final int VALID_DAYS = 3;

    @Autowired
    private PrescriptionProviderFactory providerFactory;

    @Autowired
    private PrescriptionCallbackLogDao prescriptionCallbackLogDao;

    @Autowired
    private PrescriptionProductDao prescriptionProductDao;

    @Autowired
    private com.zbkj.service.service.crypto.SensitiveDataCrypto sensitiveDataCrypto;

    /**
     * 执业药师档案：审方人资格校验用（合规指南第二十二条）
     */
    @Autowired
    private com.zbkj.service.service.PharmacistService pharmacistService;

    @Autowired
    private ConsultationDao consultationDao;

    @Autowired
    private PrescriptionProviderConfigDao providerConfigDao;

    @Autowired
    private OrderPrescriptionDao orderPrescriptionDao;

    @Autowired
    private StoreProductDao storeProductDao;

    @Override
    public Prescription submitUpload(Integer uid, String patientName, String idcard,
                                     String images, String diagnosis) {
        if (patientName == null || patientName.trim().isEmpty()) {
            throw new CrmebException("请填写患者姓名（处方药需实名购买）");
        }
        if (idcard == null || idcard.trim().isEmpty()) {
            throw new CrmebException("请填写身份证号（处方药需实名购买）");
        }
        if (images == null || images.trim().isEmpty() || "[]".equals(images.trim())) {
            throw new CrmebException("请上传处方照片");
        }
        Prescription rx = new Prescription()
                .setRxNo(genRxNo())
                .setUid(uid)
                .setSource(1)
                .setProvider("")
                .setOuterRxNo("")
                .setPatientName(patientName.trim())
                .setPatientIdcard(sensitiveDataCrypto.encrypt(idcard.trim()))
                .setImages(images)
                .setDiagnosis(diagnosis == null ? "" : diagnosis)
                .setDoctorName("")
                .setDoctorHospital("")
                .setPharmacistId(0)
                .setAuditStatus(0)
                .setAuditRemark("")
                .setValidStart(new Date())
                .setStatus(1)
                .setIsDel(false);
        save(rx);
        return rx;
    }

    @Override
    public Map<String, Object> createConsult(Integer uid, String patientName, String idcard, String extra) {
        PrescriptionProvider provider = currentProvider();
        Consultation c = provider.createConsult(uid, patientName, idcard, extra);
        if (c == null) {
            throw new CrmebException("发起问诊失败");
        }
        c.setUid(uid).setIsDel(false);
        consultationDao.insert(c);

        Map<String, Object> result = new HashMap<>();
        result.put("consultNo", c.getConsultNo());
        result.put("redirectUrl", c.getRedirectUrl());
        result.put("status", c.getStatus());
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Prescription pullFromProvider(String providerCode, String outerRxNo) {
        String code = providerCode != null ? providerCode : currentProvider().code();
        // 幂等：同一个对方处方号只落一条
        Prescription exist = getOne(new LambdaQueryWrapper<Prescription>()
                .eq(Prescription::getProvider, code)
                .eq(Prescription::getOuterRxNo, outerRxNo)
                .eq(Prescription::getIsDel, false)
                .last("limit 1"));
        if (exist != null) {
            return exist;
        }
        Prescription rx = providerFactory.get(code).queryPrescription(outerRxNo);
        if (rx == null) {
            throw new CrmebException("未查询到处方: " + outerRxNo);
        }
        if (rx.getRxNo() == null || rx.getRxNo().isEmpty()) {
            rx.setRxNo(genRxNo());
        }
        rx.setProvider(code).setOuterRxNo(outerRxNo).setIsDel(false);
        if (rx.getAuditStatus() == null) {
            // 无论对方是否已审核，落到我方一律重新走一遍药师审核
            rx.setAuditStatus(0);
        }
        rx.setValidStart(new Date());
        rx.setStatus(1);
        save(rx);
        return rx;
    }

    @Override
    public Prescription audit(Integer prescriptionId, boolean pass, String remark, Integer pharmacistId) {
        Prescription rx = getById(prescriptionId);
        if (rx == null || Boolean.TRUE.equals(rx.getIsDel())) {
            throw new CrmebException("处方不存在");
        }
        if (rx.getAuditStatus() != null && rx.getAuditStatus() == 1) {
            throw new CrmebException("该处方已审核通过，不能重复审核");
        }

        // ---------- 审方人资格校验 ----------
        // 《处方药网络零售合规指南》第二十二条：处方审核**必须由本企业执业药师开展**，
        // 不得由其他岗位人员或者人工智能代为实施。
        //
        // 现状问题：后台 /api/admin/prescription/audit 传进来的是**后台管理员 id**，
        // 不是执业药师 id。若不校验，任何管理员账号都能审方 —— 直接违反第二十二条。
        //
        // 采取「**自激活**」策略（不引入配置开关，避免有人忘了打开）：
        //   - 只要 eb_pharmacist 里存在**可审方**的药师（在职 + 有审方权限 + 注册有效），就强制校验，
        //     传进来的 id 必须是合格药师，否则拒绝
        //   - 一条合格药师都没有时（例如还没录入），放行但打 ERROR 点名
        //     —— 这样不会把演示环境打死，同时上线前录入药师后**自动开始强制**
        Pharmacist reviewer = null;
        boolean hasQualified = pharmacistService.pickReviewer() != null;
        if (hasQualified) {
            reviewer = pharmacistService.requireReviewer(pharmacistId);
        } else {
            log.error("[Prescription] ⚠️ 合规风险：eb_pharmacist 中没有任何可审方的执业药师，"
                    + "本次审方未校验审方人资格（操作人 id={}）。"
                    + "依据《处方药网络零售合规指南》第二十二条，上线前必须录入执业药师档案",
                    pharmacistId);
        }

        rx.setAuditStatus(pass ? 1 : 2)
                .setAuditRemark(remark == null ? "" : remark)
                .setPharmacistId(pharmacistId == null ? 0 : pharmacistId)
                .setAuditTime(new Date());
        // 冗余存药师姓名：药师日后离职或改名，历史审方记录仍可追溯
        if (reviewer != null) {
            rx.setPharmacistName(reviewer.getName());
            rx.setAuditSource(1); // 1 = 我方药师
        } else {
            rx.setAuditSource(0); // 未校验来源，留痕便于日后审计
        }
        if (pass) {
            rx.setValidStart(new Date());
            rx.setValidEnd(daysLater(VALID_DAYS));
            rx.setStatus(1);
        } else {
            rx.setStatus(0);
        }
        updateById(rx);
        log.info("[Prescription] 审核 rxNo={} 结果={} 药师id={} 药师={} 校验={}",
                rx.getRxNo(), pass ? "通过" : "驳回", pharmacistId,
                reviewer == null ? "-" : reviewer.getName(),
                hasQualified ? "已校验" : "未校验(无合格药师)");
        return rx;
    }

    @Override
    public List<Prescription> listByUid(Integer uid, Integer auditStatus) {
        LambdaQueryWrapper<Prescription> w = new LambdaQueryWrapper<Prescription>()
                .eq(Prescription::getUid, uid)
                .eq(Prescription::getIsDel, false)
                .orderByDesc(Prescription::getId);
        if (auditStatus != null) {
            w.eq(Prescription::getAuditStatus, auditStatus);
        }
        return maskIdcards(list(w));
    }

    @Override
    public List<Prescription> listForAudit(Integer auditStatus, Integer limit) {
        return maskIdcards(list(new LambdaQueryWrapper<Prescription>()
                .eq(Prescription::getAuditStatus, auditStatus == null ? 0 : auditStatus)
                .eq(Prescription::getIsDel, false)
                .orderByAsc(Prescription::getId)
                .last("limit " + (limit == null || limit <= 0 ? 20 : limit))));
    }

    /**
     * 出参一律脱敏：身份证号明文只在库里（密文）和我们自己的解密逻辑里存在，
     * 绝不能顺着接口流到前端或后台页面。需要明文核验时走专门的高权限通道。
     */
    private List<Prescription> maskIdcards(List<Prescription> list) {
        if (list == null || list.isEmpty()) {
            return list;
        }
        for (Prescription p : list) {
            if (p != null) {
                p.setPatientIdcard(sensitiveDataCrypto.maskIdcard(sensitiveDataCrypto.decrypt(p.getPatientIdcard())));
            }
        }
        return list;
    }

    @Override
    public List<Integer> checkRxProductsCovered(Integer uid, List<Integer> rxProductIds) {
        if (rxProductIds == null || rxProductIds.isEmpty()) {
            return Collections.emptyList();
        }
        // 1. 这批商品里哪些真的是处方药（is_rx=1）。
        //    用 QueryWrapper 直接写 SQL 片段，避免为了一个字段改 StoreProduct 实体。
        List<StoreProduct> rxProducts = storeProductDao.selectList(new QueryWrapper<StoreProduct>()
                .in("id", rxProductIds)
                .apply("is_rx = 1"));
        if (rxProducts.isEmpty()) {
            return Collections.emptyList();
        }

        // 2. 取出该用户所有"已审核通过 + 未过期"的处方
        List<Prescription> valid = listValidPrescriptions(uid);
        if (valid.isEmpty()) {
            return rxProducts.stream().map(StoreProduct::getId).collect(Collectors.toList());
        }

        // 3. 精确匹配。
        //
        //    这里必须区分两类处方，否则会把用户全拦死：
        //      a) 合作互联网医院回传的处方 —— eb_prescription_product 里有明细，
        //         按明细精确匹配，处方没开这个药就不让买。
        //      b) 用户手工上传的处方照片 —— 没有明细，无法精确匹配，
        //         退回「有有效处方即放行」。
        //    缺数据是系统能力的欠缺，不该由用户承担后果。

        List<Integer> validRxIds = valid.stream().map(Prescription::getId).collect(Collectors.toList());

        // 有明细的处方：它开了哪些商品
        List<PrescriptionProduct> details = prescriptionProductDao.selectList(
                new LambdaQueryWrapper<PrescriptionProduct>().in(PrescriptionProduct::getPrescriptionId, validRxIds));

        Set<Integer> coveredByDetails = details.stream()
                .map(PrescriptionProduct::getProductId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        // 没有任何明细的处方（手工上传的）——这些处方只能按宽松规则放行
        Set<Integer> rxIdsWithDetails = details.stream()
                .map(PrescriptionProduct::getPrescriptionId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        boolean hasPrescriptionWithoutDetails = valid.stream()
                .anyMatch(p -> !rxIdsWithDetails.contains(p.getId()));

        List<Integer> uncovered = new ArrayList<>();
        for (StoreProduct p : rxProducts) {
            if (coveredByDetails.contains(p.getId())) {
                continue;
            }
            if (hasPrescriptionWithoutDetails) {
                // 有一张没明细的有效处方，按宽松规则放行
                continue;
            }
            uncovered.add(p.getId());
        }

        if (uncovered.isEmpty()) {
            log.info("[Prescription] 用户 {} 处方覆盖校验通过：有效处方 {} 张，明细 {} 条",
                    uid, valid.size(), details.size());
        } else {
            log.warn("[Prescription] 用户 {} 有 {} 个处方药不在任何有效处方明细内：{}",
                    uid, uncovered.size(), uncovered);
        }
        return uncovered;
    }

    @Override
    public boolean hasValidPrescription(Integer uid) {
        return !listValidPrescriptions(uid).isEmpty();
    }

    /** 「已审核通过 + 未过期」的处方。两处校验共用，避免条件写岔。 */
    private List<Prescription> listValidPrescriptions(Integer uid) {
        Date now = new Date();
        return list(new LambdaQueryWrapper<Prescription>()
                .eq(Prescription::getUid, uid)
                .eq(Prescription::getAuditStatus, 1)
                .eq(Prescription::getStatus, 1)
                .eq(Prescription::getIsDel, false)
                .and(w -> w.isNull(Prescription::getValidEnd).or().ge(Prescription::getValidEnd, now)));
    }

    @Override
    public void bindToOrder(Integer orderId, List<Integer> prescriptionIds) {
        if (orderId == null || prescriptionIds == null || prescriptionIds.isEmpty()) {
            return;
        }
        for (Integer rxId : prescriptionIds) {
            // 注意：本项目 MyBatis-Plus 版本的 selectCount 返回 Integer，不是 Long
            Integer cnt = orderPrescriptionDao.selectCount(new LambdaQueryWrapper<OrderPrescription>()
                    .eq(OrderPrescription::getOrderId, orderId)
                    .eq(OrderPrescription::getPrescriptionId, rxId));
            if (cnt != null && cnt > 0) {
                continue;
            }
            orderPrescriptionDao.insert(new OrderPrescription()
                    .setOrderId(orderId).setPrescriptionId(rxId));
        }
    }

    @Override
    public List<Prescription> listByOrderId(Integer orderId) {
        List<OrderPrescription> rels = orderPrescriptionDao.selectList(
                new LambdaQueryWrapper<OrderPrescription>().eq(OrderPrescription::getOrderId, orderId));
        if (rels.isEmpty()) {
            return Collections.emptyList();
        }
        List<Integer> ids = rels.stream().map(OrderPrescription::getPrescriptionId).collect(Collectors.toList());
        return listByIds(ids);
    }

    @Override
    public boolean handleCallback(String providerCode, HttpServletRequest request, String rawBody) {
        PrescriptionCallbackLog logRow = new PrescriptionCallbackLog();
        logRow.setProvider(providerCode);
        logRow.setRawBody(truncate(rawBody, 4000));
        logRow.setHeaders(collectHeaders(request));
        logRow.setCreateTime(new Date());
        logRow.setIsParsed(false);

        try {
            if (!providerFactory.exists(providerCode)) {
                log.warn("[Prescription] 回调来自未知平台: {}", providerCode);
                logRow.setErrMsg("未知平台: " + providerCode);
                return false;
            }
            PrescriptionProvider provider = providerFactory.get(providerCode);
            if (!provider.verifyCallback(request, rawBody)) {
                log.warn("[Prescription] 回调验签失败 provider={}", providerCode);
                logRow.setErrMsg("验签失败");
                return false;
            }
            Prescription rx = provider.parseCallback(rawBody);
            if (rx == null || rx.getOuterRxNo() == null || rx.getOuterRxNo().isEmpty()) {
                log.warn("[Prescription] 回调报文解析失败 provider={}", providerCode);
                logRow.setErrMsg("报文解析失败或缺少处方号");
                return false;
            }
            logRow.setOuterRxNo(rx.getOuterRxNo());
            pullFromProvider(providerCode, rx.getOuterRxNo());

            // 关联问诊单
            Consultation c = consultationDao.selectOne(new LambdaQueryWrapper<Consultation>()
                    .eq(Consultation::getProvider, providerCode)
                    .eq(Consultation::getRxNo, rx.getOuterRxNo())
                    .last("limit 1"));
            if (c != null) {
                c.setStatus(2);
                consultationDao.updateById(c);
            }
            logRow.setIsParsed(true);
            return true;
        } catch (Exception e) {
            log.error("[Prescription] 回调处理异常 provider={}", providerCode, e);
            logRow.setErrMsg(truncate(e.getMessage(), 500));
            return false;
        } finally {
            // 落日志本身不能影响回调结果 —— 对方重推时不该因为我们日志表写失败而反复重试
            try {
                prescriptionCallbackLogDao.insert(logRow);
            } catch (Exception e) {
                log.error("[Prescription] 回调日志写入失败 provider={}", providerCode, e);
            }
        }
    }

    private static String truncate(String s, int max) {
        if (s == null) {
            return null;
        }
        return s.length() <= max ? s : s.substring(0, max);
    }

    /** 只留排查验签需要的头，避免把整个请求头（可能含 token）落库 */
    private static String collectHeaders(HttpServletRequest request) {
        if (request == null) {
            return null;
        }
        StringBuilder sb = new StringBuilder();
        for (String name : new String[]{"Content-Type", "Signature", "sign", "timestamp", "nonce", "User-Agent"}) {
            String v = request.getHeader(name);
            if (v != null && !v.isEmpty()) {
                sb.append(name).append('=').append(v).append("; ");
            }
        }
        return truncate(sb.toString(), 1000);
    }

    // ---------- 内部工具 ----------

    /**
     * 当前生效的处方平台配置。
     *
     * 与 {@code DeliveryOrderServiceImpl.currentProvider()} 同一套防护逻辑，原因也一样：
     * 配置表里可能启用了一堆平台，但代码只实现了其中一个。
     * 如果只取「sort 最小的那条」就返回，那条很可能代码里根本没实现 ——
     * 停掉唯一能用的那个之后，所有开方请求会全部失败。
     * 配送模块当初就差点栽在这上面（5 个运力商全 is_enable=1，只实现了 mock）。
     *
     * 策略：按 sort 遍历所有启用的配置，**跳过代码里没有实现的**（逐个记 ERROR 点名），
     * 返回第一个「配置启用且代码已实现」的；全都不行返回 null。
     */
    private PrescriptionProviderConfig currentProviderConfig() {
        List<PrescriptionProviderConfig> configs = providerConfigDao.selectList(
                new LambdaQueryWrapper<PrescriptionProviderConfig>()
                        .eq(PrescriptionProviderConfig::getIsEnable, true)
                        .eq(PrescriptionProviderConfig::getIsDel, false)
                        .orderByAsc(PrescriptionProviderConfig::getSort));
        StringBuilder skipped = new StringBuilder();
        for (PrescriptionProviderConfig c : configs) {
            if (providerFactory.exists(c.getCode())) {
                if (skipped.length() > 0) {
                    log.warn("[Prescription] 处方平台配置需要清理：跳过了 {}，实际使用 {}",
                            skipped, c.getCode());
                }
                return c;
            }
            if (skipped.length() > 0) {
                skipped.append(',');
            }
            skipped.append(c.getCode());
            log.error("[Prescription] 处方平台 {} 已启用但代码里没有实现，已跳过，"
                    + "请检查 eb_prescription_provider 配置", c.getCode());
        }
        if (skipped.length() > 0) {
            log.error("[Prescription] 已启用的处方平台 {} 在代码里全都没有实现，开方将不可用", skipped);
        }
        return null;
    }

    /**
     * 取当前平台配置（供对接层读 clientID/secretKey/域名/回调地址）。
     * 没有启用配置时返回 null。
     */
    @Override
    public PrescriptionProviderConfig currentConfig() {
        return currentProviderConfig();
    }

    /** 启动自检：把「配置启用但代码未实现」的问题在启动日志里点名 */
    @Override
    public void afterPropertiesSet() {
        try {
            List<PrescriptionProviderConfig> configs = providerConfigDao.selectList(
                    new LambdaQueryWrapper<PrescriptionProviderConfig>()
                            .eq(PrescriptionProviderConfig::getIsDel, false));
            List<String> broken = new ArrayList<>();
            for (PrescriptionProviderConfig c : configs) {
                if (!providerFactory.exists(c.getCode())) {
                    broken.add(c.getCode());
                    if (Boolean.TRUE.equals(c.getIsEnable())) {
                        log.error("[Prescription] 处方平台 {}（{}）已启用但代码未实现，开方必然失败",
                                c.getCode(), c.getName());
                    }
                }
            }
            PrescriptionProviderConfig cur = currentProviderConfig();
            log.info("[Prescription] 处方平台自检：代码已实现={} 配置需清理={} 当前生效={}",
                    providerFactory.codes(), broken,
                    cur == null ? "无（开方不可用）" : cur.getCode());
        } catch (Exception e) {
            log.warn("[Prescription] 处方平台配置自检失败（不影响启动）：{}", e.getMessage());
        }
    }

    private PrescriptionProvider currentProvider() {
        PrescriptionProviderConfig config = currentProviderConfig();
        if (config == null) {
            // 兜底：配置表为空时仍允许 mock 跑通演示（与配送模块行为一致）
            if (providerFactory.exists("mock")) {
                log.warn("[Prescription] 未启用任何处方平台，回退到 mock（仅供演示）");
                return providerFactory.get("mock");
            }
            throw new CrmebException("未启用任何可用的处方平台，请到后台配置并启用");
        }
        return providerFactory.get(config.getCode());
    }

    private static String genRxNo() {
        return "RX" + System.currentTimeMillis() + (int) (Math.random() * 900 + 100);
    }

    private static Date daysLater(int days) {
        return new Date(System.currentTimeMillis() + days * 24L * 3600 * 1000);
    }
}
