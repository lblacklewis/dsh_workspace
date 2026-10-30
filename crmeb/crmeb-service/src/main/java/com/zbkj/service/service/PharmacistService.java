package com.zbkj.service.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.zbkj.common.model.pharmacist.Pharmacist;

import java.util.List;

/**
 * 执业药师档案服务
 */
public interface PharmacistService extends IService<Pharmacist> {

    /**
     * 档案列表（后台管理用）
     *
     * @param onlyValid true 只返回在职且有审方权限的
     */
    List<Pharmacist> listAll(boolean onlyValid);

    /**
     * 新增档案。
     *
     * 会做这些校验/处理（不合规的数据不允许入库）：
     *   - 姓名、资格证号必填
     *   - 身份证号**加密后**再存（绝不落明文）
     *   - 要开启审方权限(reviewEnabled)时，必须同时具备：
     *       资格证号 + 注册单位 + 注册有效期未过期
     *     —— 依据《处方药网络零售合规指南》第二十二条，
     *        审方必须由本企业执业药师开展，没有注册信息的人不能审方
     *   - 要对外公示(isPublic)时，必须开启审方权限：
     *     —— 第八条要求公示的是"资格认定信息"，公示一个不能审方的人没有意义且会误导用户
     */
    Pharmacist create(Pharmacist p);

    /**
     * 更新档案（同 create 的校验）
     */
    Pharmacist update(Pharmacist p);

    /**
     * 该药师当前是否**可以用于审方**：
     * 在职 + 未删除 + 有审方权限 + 注册有效期未过期 + 有注册单位
     */
    boolean canReview(Integer pharmacistId);

    /**
     * 取一个可审方的药师，没有则返回 null
     */
    Pharmacist pickReviewer();

    /**
     * 前台公示用的列表（只返回姓名 + 资格证号等可公开字段，不含身份证/手机号）
     */
    List<Pharmacist> listForPublic();

    /**
     * 按 id 取，且校验可审方；不可审方抛异常并说明原因
     * （审方前置校验用，宁可拦下来也不要放过）
     */
    Pharmacist requireReviewer(Integer pharmacistId);
}
