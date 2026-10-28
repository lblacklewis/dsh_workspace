package com.zbkj.service.service.prescription.provider;

import com.zbkj.common.model.prescription.Consultation;
import com.zbkj.common.model.prescription.Prescription;
import com.zbkj.service.service.prescription.PrescriptionProvider;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import javax.servlet.http.HttpServletRequest;
import java.util.Date;

/**
 * 本地模拟处方平台
 *
 * 用途：在跟合作互联网医院签约、拿到接口文档之前，让处方流程可以先跑通：
 *   发起问诊 → 得到处方（待审核）→ 药师审核通过 → 凭方下单
 *
 * ⚠️ 生产环境务必在配置里关掉 mock。
 */
@Slf4j
@Component
public class MockPrescriptionProvider implements PrescriptionProvider {

    @Override
    public String code() {
        return "mock";
    }

    @Override
    public String name() {
        return "本地模拟处方平台（开发用）";
    }

    @Override
    public Consultation createConsult(Integer uid, String patientName, String idcard, String extra) {
        String consultNo = "MC" + System.currentTimeMillis();
        Consultation c = new Consultation()
                .setConsultNo(consultNo)
                .setUid(uid)
                .setProvider(code())
                .setOuterNo("MOUTER" + consultNo)
                .setStatus(1)
                // 跳转式对接时前端拿这个 url 去 WebView 打开；mock 给个占位页
                .setRedirectUrl("/pages/prescription/mock_consult?consultNo=" + consultNo)
                .setRxNo("")
                .setRemark("mock 问诊单，真实对接后由合作平台返回")
                .setIsDel(false);
        log.info("[MockPrescription] 发起问诊 uid={} consultNo={}", uid, consultNo);
        return c;
    }

    @Override
    public Prescription queryPrescription(String outerRxNo) {
        if (outerRxNo == null || outerRxNo.isEmpty()) {
            return null;
        }
        // mock 规则：只要传了单号就当作对方已开方，返回一张待审核的处方
        Prescription rx = new Prescription()
                .setRxNo("MRX" + System.currentTimeMillis())
                .setUid(0)
                .setSource(2)
                .setProvider(code())
                .setOuterRxNo(outerRxNo)
                .setPatientName("")
                .setPatientIdcard("")
                .setImages("[]")
                .setDiagnosis("mock 诊断")
                .setDoctorName("mock 医师")
                .setDoctorHospital("mock 互联网医院")
                .setPharmacistId(0)
                // 关键：mock 也返回"待审核"，强制走药师审核这一步，
                // 避免开发期绕过审核，上线后发现流程缺环
                .setAuditStatus(0)
                .setAuditRemark("")
                .setIsDel(false);
        return rx;
    }

    @Override
    public boolean verifyCallback(HttpServletRequest request, String rawBody) {
        return true;
    }

    @Override
    public Prescription parseCallback(String rawBody) {
        if (rawBody == null || !rawBody.contains("outerRxNo")) {
            return null;
        }
        Prescription rx = new Prescription();
        rx.setOuterRxNo(extract(rawBody, "outerRxNo"));
        rx.setDiagnosis(extract(rawBody, "diagnosis"));
        rx.setDoctorName(extract(rawBody, "doctorName"));
        rx.setSource(2);
        rx.setProvider(code());
        rx.setAuditStatus(0);
        rx.setImages("[]");
        rx.setIsDel(false);
        return rx;
    }

    private static String extract(String json, String key) {
        String pattern = "\"" + key + "\"";
        int i = json.indexOf(pattern);
        if (i < 0) {
            return "";
        }
        int colon = json.indexOf(':', i + pattern.length());
        int start = json.indexOf('"', colon + 1);
        if (colon < 0 || start < 0) {
            return "";
        }
        int end = json.indexOf('"', start + 1);
        return end < 0 ? "" : json.substring(start + 1, end);
    }
}
