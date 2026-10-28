package com.zbkj.common.request;

import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;

import java.io.Serializable;
import java.math.BigDecimal;

/**
 * 同城配送询价请求
 * 收货信息由前端从用户选中的收货地址带过来，不做服务端地址查询，保持接口无状态
 */
@Data
@ApiModel(value = "DeliveryQuoteRequest对象", description = "同城配送询价请求")
public class DeliveryQuoteRequest implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "收货人姓名")
    private String toName;

    @ApiModelProperty(value = "收货人电话")
    private String toPhone;

    @ApiModelProperty(value = "收货地址")
    private String toAddress;

    @ApiModelProperty(value = "收货纬度")
    private BigDecimal toLat;

    @ApiModelProperty(value = "收货经度")
    private BigDecimal toLng;

    @ApiModelProperty(value = "商品件数")
    private Integer goodsCount = 1;

    @ApiModelProperty(value = "指定运力商，不传用当前启用的")
    private String provider;
}
