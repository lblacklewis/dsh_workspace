package com.zbkj.common.model.delivery;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.Date;

/**
 * 即时配送单
 * 一笔订单对应一条配送记录，记录运力商、骑手、状态流转
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@TableName("eb_delivery_order")
@ApiModel(value = "DeliveryOrder对象", description = "即时配送单")
public class DeliveryOrder implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "配送单id")
    @TableId(value = "id", type = IdType.AUTO)
    private Integer id;

    @ApiModelProperty(value = "关联订单id")
    private Integer orderId;

    @ApiModelProperty(value = "订单号")
    private String orderNo;

    @ApiModelProperty(value = "运力商 wx/meituan/fengniao/kuaidi100/mock")
    private String provider;

    @ApiModelProperty(value = "运力商订单号")
    private String outerNo;

    @ApiModelProperty(value = "0待发单 1已发单 2已接单 3已取货 4配送中 5已送达 6已取消 7发单失败")
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

    @ApiModelProperty(value = "配送距离(米)")
    private Integer distance;

    @ApiModelProperty(value = "预计送达(分钟)")
    private Integer estimateMin;

    @ApiModelProperty(value = "收件人")
    private String receiverName;

    @ApiModelProperty(value = "收件人电话")
    private String receiverPhone;

    @ApiModelProperty(value = "收件地址")
    private String receiverAddress;

    @ApiModelProperty(value = "发单失败原因")
    private String failReason;

    @ApiModelProperty(value = "最后一次回调时间")
    private Date callbackTime;

    @ApiModelProperty(value = "是否删除")
    private Boolean isDel;

    @ApiModelProperty(value = "创建时间")
    private Date createTime;

    @ApiModelProperty(value = "更新时间")
    private Date updateTime;
}
