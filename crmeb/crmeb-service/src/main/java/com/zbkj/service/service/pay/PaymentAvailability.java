package com.zbkj.service.service.pay;

import com.zbkj.service.service.SystemConfigService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.regex.Pattern;

/**
 * 支付方式可用性判定
 *
 * 背景：CRMEB 判断"某支付方式可用"时只看开关值（pay_weixin_open == "1"），
 * 完全不校验凭证是否真的配了。本项目初始化时凭证被填成了占位值（111 / 111111），
 * 开关却是打开的 —— 结果前端把「微信支付」「支付宝」当成可用选项展示给用户，
 * 用户点下去必然失败。
 *
 * 这里统一收口：**开关打开 且 凭证是真实值** 才算可用。
 * 前端据此隐藏不可用的支付方式，后端 checkPayType 据此拦截，两边一致。
 *
 * 这样一来，将来填好真实凭证后开关自然生效，不需要改代码。
 */
@Slf4j
@Component
public class PaymentAvailability {

    /** 微信支付凭证 */
    private static final String KEY_WX_APPID = "pay_weixin_appid";
    private static final String KEY_WX_MCHID = "pay_weixin_mchid";
    private static final String KEY_WX_KEY = "pay_weixin_key";
    /** 支付宝凭证 */
    private static final String KEY_ALI_APPID = "ali_pay_appid";
    private static final String KEY_ALI_PRIVATE_KEY = "ali_pay_private_key";
    /** 开关 */
    private static final String KEY_WX_OPEN = "pay_weixin_open";
    private static final String KEY_ALI_STATUS = "ali_pay_status";
    private static final String KEY_YUE_STATUS = "yue_pay_status";

    /** 纯占位：全是同一个字符，或明显是测试词 */
    private static final Pattern PLACEHOLDER = Pattern.compile("^(\\d)\\1*$");
    private static final String[] FAKE_WORDS = {"test", "xxxx", "todo", "null", "none", "1111old"};

    /** 这些凭证最短也要这么长：微信 appid 18 位、mchid 10 位、key 32 位，支付宝更长 */
    private static final int MIN_CREDENTIAL_LENGTH = 8;

    @Autowired
    private SystemConfigService systemConfigService;

    /** 微信支付是否真正可用 */
    public boolean wechatPayAvailable() {
        if (!isOn(KEY_WX_OPEN)) {
            return false;
        }
        return isRealCredential(KEY_WX_APPID)
                && isRealCredential(KEY_WX_MCHID)
                && isRealCredential(KEY_WX_KEY);
    }

    /** 支付宝是否真正可用 */
    public boolean aliPayAvailable() {
        if (!isOn(KEY_ALI_STATUS)) {
            return false;
        }
        return isRealCredential(KEY_ALI_APPID) && isRealCredential(KEY_ALI_PRIVATE_KEY);
    }

    /** 余额支付：只依赖开关，不依赖外部凭证 */
    public boolean yuePayAvailable() {
        return isOn(KEY_YUE_STATUS);
    }

    /**
     * 判断一个凭证值是不是"真的"。
     * 宁可漏判（把占位值当真的）也不要误判真实凭证为假 —— 所以规则是保守的：
     * 只有明确像占位符的才判为假。
     */
    private boolean isRealCredential(String key) {
        String v = config(key);
        if (v == null) {
            return false;
        }
        v = v.trim();
        if (v.isEmpty()) {
            return false;
        }
        if (v.length() < MIN_CREDENTIAL_LENGTH) {
            return false;
        }
        if (PLACEHOLDER.matcher(v).matches()) {
            return false;
        }
        String lower = v.toLowerCase();
        for (String w : FAKE_WORDS) {
            if (lower.equals(w) || lower.contains(w)) {
                return false;
            }
        }
        return true;
    }

    private boolean isOn(String key) {
        String v = config(key);
        if (v == null) {
            return false;
        }
        v = v.trim();
        // ⚠️ CRMEB 把开关值**连引号一起**存进 DB：eb_system_config.value 实际是 `'1'`（3 个字符），
        // 官方常量 Constants.CONFIG_FORM_SWITCH_OPEN 本身就是 "'1'"。
        // 这里两种写法都认，否则会出现"配置明明是开的却判定为关"这种极难排查的问题。
        return "1".equals(v) || "'1'".equals(v);
    }

    private String config(String key) {
        try {
            return systemConfigService.getValueByKey(key);
        } catch (Exception e) {
            // 配置读取失败时按"不可用"处理，宁可少展示一个支付方式，也不要让用户点了报错
            log.warn("[PaymentAvailability] 读取配置 {} 失败", key, e);
            return null;
        }
    }

    /**
     * 启动/诊断用：把当前判定结果打出来，配置问题时一眼能看到。
     */
    public String describe() {
        return String.format("微信支付=%s 支付宝=%s 余额=%s ｜ 开关原始值: wx_open=[%s] ali_status=[%s] yue_status=[%s]",
                wechatPayAvailable() ? "可用" : "不可用(开关未开或凭证未配置)",
                aliPayAvailable() ? "可用" : "不可用(开关未开或凭证未配置)",
                yuePayAvailable() ? "可用" : "不可用",
                config(KEY_WX_OPEN), config(KEY_ALI_STATUS), config(KEY_YUE_STATUS));
    }

    /**
     * 启动时把真实可用状态打进日志。
     * 配置出问题时（开关开着但凭证是占位值）不用翻代码就能一眼看出来。
     */
    @javax.annotation.PostConstruct
    public void logOnStartup() {
        try {
            log.info("[PaymentAvailability] 启动检查: {}", describe());
        } catch (Exception e) {
            // 启动期配置可能还没就绪，这里绝不能因为打日志失败而影响启动
            log.warn("[PaymentAvailability] 启动检查失败（不影响启动）", e);
        }
    }
}
