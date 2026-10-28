package com.zbkj.service.service.delivery.dto;

import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.experimental.Accessors;

import java.io.Serializable;
import java.math.BigDecimal;

/**
 * 运力商回调解析结果
 * 各家回调报文格式完全不同，由各自 provider 解析后收敛成这个对象
 */
@Data
@Accessors(chain = true)
@ApiModel(value = "DeliveryCallbackData对象", description = "配送回调解析结果")
public class DeliveryCallbackData implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "运力商订单号")
    private String outerNo;

    @ApiModelProperty(value = "我方订单号（部分运力商会原样回传）")
    private String orderNo;

    @ApiModelProperty(value = "统一后的状态，见 DeliveryStatus")
    private Integer status;

    @ApiModelProperty(value = "运力商原始状态")
    private String rawStatus;

    @ApiModelProperty(value = "骑手姓名")
    private String riderName;

    @ApiModelProperty(value = "骑手电话")
    private String riderPhone;

    @ApiModelProperty(value = "骑手纬度")
    private BigDecimal riderLat;

    @ApiModelProperty(value = "骑手经度")
    private BigDecimal riderLng;

    @ApiModelProperty(value = "取消/异常原因")
    private String reason;
}
