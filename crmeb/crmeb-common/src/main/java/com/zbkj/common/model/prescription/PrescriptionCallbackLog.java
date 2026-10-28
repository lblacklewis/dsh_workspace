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
 * 处方平台回调日志
 *
 * 无论验签、解析、落库成功与否都要写一条 —— 互联网处方流转是受监管的链路，
 * 出问题时必须能还原"对方推了什么、我们怎么处理的"。
 * 与 eb_delivery_callback_log 同构。
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@TableName("eb_prescription_callback_log")
@ApiModel(value = "PrescriptionCallbackLog", description = "处方平台回调日志")
public class PrescriptionCallbackLog implements Serializable {

    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    @ApiModelProperty(value = "处方平台 code")
    private String provider;

    @ApiModelProperty(value = "对方处方号（解析出来才有）")
    private String outerRxNo;

    @ApiModelProperty(value = "事件类型（如有）")
    private String eventType;

    @ApiModelProperty(value = "原始报文，截断保存")
    private String rawBody;

    @ApiModelProperty(value = "关键请求头，便于排查验签失败")
    private String headers;

    @ApiModelProperty(value = "是否解析并处理成功")
    private Boolean isParsed;

    @ApiModelProperty(value = "失败原因")
    private String errMsg;

    private Date createTime;
}
