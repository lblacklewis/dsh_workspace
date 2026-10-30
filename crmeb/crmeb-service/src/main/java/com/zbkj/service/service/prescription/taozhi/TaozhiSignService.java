package com.zbkj.service.service.prescription.taozhi;

import com.zbkj.common.exception.CrmebException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;
import java.util.TreeMap;

/**
 * 桃子（100CBC）云处方 —— v2.1 签名
 *
 * 规则（文档「2.接口协议 / 鉴权方式」原始描述）：
 *
 *   1. 拼接字符串
 *      如：secretKey值 + bizID + "bizID值" + clientID + "clientID值" + timestamp + "timestamp值"
 *   2. 对以上字符串进行 MD5 加密然后转小写作为 sign 值
 *   3. 所有接口通过请求体中的 sign 字段鉴权，header 中添加 version=v2.1
 *
 * 从文档的 Java 示例代码可确认拼接的确切顺序（注意**字段名也参与拼接**）：
 *
 *   String signStr = secretKey + "bizID" + bizID + "clientID" + clientID + "timestamp" + timestamp_s;
 *
 * ⚠️ 三个必须知道的注意点（都是实测/读文档得出的，不要凭感觉改）：
 *
 *  1. **文档只明确了「用 bizID+clientID+timestamp」这一种拼接顺序。**
 *     但 3.5(auditResult) / 3.6(getChatRecord) / 3.7(getResult) 的请求字段更多
 *     （例如 3.5 还有 rpID、auditStatus、outPharmacistID），
 *     文档**没有说明**这些接口的 sign 是否也要把它们的字段拼进去、按什么顺序拼。
 *     所以这里把「参与签名的字段顺序」做成可配置（{@link #signWithOrder}），
 *     默认用文档写明的那一套；拿到对方确认后只改配置，不用改调用方代码。
 *
 *  2. **文档里的示例 secretKey 与示例 clientID 对不上。**
 *     我拿文档第 14 页的 sign=fbcd8f37a2e0bbcd3e949c615dec1a07 反推过：
 *     用文档给的 secretKey=6927HsL30B9r132A2ZFvEFu15k8bi9
 *     配合 bizID/clientID/timestamp 按 6 种常见拼法都算不出该值
 *     （脚本见 docs/verify-taozhi-sign.js）。
 *     说明文档里的 secretKey 只是「格式示例」，示例 JSON 里的 clientID 是别的租户。
 *     **结论：签名无法离线自验，必须等对方给正式凭证后在沙箱验证。**
 *
 *  3. **MD5 强度弱**，但这是对方既定协议，只能照做。
 *     我方对外提供的回调接口不沿用这套（见 TaozhiCallbackSignVerifier 的说明）。
 */
@Slf4j
@Component
public class TaozhiSignService {

    /** 协议版本，必须放在请求 header 里 */
    public static final String VERSION_HEADER = "version";
    public static final String VERSION_VALUE = "v2.1";

    /**
     * 文档明确写明的拼接顺序：secretKey + bizID + clientID + timestamp
     * 元素为 "字段名"，拼接时会在字段名后紧跟该字段的值。
     */
    public static final String[] DEFAULT_ORDER = {"bizID", "clientID", "timestamp"};

    /**
     * 按默认顺序签名（3.1 创建问诊单用这个，文档写明了）
     *
     * @param secretKey 密钥
     * @param params    参数表，key 为文档里的字段名
     */
    public String sign(String secretKey, Map<String, ?> params) {
        return signWithOrder(secretKey, params, DEFAULT_ORDER);
    }

    /**
     * 指定字段顺序签名。
     *
     * 之所以做成可传顺序：文档只写了 3.1 的顺序，其余接口待对方确认，
     * 到时候改这里传的数组即可，不必改调用方。
     *
     * @param order 参与签名的字段名顺序；字段在 params 里不存在时按空串参与
     *              （文档要求"没有值也必须传空字符串"，所以空值同样要拼进去）
     */
    public String signWithOrder(String secretKey, Map<String, ?> params, String[] order) {
        if (secretKey == null || secretKey.isEmpty()) {
            throw new CrmebException("桃子签名失败：secretKey 未配置");
        }
        if (order == null || order.length == 0) {
            throw new CrmebException("桃子签名失败：未指定参与签名的字段顺序");
        }
        StringBuilder sb = new StringBuilder(secretKey);
        for (String field : order) {
            sb.append(field);
            Object v = params == null ? null : params.get(field);
            sb.append(v == null ? "" : String.valueOf(v));
        }
        String raw = sb.toString();
        String sign = md5Lower(raw);
        // 只记前缀，避免密钥/签名进日志；但保留足够信息便于比对拼接是否正确
        if (log.isDebugEnabled()) {
            log.debug("[Taozhi] 待签名串前 40 位={} sign={}",
                    raw.substring(0, Math.min(40, raw.length())), sign);
        }
        return sign;
    }

    /**
     * 校验对方回调的签名。
     *
     * ⚠️ 现状：文档 3.2「事件通知/处方推送」的**请求参数字段列表里没有 sign**，
     * 但正文的 JSON 示例里却有一个 sign 字段 —— 自相矛盾。
     * 在对方明确「回调用哪个 key 签、按什么顺序」之前，
     * 这里**不能假装验签成功**（那等于给伪造处方开门）。
     *
     * 所以策略是：
     *   - 配置了 callbackSecretKey 才做校验，校验不过一律拒绝
     *   - 没配置就**拒绝**并记 ERROR 点名，而不是放行
     *
     * @return true 表示验签通过
     */
    public boolean verifyCallback(String callbackSecretKey, Map<String, ?> params, String sign,
                                  String[] order) {
        if (callbackSecretKey == null || callbackSecretKey.isEmpty()) {
            log.error("[Taozhi] 收到处方回调但没有配置 callbackSecretKey，"
                    + "无法验签，已拒绝。请向对方确认回调签名规则后在 eb_prescription_provider 里配置");
            return false;
        }
        if (sign == null || sign.isEmpty()) {
            log.error("[Taozhi] 收到处方回调但没有 sign 字段，已拒绝");
            return false;
        }
        String expect = signWithOrder(callbackSecretKey, params, order);
        boolean ok = expect.equalsIgnoreCase(sign);
        if (!ok) {
            log.error("[Taozhi] 处方回调验签失败 params={} 期望={} 实际={}", params.keySet(), expect, sign);
        }
        return ok;
    }

    /**
     * 按「全部参数按键名字典序」签名 —— 很多平台用这种，留作备选。
     * 若对方确认用字典序，把 order 传成排好序的字段名即可，无需改本类。
     */
    public String signBySortedKeys(String secretKey, Map<String, ?> params) {
        TreeMap<String, Object> sorted = new TreeMap<>();
        if (params != null) {
            params.forEach((k, v) -> {
                if (v != null) sorted.put(k, v);
            });
        }
        return signWithOrder(secretKey, sorted, sorted.keySet().toArray(new String[0]));
    }

    /** MD5 后转小写十六进制 */
    public static String md5Lower(String s) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] d = md.digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(d.length * 2);
            for (byte b : d) {
                sb.append(Character.forDigit((b >> 4) & 0xF, 16));
                sb.append(Character.forDigit(b & 0xF, 16));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new CrmebException("MD5 计算失败：" + e.getMessage());
        }
    }
}
