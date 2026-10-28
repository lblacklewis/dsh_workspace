package com.zbkj.front.controller;

import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.delivery.DeliveryOrder;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.model.user.User;
import com.zbkj.common.request.DeliveryQuoteRequest;
import com.zbkj.common.result.CommonResult;
import com.zbkj.service.service.DeliveryOrderService;
import com.zbkj.service.service.StoreOrderService;
import com.zbkj.service.service.UserService;
import com.zbkj.service.service.delivery.DeliveryStatus;
import com.zbkj.service.service.delivery.dto.DeliveryCreateRequest;
import com.zbkj.service.service.delivery.dto.DeliveryQuoteResult;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * 同城即时配送（前台）
 *
 * 说明：本模块的接口前缀是 api/front/delivery，对外经 nginx 暴露为 /front-api/api/front/delivery/**
 */
@Slf4j
@RestController
@RequestMapping("api/front/delivery")
@Api(tags = "同城即时配送控制器")
public class DeliveryController {

    @Autowired
    private DeliveryOrderService deliveryOrderService;

    @Autowired
    private UserService userService;

    @Autowired
    private StoreOrderService storeOrderService;

    @ApiOperation(value = "同城配送是否开启")
    @RequestMapping(value = "/enabled", method = RequestMethod.GET)
    public CommonResult<Map<String, Object>> enabled() {
        Map<String, Object> result = new HashMap<>();
        boolean on = deliveryOrderService.isEnabled();
        result.put("enabled", on);
        // 不向前端暴露运力商标识，避免无意义的实现细节泄露
        return CommonResult.success(result);
    }

    @ApiOperation(value = "询价：返回运费与预计送达时间")
    @RequestMapping(value = "/quote", method = RequestMethod.POST)
    public CommonResult<DeliveryQuoteResult> quote(@RequestBody DeliveryQuoteRequest request) {
        DeliveryCreateRequest req = new DeliveryCreateRequest()
                .setToName(request.getToName())
                .setToPhone(request.getToPhone())
                .setToAddress(request.getToAddress())
                .setToLat(request.getToLat())
                .setToLng(request.getToLng())
                .setGoodsCount(request.getGoodsCount() == null ? 1 : request.getGoodsCount());
        // 询价失败不让接口报错，由前端降级提示
        return CommonResult.success(deliveryOrderService.quote(req, request.getProvider()));
    }

    @ApiOperation(value = "查询某订单的配送状态")
    @RequestMapping(value = "/status/{orderId}", method = RequestMethod.GET)
    public CommonResult<Map<String, Object>> status(@PathVariable Integer orderId) {
        // 必须校验订单归属：否则任何人遍历 orderId 就能拿到别人的收货地址和骑手电话。
        // 用 id+uid 一次查询完成校验，避免"先查订单再比对 uid"被绕过。
        User user = userService.getInfoException();
        StoreOrder owned = storeOrderService.getByEntityOne(
                new StoreOrder().setId(orderId).setUid(user.getUid()));
        if (owned == null) {
            throw new CrmebException("订单不存在或无权访问");
        }

        DeliveryOrder order = deliveryOrderService.getByOrderId(orderId);
        if (order == null) {
            throw new CrmebException("该订单没有配送信息");
        }
        // 主动同步一次，避免运力商回调丢失导致状态卡住
        order = deliveryOrderService.syncStatus(orderId);

        Map<String, Object> result = new HashMap<>();
        result.put("orderId", orderId);
        result.put("status", order.getStatus());
        result.put("statusDesc", DeliveryStatus.desc(order.getStatus()));
        result.put("riderName", order.getRiderName());
        result.put("riderPhone", order.getRiderPhone());
        result.put("riderLat", order.getRiderLat());
        result.put("riderLng", order.getRiderLng());
        result.put("estimateMin", order.getEstimateMin());
        result.put("fee", order.getFee());
        result.put("receiverAddress", order.getReceiverAddress());
        result.put("failReason", order.getFailReason());
        return CommonResult.success(result);
    }

    @ApiOperation(value = "运力商回调入口")
    @RequestMapping(value = "/callback/{provider}", method = RequestMethod.POST)
    public String callback(@PathVariable String provider,
                           javax.servlet.http.HttpServletRequest request,
                           @RequestBody String rawBody) {
        // 运力商只认"收到"两个字，任何一层报错都会导致它重推或放弃
        try {
            boolean ok = deliveryOrderService.handleCallback(provider, request, rawBody);
            return ok ? "success" : "fail";
        } catch (Exception e) {
            log.error("[Delivery] 回调入口异常 provider={}", provider, e);
            return "fail";
        }
    }
}
