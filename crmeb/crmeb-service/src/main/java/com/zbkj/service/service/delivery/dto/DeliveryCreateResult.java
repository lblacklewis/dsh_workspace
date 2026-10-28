package com.zbkj.service.service.delivery.dto;

import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.experimental.Accessors;

import java.io.Serializable;
import java.math.BigDecimal;

/**
 * 发单结果 / 状态查询结果
 * 各运力商接口字段差异很大，统一收敛到这几个字段
 */
@Data
@Accessors(chain = true)
@ApiModel(value = "DeliveryCreateResult对象", description = "配送发单结果")
public class DeliveryCreateResult implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "是否成功")
    private Boolean success = false;

    @ApiModelProperty(value = "运力商订单号")
    private String outerNo;

    @ApiModelProperty(value = "运力商侧状态码（原始值，排查用）")
    private String rawStatus;

    @ApiModelProperty(value = "统一后的状态，见 DeliveryStatus")
    private Integer status;

    @ApiModelProperty(value = "骑手姓名")
    private String riderName;

    @ApiModelProperty(value = "骑手电话")
    private String riderPhone;

    @ApiModelProperty(value = "骑手纬度")
    private BigDecimal riderLat;

    @ApiModelProperty(value = "骑手经度")
    private BigDecimal riderLng;

    @ApiModelProperty(value = "配送费")
    private BigDecimal fee;

    @ApiModelProperty(value = "失败原因")
    private String errMsg;
}
