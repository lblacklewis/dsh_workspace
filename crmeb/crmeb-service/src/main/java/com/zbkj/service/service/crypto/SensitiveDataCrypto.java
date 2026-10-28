package com.zbkj.service.service.crypto;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * 敏感信息加解密（目前用于处方患者身份证号）。
 *
 * 合规背景：身份证号属于个人敏感信息，落库不能是明文。
 *
 * 设计取舍：
 * - 用 AES/GCM 而不是 CBC：GCM 自带完整性校验，密文被篡改会解密失败而不是
 *   悄悄解出一串错误明文。
 * - 存储格式带 "enc:" 前缀 + Base64(iv(12) || ciphertext || tag)。
 *   前缀的作用是兼容历史明文数据 —— 读取时看到前缀才解密，没有前缀按明文处理，
 *   这样不需要一次性刷库，老数据也能继续用。
 * - 密钥从配置读（storapp.crypto.key）。**上线前必须替换成真实密钥并妥善保管**：
 *   密钥丢了已加密的身份证号就永久无法恢复。
 *
 * 未做的事（有意留在文档里而不是悄悄忽略）：
 * - 没有接 KMS。生产环境建议把密钥托管到 KMS，并支持轮换。
 *   当前实现预留了这一点：换密钥只需重新加密存量数据，格式不变。
 */
@Component
public class SensitiveDataCrypto {

    private static final Logger logger = LoggerFactory.getLogger(SensitiveDataCrypto.class);

    /** 密文前缀，用于区分历史明文 */
    public static final String PREFIX = "enc:";

    private static final String ALGO = "AES";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int IV_LENGTH = 12;
    private static final int TAG_BITS = 128;

    @Value("${storapp.crypto.key:}")
    private String configuredKey;

    private SecretKeySpec keySpec;
    private boolean usingDevKey = false;

    @PostConstruct
    public void init() {
        String key = configuredKey == null ? "" : configuredKey.trim();
        if (key.isEmpty()) {
            // 没有配置时用开发默认值，保证本地能跑；但必须大声警告。
            key = "storapp-dev-only-key-please-replace";
            usingDevKey = true;
            logger.warn("SensitiveDataCrypto: 未配置 storapp.crypto.key，正在使用开发默认密钥。"
                    + "**上线前必须配置真实密钥**，否则身份证号加密形同虚设");
        }
        byte[] raw = key.getBytes(StandardCharsets.UTF_8);
        // AES-128 需要 16 字节，用 SHA-256 派生，避免密钥长度不合规直接启动失败
        byte[] derived;
        try {
            derived = java.security.MessageDigest.getInstance("SHA-256").digest(raw);
        } catch (Exception e) {
            throw new IllegalStateException("SensitiveDataCrypto: 密钥派生失败", e);
        }
        this.keySpec = new SecretKeySpec(java.util.Arrays.copyOf(derived, 16), ALGO);
    }

    public boolean isUsingDevKey() {
        return usingDevKey;
    }

    /**
     * 加密。空值原样返回（不写 enc: 前缀，避免把 null 变成一个看似有效的密文）。
     * 已加密的值不重复加密。
     */
    public String encrypt(String plain) {
        if (plain == null || plain.isEmpty()) {
            return plain;
        }
        if (plain.startsWith(PREFIX)) {
            return plain;
        }
        try {
            byte[] iv = new byte[IV_LENGTH];
            new SecureRandom().nextBytes(iv);
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, new GCMParameterSpec(TAG_BITS, iv));
            byte[] ct = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));

            byte[] out = new byte[iv.length + ct.length];
            System.arraycopy(iv, 0, out, 0, iv.length);
            System.arraycopy(ct, 0, out, iv.length, ct.length);
            return PREFIX + Base64.getEncoder().encodeToString(out);
        } catch (Exception e) {
            // 加密失败绝不能写明文进库 —— 宁可让这次请求失败
            throw new IllegalStateException("敏感信息加密失败", e);
        }
    }

    /**
     * 解密。没有 enc: 前缀的按历史明文原样返回（迁移期兼容）。
     * 有前缀但解不开（换过密钥、数据被篡改）返回 null 并记日志，不抛异常 ——
     * 一条坏数据不该让整个列表接口挂掉。
     */
    public String decrypt(String stored) {
        if (stored == null || stored.isEmpty()) {
            return stored;
        }
        if (!stored.startsWith(PREFIX)) {
            return stored;
        }
        try {
            byte[] all = Base64.getDecoder().decode(stored.substring(PREFIX.length()));
            byte[] iv = java.util.Arrays.copyOfRange(all, 0, IV_LENGTH);
            byte[] ct = java.util.Arrays.copyOfRange(all, IV_LENGTH, all.length);
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, keySpec, new GCMParameterSpec(TAG_BITS, iv));
            return new String(cipher.doFinal(ct), StandardCharsets.UTF_8);
        } catch (Exception e) {
            logger.error("敏感信息解密失败（可能更换过密钥或数据被破坏）", e);
            return null;
        }
    }

    /**
     * 身份证号脱敏：保留前 6 位（地址码）和后 4 位，中间打码。
     * 管理端展示用这个，不要展示明文。
     */
    public String maskIdcard(String idcard) {
        if (idcard == null || idcard.isEmpty()) {
            return idcard;
        }
        String v = idcard.trim();
        if (v.length() <= 10) {
            return "****";
        }
        return v.substring(0, 6) + "********" + v.substring(v.length() - 4);
    }

    /** 是否长得像身份证号（15 或 18 位），用于写入前的基本校验 */
    public boolean looksLikeIdcard(String idcard) {
        if (idcard == null) {
            return false;
        }
        String v = idcard.trim();
        return v.matches("^\\d{15}$") || v.matches("^\\d{17}[\\dXx]$");
    }
}
