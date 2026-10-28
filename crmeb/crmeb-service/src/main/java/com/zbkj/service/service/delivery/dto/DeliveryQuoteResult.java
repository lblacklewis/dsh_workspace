package com.zbkj.service.service.delivery.dto;

import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.experimental.Accessors;

import java.io.Serializable;
import java.math.BigDecimal;

/**
 * 配送询价结果
 * 结算页展示用：运费 + 预计送达时长 + 距离
 */
@Data
@Accessors(chain = true)
@ApiModel(value = "DeliveryQuoteResult对象", description = "配送询价结果")
public class DeliveryQuoteResult implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "询价是否成功")
    private Boolean success = false;

    @ApiModelProperty(value = "配送费")
    private BigDecimal fee = BigDecimal.ZERO;

    @ApiModelProperty(value = "距离(米)")
    private Integer distance = 0;

    @ApiModelProperty(value = "预计送达(分钟)")
    private Integer estimateMin = 0;

    @ApiModelProperty(value = "失败原因")
    private String errMsg;
}
