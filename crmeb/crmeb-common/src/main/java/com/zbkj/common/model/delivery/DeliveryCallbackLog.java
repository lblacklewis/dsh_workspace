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
import java.util.Date;

/**
 * 配送回调原始日志
 * 运力商回调是异步且可能丢失的，这张表是排查丢单的唯一依据，不要省
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@TableName("eb_delivery_callback_log")
@ApiModel(value = "DeliveryCallbackLog对象", description = "配送回调原始日志")
public class DeliveryCallbackLog implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "主键")
    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    @ApiModelProperty(value = "运力商标识")
    private String provider;

    @ApiModelProperty(value = "运力商订单号")
    private String outerNo;

    @ApiModelProperty(value = "事件类型")
    private String eventType;

    @ApiModelProperty(value = "原始报文体")
    private String rawBody;

    @ApiModelProperty(value = "原始请求头")
    private String headers;

    @ApiModelProperty(value = "是否解析成功")
    private Boolean isParsed;

    @ApiModelProperty(value = "错误信息")
    private String errMsg;

    @ApiModelProperty(value = "创建时间")
    private Date createTime;
}
