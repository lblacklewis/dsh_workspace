package com.zbkj.front.controller;

import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.prescription.Prescription;
import com.zbkj.common.model.user.User;
import com.zbkj.common.result.CommonResult;
import com.zbkj.service.service.PrescriptionService;
import com.zbkj.service.service.UserService;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 互联网处方（前台）
 *
 * 合规：处方药"先方后药"，本模块是下单前的必经环节
 */
@Slf4j
@RestController
@RequestMapping("api/front/prescription")
@Api(tags = "处方控制器")
public class PrescriptionController {

    @Autowired
    private PrescriptionService prescriptionService;

    @Autowired
    private UserService userService;

    @ApiOperation(value = "上传处方（拍照上传线下处方）")
    @RequestMapping(value = "/upload", method = RequestMethod.POST)
    public CommonResult<Map<String, Object>> upload(@RequestBody Map<String, Object> body) {
        User user = userService.getInfoException();
        String images = str(body.get("images"));
        Prescription rx = prescriptionService.submitUpload(
                user.getUid(),
                str(body.get("patientName")),
                str(body.get("idcard")),
                images,
                str(body.get("diagnosis")));
        return CommonResult.success(brief(rx));
    }

    @ApiOperation(value = "发起在线问诊（跳转合作互联网医院）")
    @RequestMapping(value = "/consult", method = RequestMethod.POST)
    public CommonResult<Map<String, Object>> consult(@RequestBody Map<String, Object> body) {
        User user = userService.getInfoException();
        Map<String, Object> result = prescriptionService.createConsult(
                user.getUid(),
                str(body.get("patientName")),
                str(body.get("idcard")),
                str(body.get("extra")));
        return CommonResult.success(result);
    }

    @ApiOperation(value = "我的处方列表")
    @RequestMapping(value = "/list", method = RequestMethod.GET)
    public CommonResult<List<Map<String, Object>>> list(
            @RequestParam(required = false) Integer auditStatus) {
        User user = userService.getInfoException();
        List<Map<String, Object>> list = prescriptionService.listByUid(user.getUid(), auditStatus)
                .stream().map(this::brief).collect(Collectors.toList());
        return CommonResult.success(list);
    }

    @ApiOperation(value = "处方详情")
    @RequestMapping(value = "/detail/{id}", method = RequestMethod.GET)
    public CommonResult<Map<String, Object>> detail(@PathVariable Integer id) {
        User user = userService.getInfoException();
        Prescription rx = prescriptionService.getById(id);
        // 越权防护：只能看自己的处方
        if (rx == null || Boolean.TRUE.equals(rx.getIsDel()) || !user.getUid().equals(rx.getUid())) {
            throw new CrmebException("处方不存在或无权访问");
        }
        Map<String, Object> m = brief(rx);
        m.put("images", rx.getImages());
        m.put("auditRemark", rx.getAuditRemark());
        m.put("doctorName", rx.getDoctorName());
        m.put("doctorHospital", rx.getDoctorHospital());
        m.put("validEnd", rx.getValidEnd());
        return CommonResult.success(m);
    }

    @ApiOperation(value = "校验这批商品是否都已有有效处方覆盖")
    @RequestMapping(value = "/check", method = RequestMethod.POST)
    public CommonResult<Map<String, Object>> check(@RequestBody Map<String, Object> body) {
        User user = userService.getInfoException();
        List<Integer> productIds = parseIntList(str(body.get("productIds")));
        List<Integer> missing = prescriptionService.checkRxProductsCovered(user.getUid(), productIds);
        Map<String, Object> result = new HashMap<>();
        result.put("passed", missing.isEmpty());
        result.put("missingProductIds", missing);
        return CommonResult.success(result);
    }

    @ApiOperation(value = "合作平台回调入口")
    @RequestMapping(value = "/callback/{provider}", method = RequestMethod.POST)
    public String callback(@PathVariable String provider,
                           javax.servlet.http.HttpServletRequest request,
                           @RequestBody String rawBody) {
        try {
            return prescriptionService.handleCallback(provider, request, rawBody) ? "success" : "fail";
        } catch (Exception e) {
            log.error("[Prescription] 回调入口异常 provider={}", provider, e);
            return "fail";
        }
    }

    // ---------- 工具 ----------

    /** 对外只暴露必要字段，身份证号绝不返回 */
    private Map<String, Object> brief(Prescription rx) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", rx.getId());
        m.put("rxNo", rx.getRxNo());
        m.put("source", rx.getSource());
        m.put("auditStatus", rx.getAuditStatus());
        m.put("auditStatusDesc", auditDesc(rx.getAuditStatus()));
        m.put("patientName", rx.getPatientName());
        m.put("diagnosis", rx.getDiagnosis());
        m.put("createTime", rx.getCreateTime());
        m.put("validEnd", rx.getValidEnd());
        return m;
    }

    private static String auditDesc(Integer s) {
        if (s == null) {
            return "未知";
        }
        switch (s) {
            case 0: return "待药师审核";
            case 1: return "审核通过";
            case 2: return "审核驳回";
            default: return "未知";
        }
    }

    private static String str(Object o) {
        return o == null ? "" : String.valueOf(o);
    }

    private static List<Integer> parseIntList(String csv) {
        if (csv == null || csv.trim().isEmpty()) {
            return java.util.Collections.emptyList();
        }
        return Arrays.stream(csv.split(","))
                .map(String::trim).filter(s -> !s.isEmpty())
                .map(Integer::valueOf).collect(Collectors.toList());
    }
}
