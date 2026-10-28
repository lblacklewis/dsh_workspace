package com.zbkj.service.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.delivery.DeliveryCallbackLog;
import com.zbkj.common.model.delivery.DeliveryOrder;
import com.zbkj.common.model.delivery.DeliveryProviderConfig;
import com.zbkj.service.dao.DeliveryCallbackLogDao;
import com.zbkj.service.dao.DeliveryOrderDao;
import com.zbkj.service.dao.DeliveryProviderConfigDao;
import com.zbkj.service.service.DeliveryOrderService;
import com.zbkj.service.service.delivery.DeliveryProvider;
import com.zbkj.service.service.delivery.DeliveryProviderFactory;
import com.zbkj.service.service.delivery.DeliveryStatus;
import com.zbkj.service.service.delivery.dto.DeliveryCallbackData;
import com.zbkj.service.service.delivery.dto.DeliveryCreateRequest;
import com.zbkj.service.service.delivery.dto.DeliveryCreateResult;
import com.zbkj.service.service.delivery.dto.DeliveryQuoteResult;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.servlet.http.HttpServletRequest;
import java.util.Collections;
import java.util.Date;
import java.util.Enumeration;
import java.util.List;

/**
 * 即时配送服务实现
 *
 * 关于分层：配送单是主表，运力商配置和回调日志是它的附属表，
 * 这里直接注入后两者的 Dao，没有再各包一层 ServiceImpl —— 它们的操作都只是简单 CRUD，
 * 多包一层只是增加文件数。如果后续配置管理变复杂（比如要缓存、要校验），再拆出去。
 */
