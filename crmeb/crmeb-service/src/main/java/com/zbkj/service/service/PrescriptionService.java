package com.zbkj.service.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.zbkj.common.model.prescription.Prescription;

import javax.servlet.http.HttpServletRequest;
import java.util.List;

/**
 * 处方服务
 */
public interface PrescriptionService extends IService<Prescription> {

    /** 用户上传处方，进入待审核 */
    Prescription submitUpload(Integer uid, String patientName, String idcard, String images, String diagnosis);

    /** 发起在线问诊，返回问诊单号与跳转地址（由调用方包成响应） */
    java.util.Map<String, Object> createConsult(Integer uid, String patientName, String idcard, String extra);

    /** 从合作平台拉取处方并落库（幂等：同一 outerRxNo 不重复插入） */
    Prescription pullFromProvider(String providerCode, String outerRxNo);

    /** 药师审核 */
    Prescription audit(Integer prescriptionId, boolean pass, String remark, Integer pharmacistId);

    /** 某用户的处方列表 */
    List<Prescription> listByUid(Integer uid, Integer auditStatus);

    /** 待审核列表（后台） */
    List<Prescription> listForAudit(Integer auditStatus, Integer limit);

    /**
     * 校验这张订单能不能买这些处方药
     *
     * 规则：订单里每个 is_rx=1 的商品，都必须能在该用户「已审核通过且在有效期内」的处方里找到。
     * @return 缺少处方的商品id列表；空列表表示通过
     */
    List<Integer> checkRxProductsCovered(Integer uid, List<Integer> rxProductIds);

    /**
     * 该用户是否有「已审核通过且在有效期内」的处方。
     *
     * 只用于把拦截提示语说清楚：有处方但没开这个药，和压根没处方，
     * 对用户来说是完全不同的两件事，提示语不能混为一谈。
     */
    boolean hasValidPrescription(Integer uid);

    /** 订单绑定处方（合规留痕） */
    void bindToOrder(Integer orderId, List<Integer> prescriptionIds);

    /** 订单已绑定的处方 */
    List<Prescription> listByOrderId(Integer orderId);

    /** 处理合作平台回调 */
    boolean handleCallback(String providerCode, HttpServletRequest request, String rawBody);

    /**
     * 取当前生效的平台配置（含 clientID / 域名 / 回调地址）。
     *
     * ⚠️ 返回的 `secretKey` 是**密文**（enc: 前缀）。调用方需要明文时，
     * 必须走 SensitiveDataCrypto.decrypt()，不要自己切字符串。
     *
     * 没有启用任何配置时返回 null。
     */
    com.zbkj.common.model.prescription.PrescriptionProviderConfig currentConfig();
}
