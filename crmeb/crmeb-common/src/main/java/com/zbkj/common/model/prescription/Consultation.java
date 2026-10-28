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
 * 在线问诊记录
 * 走合作互联网医院时使用，记录跳转/回调与开出的处方号
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@TableName("eb_consultation")
@ApiModel(value = "Consultation对象", description = "在线问诊记录")
public class Consultation implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "主键")
    @TableId(value = "id", type = IdType.AUTO)
    private Integer id;

    @ApiModelProperty(value = "问诊单号")
    private String consultNo;

    @ApiModelProperty(value = "用户id")
    private Integer uid;

    @ApiModelProperty(value = "合作平台 code")
    private String provider;

    @ApiModelProperty(value = "对方问诊单号")
    private String outerNo;

    @ApiModelProperty(value = "0发起 1问诊中 2已开方 3已结束 4已取消")
    private Integer status;

    @ApiModelProperty(value = "跳转合作平台的 url（跳转式对接用）")
    private String redirectUrl;

    @ApiModelProperty(value = "开出的处方号")
    private String rxNo;

    @ApiModelProperty(value = "备注")
    private String remark;

    @ApiModelProperty(value = "是否删除")
    private Boolean isDel;

    @ApiModelProperty(value = "创建时间")
    private Date createTime;

    @ApiModelProperty(value = "更新时间")
    private Date updateTime;
}