@Slf4j
@Service
public class DeliveryOrderServiceImpl extends ServiceImpl<DeliveryOrderDao, DeliveryOrder>
        implements DeliveryOrderService {

    @Autowired
    private DeliveryProviderFactory providerFactory;

    @Autowired
    private DeliveryProviderConfigDao providerConfigDao;

    @Autowired
    private DeliveryCallbackLogDao callbackLogDao;

    @Override
    public boolean isEnabled() {
        return currentProvider() != null;
    }

    @Override
    public String currentProvider() {
        DeliveryProviderConfig config = providerConfigDao.selectOne(new LambdaQueryWrapper<DeliveryProviderConfig>()
                .eq(DeliveryProviderConfig::getIsEnable, true)
                .eq(DeliveryProviderConfig::getIsDel, false)
                .orderByAsc(DeliveryProviderConfig::getSort)
                .last("limit 1"));
        if (config == null) {
            return null;
        }
        // 配置里写了但代码没实现，属于配置错误，要能立刻发现
        if (!providerFactory.exists(config.getCode())) {
            log.error("[Delivery] 运力商 {} 已启用但代码里没有实现，请检查 eb_delivery_provider 配置", config.getCode());
            return null;
        }
        return config.getCode();
    }

    @Override
    public DeliveryQuoteResult quote(DeliveryCreateRequest req, String provider) {
        String code = provider != null ? provider : currentProvider();
        if (code == null) {
            return new DeliveryQuoteResult().setSuccess(false).setErrMsg("尚未开启同城配送");
        }
        try {
            return providerFactory.get(code).quote(req);
        } catch (Exception e) {
            // 询价失败不应该阻断结算页，返回失败让前端降级为"暂不支持配送"
            log.error("[Delivery] 询价失败 provider={} orderNo={}", code, req.getOrderNo(), e);
            return new DeliveryQuoteResult().setSuccess(false).setErrMsg("询价失败：" + e.getMessage());
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public DeliveryOrder dispatch(Integer orderId, String orderNo, DeliveryCreateRequest req, String provider) {
        // 幂等：同一订单只允许存在一条配送单
        DeliveryOrder exist = getByOrderId(orderId);
        if (exist != null) {
            log.info("[Delivery] 订单 {} 已有配送单 {}，跳过重复发单", orderNo, exist.getOuterNo());
            return exist;
        }

        String code = provider != null ? provider : currentProvider();
        if (code == null) {
            throw new CrmebException("尚未开启同城配送，无法发单");
        }
        DeliveryProvider p = providerFactory.get(code);

        DeliveryOrder order = new DeliveryOrder()
                .setOrderId(orderId)
                .setOrderNo(orderNo)
                .setProvider(code)
                .setOuterNo("")
                .setStatus(DeliveryStatus.PENDING)
                .setFee(java.math.BigDecimal.ZERO)
                .setDistance(0)
                .setEstimateMin(0)
                .setReceiverName(nvl(req.getToName()))
                .setReceiverPhone(nvl(req.getToPhone()))
                .setReceiverAddress(nvl(req.getToAddress()))
                .setFailReason("")
                .setIsDel(false);

        DeliveryCreateResult result;
        try {
            result = p.create(req);
        } catch (Exception e) {
            // 发单异常也要落一条失败记录，否则订单会永远停在"待发单"且无从排查
            log.error("[Delivery] 发单异常 orderNo={} provider={}", orderNo, code, e);
            order.setStatus(DeliveryStatus.FAILED).setFailReason(trim(e.getMessage()));
            save(order);
            return order;
        }

        if (result != null && Boolean.TRUE.equals(result.getSuccess())) {
            order.setOuterNo(nvl(result.getOuterNo()))
                    .setStatus(result.getStatus() == null ? DeliveryStatus.DISPATCHED : result.getStatus())
                    .setRiderName(nvl(result.getRiderName()))
                    .setRiderPhone(nvl(result.getRiderPhone()))
                    .setRiderLat(result.getRiderLat())
                    .setRiderLng(result.getRiderLng());
            if (result.getFee() != null) {
                order.setFee(result.getFee());
            }
        } else {
            order.setStatus(DeliveryStatus.FAILED)
                    .setFailReason(result == null ? "运力商无返回" : trim(result.getErrMsg()));
        }
        save(order);
        return order;
    }

    @Override
    public DeliveryOrder getByOrderId(Integer orderId) {
        return getOne(new LambdaQueryWrapper<DeliveryOrder>()
                .eq(DeliveryOrder::getOrderId, orderId)
                .eq(DeliveryOrder::getIsDel, false)
                .last("limit 1"));
    }

    @Override
    public DeliveryOrder syncStatus(Integer orderId) {
        DeliveryOrder order = getByOrderId(orderId);
        if (order == null || DeliveryStatus.isFinal(order.getStatus())
                || order.getOuterNo() == null || order.getOuterNo().isEmpty()) {
            return order;
        }
        try {
            DeliveryCreateResult r = providerFactory.get(order.getProvider()).query(order.getOuterNo());
            if (r != null && Boolean.TRUE.equals(r.getSuccess()) && r.getStatus() != null) {
                applyResult(order, r);
                updateById(order);
            }
        } catch (Exception e) {
            log.error("[Delivery] 同步状态失败 orderId={} outerNo={}", orderId, order.getOuterNo(), e);
        }
        return order;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public boolean cancel(Integer orderId, String reason) {
        DeliveryOrder order = getByOrderId(orderId);
        if (order == null) {
            throw new CrmebException("配送单不存在");
        }
        if (DeliveryStatus.isFinal(order.getStatus())) {
            throw new CrmebException("配送已结束（" + DeliveryStatus.desc(order.getStatus()) + "），无法取消");
        }
        boolean ok = false;
        if (order.getOuterNo() != null && !order.getOuterNo().isEmpty()) {
            ok = providerFactory.get(order.getProvider()).cancel(order.getOuterNo(), reason);
        }
        if (ok) {
            order.setStatus(DeliveryStatus.CANCELED).setFailReason(trim(reason));
            updateById(order);
        }
        return ok;
    }

    @Override
    public boolean handleCallback(String providerCode, HttpServletRequest request, String rawBody) {
        DeliveryCallbackLog logRow = new DeliveryCallbackLog()
                .setProvider(providerCode)
                .setOuterNo("")
                .setEventType("")
                .setRawBody(trim2(rawBody, 60000))
                .setHeaders(collectHeaders(request))
                .setIsParsed(false)
                .setErrMsg("")
                .setCreateTime(new Date());

        try {
            if (!providerFactory.exists(providerCode)) {
                logRow.setErrMsg("未知运力商: " + providerCode);
                callbackLogDao.insert(logRow);
                return false;
            }
            DeliveryProvider provider = providerFactory.get(providerCode);

            // ⚠️ 验签必须在解析之前，否则任何人都能伪造"已送达"
            if (!provider.verifyCallback(request, rawBody)) {
                logRow.setErrMsg("验签失败");
                callbackLogDao.insert(logRow);
                log.warn("[Delivery] 回调验签失败 provider={}", providerCode);
                return false;
            }

            DeliveryCallbackData data = provider.parseCallback(rawBody);
            if (data == null || data.getOuterNo() == null) {
                logRow.setErrMsg("报文解析失败");
                callbackLogDao.insert(logRow);
                return false;
            }
            logRow.setOuterNo(nvl(data.getOuterNo())).setEventType(nvl(data.getRawStatus()));

            DeliveryOrder order = getOne(new LambdaQueryWrapper<DeliveryOrder>()
                    .eq(DeliveryOrder::getProvider, providerCode)
                    .eq(DeliveryOrder::getOuterNo, data.getOuterNo())
                    .last("limit 1"));
            if (order == null) {
                logRow.setErrMsg("找不到对应配送单 outerNo=" + data.getOuterNo());
                callbackLogDao.insert(logRow);
                return false;
            }

            if (data.getStatus() != null && !DeliveryStatus.isFinal(order.getStatus())) {
                order.setStatus(data.getStatus());
                if (data.getRiderName() != null) {
                    order.setRiderName(data.getRiderName());
                }
                if (data.getRiderPhone() != null) {
                    order.setRiderPhone(data.getRiderPhone());
                }
                if (data.getRiderLat() != null) {
                    order.setRiderLat(data.getRiderLat());
                }
                if (data.getRiderLng() != null) {
                    order.setRiderLng(data.getRiderLng());
                }
                if (data.getReason() != null && !data.getReason().isEmpty()) {
                    order.setFailReason(trim(data.getReason()));
                }
                order.setCallbackTime(new Date());
                updateById(order);
            }

            logRow.setIsParsed(true);
            callbackLogDao.insert(logRow);
            return true;

        } catch (Exception e) {
            log.error("[Delivery] 回调处理异常 provider={}", providerCode, e);
            logRow.setErrMsg(trim2(e.getMessage(), 500));
            try {
                callbackLogDao.insert(logRow);
            } catch (Exception ignore) {
                log.error("[Delivery] 回调日志落库也失败了", ignore);
            }
            return false;
        }
    }

    @Override
    public List<DeliveryOrder> listByStatus(Integer status, Integer limit) {
        if (status == null) {
            return Collections.emptyList();
        }
        return list(new LambdaQueryWrapper<DeliveryOrder>()
                .eq(DeliveryOrder::getStatus, status)
                .eq(DeliveryOrder::getIsDel, false)
                .orderByDesc(DeliveryOrder::getId)
                .last("limit " + (limit == null || limit <= 0 ? 20 : limit)));
    }

    // ---------- 内部工具 ----------

    private void applyResult(DeliveryOrder order, DeliveryCreateResult r) {
        order.setStatus(r.getStatus());
        if (r.getRiderName() != null) {
            order.setRiderName(r.getRiderName());
        }
        if (r.getRiderPhone() != null) {
            order.setRiderPhone(r.getRiderPhone());
        }
        if (r.getRiderLat() != null) {
            order.setRiderLat(r.getRiderLat());
        }
        if (r.getRiderLng() != null) {
            order.setRiderLng(r.getRiderLng());
        }
        order.setCallbackTime(new Date());
    }

    private String collectHeaders(HttpServletRequest request) {
        if (request == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        Enumeration<String> names = request.getHeaderNames();
        while (names != null && names.hasMoreElements()) {
            String n = names.nextElement();
            sb.append(n).append(": ").append(request.getHeader(n)).append("\n");
        }
        return trim2(sb.toString(), 5000);
    }

    private static String nvl(String s) {
        return s == null ? "" : s;
    }

    private static String trim(String s) {
        return trim2(s, 255);
    }

    private static String trim2(String s, int max) {
        if (s == null) {
            return "";
        }
        return s.length() > max ? s.substring(0, max) : s;
    }
}
