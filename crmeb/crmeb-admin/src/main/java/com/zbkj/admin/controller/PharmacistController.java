package com.zbkj.admin.controller;

import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.pharmacist.Pharmacist;
import com.zbkj.common.result.CommonResult;
import com.zbkj.service.service.PharmacistService;
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

import java.util.List;

/**
 * 执业药师档案（后台）
 *
 * 为什么需要这个模块：
 *   《处方药网络零售合规指南》（药监综药管函〔2026〕282号）
 *     第八条     —— 配备执业药师，并在主页面显著位置**持续公示**其资格认定信息
 *     第二十二条 —— 处方审核**必须由本企业执业药师开展**，不得由其他岗位人员或人工智能代劳
 *   同时对接桃子云处方的 3.5 接口要回传 `outPharmacistID`，需要有药师实体。
 *
 * 权限说明：与 DeliveryController / PrescriptionController 一致，
 * **刻意不加 @PreAuthorize** —— 本项目代码要求的权限点在 eb_system_menu 里存在缺口，
 * 加了会导致连超管都 403。仅依赖登录态保护。
 *
 * ⚠️ 但要明白：**这个接口能决定"谁有资格审方"**，属于合规关键操作。
 *    上线前应把权限点补齐（admin:pharmacist:*）并限定为质量负责人角色，不要长期裸奔。
 */
@Slf4j
@RestController
@RequestMapping("api/admin/pharmacist")
@Api(tags = "执业药师档案控制器（后台）")
public class PharmacistController {

    @Autowired
    private PharmacistService pharmacistService;

    @ApiOperation(value = "药师档案列表")
    @RequestMapping(value = "/list", method = RequestMethod.GET)
    public CommonResult<List<Pharmacist>> list(
            @RequestParam(required = false, defaultValue = "false") Boolean onlyValid) {
        return CommonResult.success(mask(pharmacistService.listAll(Boolean.TRUE.equals(onlyValid))));
    }

    @ApiOperation(value = "药师档案详情")
    @RequestMapping(value = "/detail/{id}", method = RequestMethod.GET)
    public CommonResult<Pharmacist> detail(@PathVariable Integer id) {
        Pharmacist p = pharmacistService.getById(id);
        if (p == null || Boolean.TRUE.equals(p.getIsDel())) {
            throw new CrmebException("药师档案不存在");
        }
        return CommonResult.success(maskOne(p));
    }

    @ApiOperation(value = "新增药师档案")
    @RequestMapping(value = "/create", method = RequestMethod.POST)
    public CommonResult<Pharmacist> create(@RequestBody Pharmacist p) {
        // id 由库生成，防止前端塞 id 造成覆盖
        p.setId(null);
        return CommonResult.success(maskOne(pharmacistService.create(p)));
    }

    @ApiOperation(value = "更新药师档案")
    @RequestMapping(value = "/update", method = RequestMethod.POST)
    public CommonResult<Pharmacist> update(@RequestBody Pharmacist p) {
        if (p.getId() == null) {
            throw new CrmebException("更新必须带 id");
        }
        return CommonResult.success(maskOne(pharmacistService.update(p)));
    }

    @ApiOperation(value = "停用/启用审方权限")
    @RequestMapping(value = "/toggle/review", method = RequestMethod.POST)
    public CommonResult<Pharmacist> toggleReview(@RequestParam Integer id,
                                                 @RequestParam Boolean enabled) {
        Pharmacist p = new Pharmacist().setId(id).setReviewEnabled(Boolean.TRUE.equals(enabled));
        // 关闭审方权限时，公示必须一起关 —— 否则会公示一个不能审方的人，误导用户
        if (!Boolean.TRUE.equals(enabled)) {
            p.setIsPublic(false);
        }
        return CommonResult.success(maskOne(pharmacistService.update(p)));
    }

    @ApiOperation(value = "停用/启用前台公示")
    @RequestMapping(value = "/toggle/public", method = RequestMethod.POST)
    public CommonResult<Pharmacist> togglePublic(@RequestParam Integer id,
                                                 @RequestParam Boolean enabled) {
        // 公示的前提是这个人能审方，service 里有校验
        Pharmacist p = new Pharmacist().setId(id).setIsPublic(Boolean.TRUE.equals(enabled));
        return CommonResult.success(maskOne(pharmacistService.update(p)));
    }

    @ApiOperation(value = "只读：当前是否有可审方药师（上线前自检用）")
    @RequestMapping(value = "/has/reviewer", method = RequestMethod.GET)
    public CommonResult<String> hasReviewer() {
        Pharmacist p = pharmacistService.pickReviewer();
        if (p == null) {
            return CommonResult.success("无。上线前必须录入至少 1 名可审方的执业药师"
                    + "（《处方药网络零售合规指南》第二十二条）");
        }
        return CommonResult.success("有：" + p.getName() + "（资格证号 " + p.getCertNo() + "）");
    }

    @ApiOperation(value = "只读：校验某个 id 当前能否审方（联调自检用）")
    @RequestMapping(value = "/can/review", method = RequestMethod.GET)
    public CommonResult<String> canReview(@RequestParam Integer pharmacistId) {
        // 不抛异常，只回文字，方便在联调时直接看清"为什么不能审"
        if (pharmacistService.canReview(pharmacistId)) {
            return CommonResult.success("可以审方");
        }
        return CommonResult.success("不可审方：可能已离职、无审方权限、注册单位为空或注册有效期已过");
    }

    // ---------- 脱敏 ----------

    /**
     * 身份证号脱敏后才返回给前端。
     *
     * 后端接口返回明文身份证没有正当理由；列表页更不该带。
     * 需要看完整证号属于极少数场景，应由专门接口 + 权限 + 日志留痕来做，不要图省事。
     */
    private List<Pharmacist> mask(List<Pharmacist> list) {
        if (list != null) {
            list.forEach(this::maskOne);
        }
        return list;
    }

    private Pharmacist maskOne(Pharmacist p) {
        if (p == null) {
            return null;
        }
        String id = p.getIdcard();
        if (id != null && !id.isEmpty()) {
            // 密文（enc: 前缀）不参与脱敏展示，直接抹掉，避免把密文当明文切
            if (id.startsWith("enc:")) {
                p.setIdcard("已加密");
            } else if (id.length() >= 10) {
                p.setIdcard(id.substring(0, 4) + "**********" + id.substring(id.length() - 4));
            }
        }
        return p;
    }
}
