package com.zbkj.service.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.zbkj.common.model.delivery.DeliveryOrder;
import com.zbkj.service.service.delivery.dto.DeliveryCreateRequest;
import com.zbkj.service.service.delivery.dto.DeliveryQuoteResult;

import javax.servlet.http.HttpServletRequest;
import java.util.List;

/**
 * 即时配送服务
 */
public interface DeliveryOrderService extends IService<DeliveryOrder> {

    /**
     * 询价：结算页用，返回运费和预计送达时间
     *
     * @param req      取货/收货信息
     * @param provider 运力商 code，传 null 用当前启用的
     */
    DeliveryQuoteResult quote(DeliveryCreateRequest req, String provider);

    /**
     * 当前是否开启了同城即时配送（前台据此决定要不要显示这个选项）
     */
    boolean isEnabled();

    /**
     * 当前启用的运力商 code
     */
    String currentProvider();

    /**
     * 发单：支付成功后调用
     *
     * 幂等：同一 orderId 已存在配送单时直接返回，不重复下单。
     */
    DeliveryOrder dispatch(Integer orderId, String orderNo, DeliveryCreateRequest req, String provider);

    /**
     * 按订单 id 取配送单
     */
    DeliveryOrder getByOrderId(Integer orderId);

    /**
     * 主动同步一次状态（回调丢失时的补偿，也可给订单详情页轮询用）
     */
    DeliveryOrder syncStatus(Integer orderId);

    /**
     * 取消配送
     */
    boolean cancel(Integer orderId, String reason);

    /**
     * 处理运力商回调
     *
     * 无论验签/解析成功与否都会写 eb_delivery_callback_log。
     * @return 是否处理成功
     */
    boolean handleCallback(String providerCode, HttpServletRequest request, String rawBody);

    /**
     * 已启用的运力商列表（后台下拉用）
     */
    List<DeliveryOrder> listByStatus(Integer status, Integer limit);

    /**
     * **代码里真正实现了**的运力商 code 集合。
     *
     * 与 eb_delivery_provider 的配置不是一回事：配置表可以写 5 家，
     * 但代码里可能只实现 1 家。后台必须能区分这两者，否则会出现
     * 「配置显示已启用、发单却必然失败」的静默故障。
     */
    java.util.Set<String> implementedProviderCodes();

    /**
     * 配置校验（启动时和后台列表接口都会调）：把「配置了但代码没实现」的运力商记成错误日志。
     *
     * @return 有问题的运力商 code（已启用但未实现）
     */
    java.util.List<String> auditProviderConfig();
}
