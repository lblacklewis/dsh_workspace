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
 * 处方-药品明细
 *
 * 来源有两种：
 * - 合作互联网医院回传处方时带回来的用药明细（可靠，能精确匹配商品）
 * - 用户手工上传的处方照片：**没有明细**，只能按「有有效处方」放行
 *
 * 正因为不是每张处方都有明细，下单校验里必须区分这两种情况：
 * 有明细的按明细精确匹配，没有明细的退回原有宽松规则。
 * 不能因为缺数据就把用户全拦死 —— 那是把系统缺陷转嫁给用户。
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@TableName("eb_prescription_product")
@ApiModel(value = "PrescriptionProduct", description = "处方药品明细")
public class PrescriptionProduct implements Serializable {

    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    @ApiModelProperty(value = "处方 id")
    private Integer prescriptionId;

    @ApiModelProperty(value = "商品 id")
    private Integer productId;

    @ApiModelProperty(value = "规格 id")
    private Integer skuId;

    @ApiModelProperty(value = "数量")
    private Integer quantity;

    private Date createTime;
}
