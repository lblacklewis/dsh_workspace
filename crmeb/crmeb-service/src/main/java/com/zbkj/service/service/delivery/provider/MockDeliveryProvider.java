package com.zbkj.service.service.delivery.provider;

import com.zbkj.service.service.delivery.DeliveryProvider;
import com.zbkj.service.service.delivery.DeliveryStatus;
import com.zbkj.service.service.delivery.dto.DeliveryCallbackData;
import com.zbkj.service.service.delivery.dto.DeliveryCreateRequest;
import com.zbkj.service.service.delivery.dto.DeliveryCreateResult;
import com.zbkj.service.service.delivery.dto.DeliveryQuoteResult;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import javax.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 本地模拟运力商
 *
 * 用途：在拿到真实运力商账号之前，让前后端可以完整联调
 *      「选同城配送 → 询价 → 发单 → 骑手接单 → 配送中 → 已送达」
 *
 * 行为：
 *   - create 时生成一个 MO 开头的假单号，记录下单时刻
 *   - query  时按经过的秒数推进状态，模拟骑手接单/取货/送达
 *   - verifyCallback 一律放行（仅 mock！真实 provider 必须验签）
 *
 * ⚠️ 生产环境务必在 eb_delivery_provider 里把 mock 的 is_enable 置 0。
 */
@Slf4j
@Component
public class MockDeliveryProvider implements DeliveryProvider {

    /** 假单号自增序号 */
    private static final AtomicInteger SEQ = new AtomicInteger(1000);

    /** 单号 -> 下单时刻(毫秒) */
    private static final Map<String, Long> CREATED_AT = new ConcurrentHashMap<>();

    /** 单号 -> 是否已取消 */
    private static final Map<String, Boolean> CANCELED = new ConcurrentHashMap<>();

    /**
     * 状态推进时间轴（毫秒）：到这里说明进入了对应状态。
     * 刻意做得很快，方便演示；想放慢改这里即可。
     */
    private static final long T_ACCEPTED = 8_000L;
    private static final long T_PICKED = 20_000L;
    private static final long T_DELIVERING = 35_000L;
    private static final long T_FINISHED = 60_000L;

    private static final String[] RIDERS = {"王师傅", "李师傅", "张师傅", "赵师傅"};
    private static final String[] PHONES = {"13800000001", "13800000002", "13800000003", "13800000004"};

    @Override
    public String code() {
        return "mock";
    }

    @Override
    public String name() {
        return "本地模拟（开发用）";
    }

    @Override
    public DeliveryQuoteResult quote(DeliveryCreateRequest req) {
        // 用一个稳定的假距离：优先按经纬度算，没有就给 2 公里
        int distance = 2000;
        if (req.getFromLat() != null && req.getToLat() != null) {
            distance = (int) (haversine(req.getFromLat().doubleValue(), req.getFromLng().doubleValue(),
                    req.getToLat().doubleValue(), req.getToLng().doubleValue()) * 1000);
        }
        // 起步 5 元 + 每公里 1.5 元，向上取整到分
        BigDecimal fee = BigDecimal.valueOf(5.0 + Math.max(0, distance / 1000.0 - 3) * 1.5)
                .setScale(2, BigDecimal.ROUND_HALF_UP);
        // 骑手按 15km/h 算，最少 15 分钟
        int estimate = Math.max(15, (int) Math.ceil(distance / 1000.0 / 15 * 60) + 6);

        return new DeliveryQuoteResult()
                .setSuccess(true)
                .setFee(fee)
                .setDistance(distance)
                .setEstimateMin(estimate);
    }

    @Override
    public DeliveryCreateResult create(DeliveryCreateRequest req) {
        String outerNo = "MO" + System.currentTimeMillis() + SEQ.getAndIncrement();
        CREATED_AT.put(outerNo, System.currentTimeMillis());
        log.info("[MockDelivery] 发单成功 orderNo={} outerNo={} to={} {}", 
                req.getOrderNo(), outerNo, req.getToName(), req.getToAddress());

        return new DeliveryCreateResult()
                .setSuccess(true)
                .setOuterNo(outerNo)
                .setRawStatus("dispatched")
                .setStatus(DeliveryStatus.DISPATCHED)
                .setFee(BigDecimal.ZERO);
    }

