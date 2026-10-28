package com.zbkj.service.service.prescription;

import com.zbkj.common.model.prescription.Consultation;
import com.zbkj.common.model.prescription.Prescription;

import javax.servlet.http.HttpServletRequest;

/**
 * 互联网处方平台适配器
 *
 * 合作方的对接形态通常有三种，本接口都能覆盖：
 *   1. 跳转式：createConsult 返回 redirectUrl，用户去对方平台问诊，对方回跳时带处方号
 *   2. API 式：createConsult 返回 outerNo，之后靠 queryPrescription 轮询或等回调
 *   3. 只读式：只实现 queryPrescription，处方由对方系统主动推过来
 *
 * 新增一家合作平台 = 新增一个实现类 + 在配置里启用，业务代码不用改。
 */
public interface PrescriptionProvider {

    /**
     * 平台标识
     */
    String code();

    /**
     * 平台名称
     */
    String name();

    /**
     * 发起在线问诊
     *
     * @param uid         用户id
     * @param patientName 患者实名
     * @param idcard      身份证号
     * @param extra       额外参数（症状描述、期望药品等），各平台差异放这里
     * @return 问诊记录（至少要有 consultNo；跳转式还要有 redirectUrl）
     */
    Consultation createConsult(Integer uid, String patientName, String idcard, String extra);

    /**
     * 查询处方详情
     *
     * @param outerRxNo 对方处方号
     * @return 处方对象；查不到返回 null
     */
    Prescription queryPrescription(String outerRxNo);

    /**
     * 回调验签
     *
     * ⚠️ 处方回调能直接决定"能不能卖处方药"，伪造成本极低收益极高，
     * 验签拿不到配置时必须返回 false，绝不能放行。
     */
    boolean verifyCallback(HttpServletRequest request, String rawBody);

    /**
     * 解析回调报文，返回处方对象
     */
    Prescription parseCallback(String rawBody);
}
