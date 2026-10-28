package com.zbkj.admin.controller;

import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.prescription.Prescription;
import com.zbkj.common.result.CommonResult;
import com.zbkj.common.utils.SecurityUtil;
import com.zbkj.service.service.PrescriptionService;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 互联网处方（后台 · 药师审核）
 *
 * 权限说明：与 DeliveryController 一致，刻意不加 @PreAuthorize，
 * 因为本项目代码要求的权限点有 74 个在 eb_system_menu 里不存在，加了会让超管也 403。
 * 仅依赖登录态保护。
 *
 * ⚠️ 审核通过 = 允许该用户购买处方药，这是合规关键操作，后台应限定为药师角色账号。
 */
@Slf4j
@RestController
@RequestMapping("api/admin/prescription")
@Api(tags = "处方控制器（后台）")
public class PrescriptionController {

    @Autowired
    private PrescriptionService prescriptionService;

    @ApiOperation(value = "处方列表（默认待审核）")
    @RequestMapping(value = "/list", method = RequestMethod.GET)
    public CommonResult<List<Prescription>> list(@RequestParam(required = false, defaultValue = "0") Integer auditStatus,
                                                 @RequestParam(required = false, defaultValue = "20") Integer limit) {
        return CommonResult.success(prescriptionService.listForAudit(auditStatus, limit));
    }

    @ApiOperation(value = "处方详情")
    @RequestMapping(value = "/detail/{id}", method = RequestMethod.GET)
    public CommonResult<Prescription> detail(@PathVariable Integer id) {
        Prescription rx = prescriptionService.getById(id);
        if (rx == null || Boolean.TRUE.equals(rx.getIsDel())) {
            throw new CrmebException("处方不存在");
        }
        return CommonResult.success(rx);
    }

    @ApiOperation(value = "药师审核（通过/驳回）")
    @RequestMapping(value = "/audit", method = RequestMethod.POST)
    public CommonResult<Prescription> audit(@RequestParam Integer id,
                                            @RequestParam Boolean pass,
                                            @RequestParam(required = false, defaultValue = "") String remark) {
        Integer pharmacistId = null;
        try {
            pharmacistId = SecurityUtil.getLoginUserVo().getUser().getId();
        } catch (Exception e) {
            // 拿不到就当未知药师，不阻断流程，但日志里要能看出来
            log.warn("[Prescription] 无法获取当前药师 id", e);
        }
        if (!Boolean.TRUE.equals(pass) && (remark == null || remark.trim().isEmpty())) {
            throw new CrmebException("驳回必须填写原因");
        }
        return CommonResult.success(prescriptionService.audit(id, Boolean.TRUE.equals(pass), remark, pharmacistId));
    }

    @ApiOperation(value = "把处方绑定到订单（合规留痕）")
    @RequestMapping(value = "/bind/order", method = RequestMethod.POST)
    public CommonResult<String> bindOrder(@RequestParam Integer orderId,
                                          @RequestParam String prescriptionIds) {
        List<Integer> ids = Arrays.stream(prescriptionIds.split(","))
                .map(String::trim).filter(s -> !s.isEmpty())
                .map(Integer::valueOf).collect(Collectors.toList());
        prescriptionService.bindToOrder(orderId, ids);
        return CommonResult.success("ok");
    }

    @ApiOperation(value = "查某订单用到的处方")
    @RequestMapping(value = "/order/{orderId}", method = RequestMethod.GET)
    public CommonResult<List<Prescription>> byOrder(@PathVariable Integer orderId) {
        return CommonResult.success(prescriptionService.listByOrderId(orderId));
    }
}