    @Override
    public DeliveryCreateResult query(String outerNo) {
        Long start = CREATED_AT.get(outerNo);
        if (start == null) {
            return new DeliveryCreateResult().setSuccess(false)
                    .setOuterNo(outerNo).setErrMsg("mock 单号不存在（服务重启会清空，属正常）");
        }
        if (Boolean.TRUE.equals(CANCELED.get(outerNo))) {
            return new DeliveryCreateResult().setSuccess(true).setOuterNo(outerNo)
                    .setRawStatus("canceled").setStatus(DeliveryStatus.CANCELED);
        }

        long elapsed = System.currentTimeMillis() - start;
        int status;
        String raw;
        if (elapsed < T_ACCEPTED) {
            status = DeliveryStatus.DISPATCHED;   raw = "dispatched";
        } else if (elapsed < T_PICKED) {
            status = DeliveryStatus.ACCEPTED;     raw = "accepted";
        } else if (elapsed < T_DELIVERING) {
            status = DeliveryStatus.PICKED;       raw = "picked";
        } else if (elapsed < T_FINISHED) {
            status = DeliveryStatus.DELIVERING;   raw = "delivering";
        } else {
            status = DeliveryStatus.FINISHED;     raw = "finished";
        }

        DeliveryCreateResult result = new DeliveryCreateResult()
                .setSuccess(true).setOuterNo(outerNo).setRawStatus(raw).setStatus(status);

        // 接单之后带上骑手信息
        if (status >= DeliveryStatus.ACCEPTED) {
            int idx = Math.abs(outerNo.hashCode()) % RIDERS.length;
            result.setRiderName(RIDERS[idx]).setRiderPhone(PHONES[idx]);
            // 骑手位置随便给一个，靠近收货点
            result.setRiderLat(BigDecimal.valueOf(34.341568 + (idx * 0.001)))
                  .setRiderLng(BigDecimal.valueOf(108.940174 + (idx * 0.001)));
        }
        return result;
    }

    @Override
    public boolean cancel(String outerNo, String reason) {
        if (CREATED_AT.get(outerNo) == null) {
            return false;
        }
        CANCELED.put(outerNo, true);
        log.info("[MockDelivery] 取消配送 outerNo={} reason={}", outerNo, reason);
        return true;
    }

    @Override
    public boolean verifyCallback(HttpServletRequest request, String rawBody) {
        // mock 不验签；真实 provider 必须验，否则可被伪造"已送达"
        return true;
    }

    @Override
    public DeliveryCallbackData parseCallback(String rawBody) {
        // mock 的回调格式：{"outerNo":"MO...","status":"finished","reason":""}
        if (rawBody == null || !rawBody.contains("outerNo")) {
            return null;
        }
        DeliveryCallbackData data = new DeliveryCallbackData();
        data.setOuterNo(extract(rawBody, "outerNo"));
        data.setOrderNo(extract(rawBody, "orderNo"));
        data.setReason(extract(rawBody, "reason"));
        String raw = extract(rawBody, "status");
        data.setRawStatus(raw);
        data.setStatus(mapStatus(raw));
        return data;
    }

    // ---------- 内部工具 ----------

    private static Integer mapStatus(String raw) {
        if (raw == null) {
            return null;
        }
        switch (raw) {
            case "dispatched": return DeliveryStatus.DISPATCHED;
            case "accepted":   return DeliveryStatus.ACCEPTED;
            case "picked":     return DeliveryStatus.PICKED;
            case "delivering": return DeliveryStatus.DELIVERING;
            case "finished":   return DeliveryStatus.FINISHED;
            case "canceled":   return DeliveryStatus.CANCELED;
            case "failed":     return DeliveryStatus.FAILED;
            default:           return null;
        }
    }

    /** 极简 JSON 取值，避免为 mock 引入额外依赖 */
    private static String extract(String json, String key) {
        String pattern = "\"" + key + "\"";
        int i = json.indexOf(pattern);
        if (i < 0) {
            return null;
        }
        int colon = json.indexOf(':', i + pattern.length());
        if (colon < 0) {
            return null;
        }
        int start = json.indexOf('"', colon + 1);
        if (start < 0) {
            return null;
        }
        int end = json.indexOf('"', start + 1);
        if (end < 0) {
            return null;
        }
        return json.substring(start + 1, end);
    }

    /** 两点球面距离，单位公里 */
    private static double haversine(double lat1, double lng1, double lat2, double lng2) {
        double r = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
