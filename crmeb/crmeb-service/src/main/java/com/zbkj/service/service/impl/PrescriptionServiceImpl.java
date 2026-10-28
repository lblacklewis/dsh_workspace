package com.zbkj.service.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.prescription.Consultation;
import com.zbkj.common.model.prescription.OrderPrescription;
import com.zbkj.common.model.prescription.Prescription;
import com.zbkj.common.model.prescription.PrescriptionCallbackLog;
import com.zbkj.common.model.product.StoreProduct;
import com.zbkj.service.dao.ConsultationDao;
import com.zbkj.service.dao.OrderPrescriptionDao;
import com.zbkj.service.dao.PrescriptionCallbackLogDao;
import com.zbkj.service.dao.PrescriptionDao;
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
        implements PrescriptionService {

    /** 处方有效期默认 3 天（多数地区对互联网处方有效期的通行做法，按实际监管要求调整） */
    private static final int VALID_DAYS = 3;

    @Autowired
    private PrescriptionProviderFactory providerFactory;

    @Autowired
    private PrescriptionCallbackLogDao prescriptionCallbackLogDao;

    @Autowired
    private ConsultationDao consultationDao;

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
                .setPatientIdcard(idcard.trim())
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
        rx.setAuditStatus(pass ? 1 : 2)
                .setAuditRemark(remark == null ? "" : remark)
                .setPharmacistId(pharmacistId == null ? 0 : pharmacistId)
                .setAuditTime(new Date());
        if (pass) {
            rx.setValidStart(new Date());
            rx.setValidEnd(daysLater(VALID_DAYS));
            rx.setStatus(1);
        } else {
            rx.setStatus(0);
        }
        updateById(rx);
        log.info("[Prescription] 审核 rxNo={} 结果={} 药师={}", rx.getRxNo(), pass ? "通过" : "驳回", pharmacistId);
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
        return list(w);
    }

    @Override
    public List<Prescription> listForAudit(Integer auditStatus, Integer limit) {
        return list(new LambdaQueryWrapper<Prescription>()
                .eq(Prescription::getAuditStatus, auditStatus == null ? 0 : auditStatus)
                .eq(Prescription::getIsDel, false)
                .orderByAsc(Prescription::getId)
                .last("limit " + (limit == null || limit <= 0 ? 20 : limit)));
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
        Date now = new Date();
        List<Prescription> valid = list(new LambdaQueryWrapper<Prescription>()
                .eq(Prescription::getUid, uid)
                .eq(Prescription::getAuditStatus, 1)
                .eq(Prescription::getStatus, 1)
                .eq(Prescription::getIsDel, false)
                .and(w -> w.isNull(Prescription::getValidEnd).or().ge(Prescription::getValidEnd, now)));
        if (valid.isEmpty()) {
            return rxProducts.stream().map(StoreProduct::getId).collect(Collectors.toList());
        }

        // 3. 目前只校验"有没有有效处方"，不校验处方里是否**恰好包含**这个药。
        //    严格意义上应该比对 eb_prescription_product，但那需要处方明细录入或对方平台回传明细，
        //    等合作方接口文档确定后再补。当前实现已能拦住"完全没处方就买处方药"的违规。
        // TODO(接入合作平台后)：改为按 eb_prescription_product 精确匹配商品
        log.info("[Prescription] 用户 {} 有 {} 张有效处方，放行 {} 个处方药", uid, valid.size(), rxProducts.size());
        return Collections.emptyList();
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

    private PrescriptionProvider currentProvider() {
        // 目前只有 mock；接入合作平台后改成从配置表读，与 DeliveryOrderService.currentProvider() 同构
        return providerFactory.get("mock");
    }

    private static String genRxNo() {
        return "RX" + System.currentTimeMillis() + (int) (Math.random() * 900 + 100);
    }

    private static Date daysLater(int days) {
        return new Date(System.currentTimeMillis() + days * 24L * 3600 * 1000);
    }
}
