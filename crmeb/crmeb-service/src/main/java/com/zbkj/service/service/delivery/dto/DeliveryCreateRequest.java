package com.zbkj.service.service.delivery.dto;

import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.experimental.Accessors;

import java.io.Serializable;
import java.math.BigDecimal;

/**
 * 发单请求
 * 提供给各运力商实现的统一入参，业务层只构造这一个对象
 */
@Data
@Accessors(chain = true)
@ApiModel(value = "DeliveryCreateRequest对象", description = "配送发单请求")
public class DeliveryCreateRequest implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "我方订单号（作为幂等键回传）")
    private String orderNo;

    @ApiModelProperty(value = "取货门店名称")
    private String fromName;

    @ApiModelProperty(value = "取货门店电话")
    private String fromPhone;

    @ApiModelProperty(value = "取货地址")
    private String fromAddress;

    @ApiModelProperty(value = "取货纬度")
    private BigDecimal fromLat;

    @ApiModelProperty(value = "取货经度")
    private BigDecimal fromLng;

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

    @ApiModelProperty(value = "商品重量(克)")
    private Integer weight = 1000;

    @ApiModelProperty(value = "备注")
    private String remark;
}
