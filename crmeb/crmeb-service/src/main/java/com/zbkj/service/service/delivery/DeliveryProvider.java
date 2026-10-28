package com.zbkj.service.service.delivery;

import com.zbkj.service.service.delivery.dto.DeliveryCallbackData;
import com.zbkj.service.service.delivery.dto.DeliveryCreateRequest;
import com.zbkj.service.service.delivery.dto.DeliveryCreateResult;
import com.zbkj.service.service.delivery.dto.DeliveryQuoteResult;

import javax.servlet.http.HttpServletRequest;

/**
 * 配送运力商适配器
 *
 * 新增一家运力商 = 新增一个实现类 + 在 eb_delivery_provider 插一行配置，
 * 业务代码（结算页、发单、订单详情）完全不用改。
 *
 * 实现类需标注 @Component，Factory 会按 code() 自动注册。
 */
public interface DeliveryProvider {

    /**
     * 运力商标识，必须与 eb_delivery_provider.code 一致
     */
    String code();

    /**
     * 运力商展示名
     */
    String name();

    /**
     * 询价：结算页展示运费和预计送达时间
     *
     * @param req 取货/收货信息
     * @return 询价结果，失败时 success=false 且带 errMsg（不要抛异常，结算页要能容错降级）
     */
    DeliveryQuoteResult quote(DeliveryCreateRequest req);

    /**
     * 发单：支付成功后调用
     *
     * 必须幂等：同一 orderNo 重复调用应返回同一 outerNo，不能重复下单。
     * @param req 取货/收货信息
     * @return 发单结果，失败时 success=false 且带 errMsg
     */
    DeliveryCreateResult create(DeliveryCreateRequest req);

    /**
     * 查询配送状态（回调丢失时的补偿手段）
     *
     * @param outerNo 运力商订单号
     */
    DeliveryCreateResult query(String outerNo);

    /**
     * 取消配送（仅未接单时可取消，各家规则不同）
     *
     * @param outerNo 运力商订单号
     * @param reason  取消原因
     */
    boolean cancel(String outerNo, String reason);

    /**
     * 回调验签
     *
     * ⚠️ 必须实现，否则任何人都能伪造"已送达"回调。
     * 各家用签名算法不同（MD5/HMAC-SHA256/微信平台证书），
     * 拿不到配置无法验签时应返回 false 并记日志，不要放行。
     */
    boolean verifyCallback(HttpServletRequest request, String rawBody);

    /**
     * 解析回调报文
     *
     * @param rawBody 原始报文
     * @return 解析结果，格式不认识时返回 null
     */
    DeliveryCallbackData parseCallback(String rawBody);
}
