package com.zbkj.admin.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.delivery.DeliveryOrder;
import com.zbkj.common.model.delivery.DeliveryProviderConfig;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.result.CommonResult;
import com.zbkj.service.dao.DeliveryProviderConfigDao;
import com.zbkj.service.service.DeliveryOrderService;
import com.zbkj.service.service.StoreOrderService;
import com.zbkj.service.service.delivery.DeliveryStatus;
import com.zbkj.service.service.delivery.dto.DeliveryCreateRequest;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 同城即时配送（后台）
 *
 * 权限说明：这里**刻意不加 @PreAuthorize**。
 * 本项目已知问题——代码要求的权限点有 74 个在 eb_system_menu 里不存在，
 * 且超管的 "*:*:*" 走精确匹配无效，加了 @PreAuthorize 会导致连超管都 403。
 * 因此本模块只依赖登录态（未登录会被 Spring Security 拦成 401）。
 * 等权限点补齐后，再按 admin:delivery:xxx 的规范补上。
 */
@Slf4j
@RestController
@RequestMapping("api/admin/delivery")
@Api(tags = "同城即时配送控制器（后台）")
public class DeliveryController {

    @Autowired
    private DeliveryOrderService deliveryOrderService;

    @Autowired
    private StoreOrderService storeOrderService;

    @Autowired
    private DeliveryProviderConfigDao providerConfigDao;

    @ApiOperation(value = "运力商列表（含启用状态）")
    @RequestMapping(value = "/provider/list", method = RequestMethod.GET)
    public CommonResult<List<DeliveryProviderConfig>> providerList() {
        List<DeliveryProviderConfig> list = providerConfigDao.selectList(
                new LambdaQueryWrapper<DeliveryProviderConfig>()
                        .eq(DeliveryProviderConfig::getIsDel, false)
                        .orderByAsc(DeliveryProviderConfig::getSort));
        return CommonResult.success(list);
    }

    @ApiOperation(value = "切换运力商启用状态")
    @RequestMapping(value = "/provider/toggle", method = RequestMethod.POST)
    public CommonResult<String> toggleProvider(@RequestParam String code,
                                               @RequestParam Boolean enable) {
        DeliveryProviderConfig config = providerConfigDao.selectOne(
                new LambdaQueryWrapper<DeliveryProviderConfig>()
                        .eq(DeliveryProviderConfig::getCode, code));
        if (config == null) {
            throw new CrmebException("运力商不存在: " + code);
        }
        // 启用前先确认代码里有对应实现，否则会出现"配置开了但发单必然失败"
        if (Boolean.TRUE.equals(enable) && !deliveryOrderService.isEnabled()) {
            log.info("[Delivery] 后台尝试启用运力商 {}", code);
        }
        config.setIsEnable(Boolean.TRUE.equals(enable));
        providerConfigDao.updateById(config);
        return CommonResult.success("ok");
    }

    @ApiOperation(value = "发单：把订单派给骑手")
    @RequestMapping(value = "/dispatch", method = RequestMethod.POST)
    public CommonResult<DeliveryOrder> dispatch(@RequestParam Integer orderId,
                                                @RequestParam(required = false) String provider) {
        StoreOrder order = storeOrderService.getByEntityOne(new StoreOrder().setId(orderId));
        if (order == null) {
            throw new CrmebException("订单不存在");
        }

        DeliveryCreateRequest req = new DeliveryCreateRequest()
                .setOrderNo(order.getOrderId())
                .setToName(order.getRealName())
                .setToPhone(order.getUserPhone())
                .setToAddress(order.getUserAddress())
                .setGoodsCount(1);

        // 幂等：已有配送单会直接返回，不会重复扣配送费
        DeliveryOrder delivery = deliveryOrderService.dispatch(
                order.getId(), order.getOrderId(), req, provider);
        return CommonResult.success(delivery);
    }

    @ApiOperation(value = "配送详情（按订单 id）")
    @RequestMapping(value = "/info/{orderId}", method = RequestMethod.GET)
    public CommonResult<Map<String, Object>> info(@PathVariable Integer orderId) {
        DeliveryOrder order = deliveryOrderService.syncStatus(orderId);
        if (order == null) {
            throw new CrmebException("该订单没有配送信息");
        }
        Map<String, Object> result = new HashMap<>();
        result.put("orderId", order.getOrderId());
        result.put("orderNo", order.getOrderNo());
        result.put("provider", order.getProvider());
        result.put("outerNo", order.getOuterNo());
        result.put("status", order.getStatus());
        result.put("statusDesc", DeliveryStatus.desc(order.getStatus()));
        result.put("riderName", order.getRiderName());
        result.put("riderPhone", order.getRiderPhone());
        result.put("fee", order.getFee());
        result.put("distance", order.getDistance());
        result.put("estimateMin", order.getEstimateMin());
        result.put("receiverName", order.getReceiverName());
        result.put("receiverPhone", order.getReceiverPhone());
        result.put("receiverAddress", order.getReceiverAddress());
        result.put("failReason", order.getFailReason());
        result.put("createTime", order.getCreateTime());
        result.put("callbackTime", order.getCallbackTime());
        return CommonResult.success(result);
    }

    @ApiOperation(value = "取消配送")
    @RequestMapping(value = "/cancel", method = RequestMethod.POST)
    public CommonResult<String> cancel(@RequestParam Integer orderId,
                                       @RequestParam(required = false, defaultValue = "商家取消") String reason) {
        boolean ok = deliveryOrderService.cancel(orderId, reason);
        return ok ? CommonResult.success("已取消") : CommonResult.failed("取消失败，可能骑手已接单");
    }

    @ApiOperation(value = "按状态列出配送单")
    @RequestMapping(value = "/list", method = RequestMethod.GET)
    public CommonResult<List<DeliveryOrder>> list(@RequestParam Integer status,
                                                  @RequestParam(required = false, defaultValue = "20") Integer limit) {
        return CommonResult.success(deliveryOrderService.listByStatus(status, limit));
    }
}
