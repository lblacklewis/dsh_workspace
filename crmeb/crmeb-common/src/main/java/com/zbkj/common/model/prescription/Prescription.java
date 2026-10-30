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
 * 处方单
 *
 * ⚠️ 合规要求（不要为了省事绕过）：
 *   1. 先方后药——处方药必须凭有效处方才能下单
 *   2. 药师审核——audit_status 必须为 1（通过）才可用于下单
 *   3. 处方留存——本表数据至少保留 2 年，不要做物理删除（用 is_del 软删）
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@TableName("eb_prescription")
@ApiModel(value = "Prescription对象", description = "处方单")
public class Prescription implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "主键")
    @TableId(value = "id", type = IdType.AUTO)
    private Integer id;

    @ApiModelProperty(value = "处方编号(我方生成)")
    private String rxNo;

    @ApiModelProperty(value = "用户id")
    private Integer uid;

    @ApiModelProperty(value = "来源 1用户上传 2互联网医院 3线下医院")
    private Integer source;

    @ApiModelProperty(value = "合作平台 code")
    private String provider;

    @ApiModelProperty(value = "对方处方号")
    private String outerRxNo;

    @ApiModelProperty(value = "对方问诊单号(桃子 orderID)")
    private String outerOrderNo;

    @ApiModelProperty(value = "患者姓名(实名)")
    private String patientName;

    /**
     * ⚠️ TODO(上线前必做)：身份证号目前是明文存储，这是合规风险。
     * 生产环境必须改成 AES 加密 + 密钥走 KMS/环境变量，并且展示时脱敏（如 6101**********1234）。
     * 之所以先留明文，是因为加密方案要跟密钥管理一起定，单独做半套反而更危险。
     */
    @ApiModelProperty(value = "身份证号(当前明文，上线前必须加密)")
    private String patientIdcard;

    @ApiModelProperty(value = "处方图片/PDF url，JSON 数组")
    private String images;

    @ApiModelProperty(value = "诊断")
    private String diagnosis;

    @ApiModelProperty(value = "科室code(桃子 sectionCode)")
    private String sectionCode;

    @ApiModelProperty(value = "科室名称(桃子 sectionName)")
    private String sectionName;

    @ApiModelProperty(value = "开方医师")
    private String doctorName;

    @ApiModelProperty(value = "医师所属医院")
    private String doctorHospital;

    @ApiModelProperty(value = "审核药师(eb_pharmacist.id)")
    private Integer pharmacistId;

    @ApiModelProperty(value = "审方药师姓名(冗余存，药师离职后仍可追溯)")
    private String pharmacistName;

    @ApiModelProperty(value = "审核来源 0未审 1我方药师 2平台药师(仅记录，不能替代我方审方)")
    private Integer auditSource;

    @ApiModelProperty(value = "0待审核 1通过 2驳回")
    private Integer auditStatus;

    @ApiModelProperty(value = "审核意见")
    private String auditRemark;

    @ApiModelProperty(value = "审核时间")
    private Date auditTime;

    @ApiModelProperty(value = "处方有效期起")
    private Date validStart;

    @ApiModelProperty(value = "处方有效期止")
    private Date validEnd;

    @ApiModelProperty(value = "1有效 0失效")
    private Integer status;

    @ApiModelProperty(value = "是否删除")
    private Boolean isDel;

    @ApiModelProperty(value = "创建时间")
    private Date createTime;

    @ApiModelProperty(value = "更新时间")
    private Date updateTime;
}
