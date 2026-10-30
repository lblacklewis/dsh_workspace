package com.zbkj.common.model.prescription;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

import java.io.Serializable;
import java.util.Date;

/**
 * 处方平台配置
 *
 * 对接桃子（100CBC）云处方用。
 * 原来 {@code PrescriptionServiceImpl.currentProvider()} 硬编码
 * {@code providerFactory.get("mock")}，接入真实平台后改成从本表读
 * （与 {@code DeliveryOrderServiceImpl.currentProvider()} 同构 —— 那边踩过
 * 「配置启用了一堆但代码只实现一个，停掉唯一能用的那个就全挂」的坑，这里沿用同一套防护）。
 *
 * ⚠️ secret_key 是敏感凭证，库里存 **AES-GCM 密文**（enc: 前缀），
 *    与 patient_idcard / pharmacist.idcard 用同一套 {@code SensitiveDataCrypto}。
 *    **禁止明文入库、禁止写进代码或文档。**
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@TableName("eb_prescription_provider")
@ApiModel(value = "PrescriptionProviderConfig对象", description = "处方平台配置")
public class PrescriptionProviderConfig implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "主键")
    @TableId(value = "id", type = IdType.AUTO)
    private Integer id;

    @ApiModelProperty(value = "平台 code：mock/taozhi/...")
    private String code;

    @ApiModelProperty(value = "平台名称")
    private String name;

    @ApiModelProperty(value = "平台分配的 clientID")
    private String clientId;

    @ApiModelProperty(value = "签名密钥（AES-GCM 加密，enc: 前缀）")
    private String secretKey;

    @ApiModelProperty(value = "bizID 前缀（如需要）")
    private String bizIdPrefix;

    @ApiModelProperty(value = "接口域名（生产）")
    private String apiBase;

    @ApiModelProperty(value = "接口域名（测试）")
    private String apiBaseTest;

    @ApiModelProperty(value = "1用测试域名 0用生产域名")
    private Boolean testMode;

    @ApiModelProperty(value = "3.2 事件推送回调地址")
    private String callbackUrl;

    @ApiModelProperty(value = "问诊结束回跳地址(redirectUrl)")
    private String redirectUrl;

    @ApiModelProperty(value = "3.4 待审核处方接收地址")
    private String auditUrl;

    @ApiModelProperty(value = "是否启用")
    private Boolean isEnable;

    @ApiModelProperty(value = "排序")
    private Integer sort;

    @ApiModelProperty(value = "备注")
    private String remark;

    @ApiModelProperty(value = "是否删除")
    private Boolean isDel;

    @ApiModelProperty(value = "创建时间")
    private Date createTime;

    @ApiModelProperty(value = "更新时间")
    private Date updateTime;

    /** 实际使用的接口域名（按 test_mode 选） */
    public String effectiveApiBase() {
        boolean test = testMode == null || Boolean.TRUE.equals(testMode);
        String base = test ? apiBaseTest : apiBase;
        if (base == null || base.isEmpty()) {
            base = test ? apiBase : apiBaseTest; // 只配了一个就用那个
        }
        return base == null ? "" : base;
    }
}
