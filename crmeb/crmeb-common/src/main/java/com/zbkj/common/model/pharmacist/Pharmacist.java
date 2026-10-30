package com.zbkj.common.model.pharmacist;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.fasterxml.jackson.annotation.JsonFormat;
import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

import java.io.Serializable;
import java.util.Date;

/**
 * 执业药师档案
 *
 * 存在的理由（合规，不要绕过）：
 * 《处方药网络零售合规指南》（药监综药管函〔2026〕282号）
 *   第八条  —— 应配备执业药师，并在主页面显著位置**持续公示**其资格认定信息（is_public 字段）
 *   第二十条、二十二条 —— 处方审核**必须由本企业执业药师开展**，
 *                        **不得由其他岗位人员或者人工智能代为实施**
 *
 * 另外对接桃子云处方时，3.5 接口要求回传 `outPharmacistID`（客户审方药师ID），
 * 对应本表的 out_pharmacist_id。
 *
 * ⚠️ 离职不要物理删除：历史审方记录要能追溯到人，用 status + is_del 软标记。
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@TableName("eb_pharmacist")
@ApiModel(value = "Pharmacist对象", description = "执业药师档案")
public class Pharmacist implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "主键")
    @TableId(value = "id", type = IdType.AUTO)
    private Integer id;

    @ApiModelProperty(value = "药师姓名")
    private String name;

    @ApiModelProperty(value = "执业药师资格证书编号")
    private String certNo;

    @ApiModelProperty(value = "发证机关")
    private String certAuthority;

    @ApiModelProperty(value = "资格证有效期起")
    @JsonFormat(pattern = "yyyy-MM-dd")
    private Date certValidStart;

    @ApiModelProperty(value = "资格证有效期止")
    @JsonFormat(pattern = "yyyy-MM-dd")
    private Date certValidEnd;

    @ApiModelProperty(value = "执业注册证号")
    private String registerNo;

    @ApiModelProperty(value = "执业注册单位（须为我方企业，否则不能审方）")
    private String registerUnit;

    @ApiModelProperty(value = "注册有效期起")
    @JsonFormat(pattern = "yyyy-MM-dd")
    private Date registerValidStart;

    @ApiModelProperty(value = "注册有效期止")
    @JsonFormat(pattern = "yyyy-MM-dd")
    private Date registerValidEnd;

    @ApiModelProperty(value = "手机号")
    private String phone;

    /**
     * ⚠️ 加密存储（AES-GCM，enc: 前缀），与 eb_prescription.patient_idcard 同一套
     * {@link com.zbkj.service.service.crypto.SensitiveDataCrypto}
     */
    @ApiModelProperty(value = "身份证号（AES-GCM 加密，enc: 前缀）")
    private String idcard;

    @ApiModelProperty(value = "是否有审方权限 1有 0无")
    private Boolean reviewEnabled;

    @ApiModelProperty(value = "回传给处方平台的药师ID(桃子 outPharmacistID)")
    private String outPharmacistId;

    @ApiModelProperty(value = "是否在商城前台公示 1是 0否")
    private Boolean isPublic;

    @ApiModelProperty(value = "1在职 0离职")
    private Integer status;

    @ApiModelProperty(value = "备注")
    private String remark;

    @ApiModelProperty(value = "是否删除")
    private Boolean isDel;

    @ApiModelProperty(value = "创建时间")
    private Date createTime;

    @ApiModelProperty(value = "更新时间")
    private Date updateTime;
}
