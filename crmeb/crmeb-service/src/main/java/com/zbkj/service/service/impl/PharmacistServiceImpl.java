package com.zbkj.service.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.pharmacist.Pharmacist;
import com.zbkj.service.dao.PharmacistDao;
import com.zbkj.service.service.PharmacistService;
import com.zbkj.service.service.crypto.SensitiveDataCrypto;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

/**
 * 执业药师档案实现
 *
 * 合规依据：《处方药网络零售合规指南》（药监综药管函〔2026〕282号）
 *   第八条     —— 配备执业药师并**在主页面显著位置持续公示**资格认定信息
 *   第二十条   —— 处方审核由执业药师逐项检查处方要素
 *   第二十二条 —— 审核**必须由本企业执业药师开展，不得由其他岗位人员或者人工智能代为实施**
 *
 * 对接用途：桃子云处方 3.5 接口要回传 outPharmacistID（客户审方药师ID）。
 */
@Slf4j
@Service
public class PharmacistServiceImpl extends ServiceImpl<PharmacistDao, Pharmacist>
        implements PharmacistService {

    @Autowired
    private SensitiveDataCrypto sensitiveDataCrypto;

    @Override
    public List<Pharmacist> listAll(boolean onlyValid) {
        LambdaQueryWrapper<Pharmacist> w = new LambdaQueryWrapper<Pharmacist>()
                .eq(Pharmacist::getIsDel, false);
        if (onlyValid) {
            w.eq(Pharmacist::getStatus, 1).eq(Pharmacist::getReviewEnabled, true);
        }
        w.orderByDesc(Pharmacist::getStatus).orderByAsc(Pharmacist::getId);
        return list(w);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Pharmacist create(Pharmacist p) {
        normalize(p);
        if (p.getId() != null) {
            throw new CrmebException("新增药师不应带 id");
        }
        p.setIsDel(false);
        if (p.getStatus() == null) {
            p.setStatus(1);
        }
        validate(p);
        save(p);
        log.info("[Pharmacist] 新增药师 id={} name={} 审方权限={} 公示={}",
                p.getId(), p.getName(), p.getReviewEnabled(), p.getIsPublic());
        return p;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Pharmacist update(Pharmacist p) {
        if (p.getId() == null) {
            throw new CrmebException("更新药师必须带 id");
        }
        Pharmacist exist = getById(p.getId());
        if (exist == null || Boolean.TRUE.equals(exist.getIsDel())) {
            throw new CrmebException("药师档案不存在: " + p.getId());
        }
        normalize(p);
        // 只更新传了值的字段，避免把没传的字段清空
        fillAbsentFrom(p, exist);
        validate(p);
        updateById(p);
        log.info("[Pharmacist] 更新药师 id={} name={} 审方权限={} 公示={}",
                p.getId(), p.getName(), p.getReviewEnabled(), p.getIsPublic());
        return p;
    }

    @Override
    public boolean canReview(Integer pharmacistId) {
        return pickById(pharmacistId) != null;
    }

    @Override
    public Pharmacist pickReviewer() {
        List<Pharmacist> all = listAll(true);
        for (Pharmacist p : all) {
            if (isReviewable(p)) {
                return p;
            }
        }
        return null;
    }

    @Override
    public List<Pharmacist> listForPublic() {
        List<Pharmacist> out = new ArrayList<>();
        for (Pharmacist p : listAll(true)) {
            if (!Boolean.TRUE.equals(p.getIsPublic()) || !isReviewable(p)) {
                continue;
            }
            // 只输出可公开字段，绝不含身份证/手机号
            Pharmacist safe = new Pharmacist()
                    .setId(p.getId())
                    .setName(p.getName())
                    .setCertNo(p.getCertNo())
                    .setRegisterUnit(p.getRegisterUnit())
                    .setCertValidEnd(p.getCertValidEnd());
            out.add(safe);
        }
        return out;
    }

    @Override
    public Pharmacist requireReviewer(Integer pharmacistId) {
        Pharmacist p = pickById(pharmacistId);
        if (p == null) {
            throw new CrmebException("该药师当前不可用于审方（可能已离职、无审方权限、"
                    + "注册有效期已过或未填注册单位）: " + pharmacistId);
        }
        return p;
    }

    // ---------- 内部 ----------

    private Pharmacist pickById(Integer id) {
        if (id == null) {
            return null;
        }
        Pharmacist p = getById(id);
        if (p == null || Boolean.TRUE.equals(p.getIsDel())) {
            return null;
        }
        return isReviewable(p) ? p : null;
    }

    /** 是否可审方：在职 + 有权限 + 有注册单位 + 注册有效期未过 */
    private boolean isReviewable(Pharmacist p) {
        if (p == null || !Integer.valueOf(1).equals(p.getStatus())) {
            return false;
        }
        if (!Boolean.TRUE.equals(p.getReviewEnabled())) {
            return false;
        }
        if (p.getRegisterUnit() == null || p.getRegisterUnit().trim().isEmpty()) {
            return false;
        }
        // 注册有效期止为空视为长期有效；填了且已过期则不可审方
        Date end = p.getRegisterValidEnd();
        return end == null || end.after(new Date());
    }

    /** 身份证加密 + 去空白 */
    private void normalize(Pharmacist p) {
        if (p.getName() != null) {
            p.setName(p.getName().trim());
        }
        if (p.getCertNo() != null) {
            p.setCertNo(p.getCertNo().trim());
        }
        if (p.getRegisterUnit() != null) {
            p.setRegisterUnit(p.getRegisterUnit().trim());
        }
        if (p.getPhone() != null) {
            p.setPhone(p.getPhone().trim());
        }
        // 身份证：已经是密文就不重复加密；否则加密后再存
        String id = p.getIdcard();
        if (id != null && !id.isEmpty() && !id.startsWith(SensitiveDataCrypto.PREFIX)) {
            p.setIdcard(sensitiveDataCrypto.encrypt(id.trim()));
        }
    }

    /** 更新时把未传的字段用原值补齐，再做完整校验（避免"只改备注"被校验拦下） */
    private void fillAbsentFrom(Pharmacist target, Pharmacist exist) {
        if (target.getName() == null) target.setName(exist.getName());
        if (target.getCertNo() == null) target.setCertNo(exist.getCertNo());
        if (target.getRegisterUnit() == null) target.setRegisterUnit(exist.getRegisterUnit());
        if (target.getRegisterValidEnd() == null) target.setRegisterValidEnd(exist.getRegisterValidEnd());
        if (target.getReviewEnabled() == null) target.setReviewEnabled(exist.getReviewEnabled());
        if (target.getIsPublic() == null) target.setIsPublic(exist.getIsPublic());
        if (target.getStatus() == null) target.setStatus(exist.getStatus());
        if (target.getOutPharmacistId() == null) target.setOutPharmacistId(exist.getOutPharmacistId());
    }

    private void validate(Pharmacist p) {
        if (p.getName() == null || p.getName().isEmpty()) {
            throw new CrmebException("药师姓名必填");
        }
        if (p.getCertNo() == null || p.getCertNo().isEmpty()) {
            throw new CrmebException("执业药师资格证书编号必填（合规要求公示）");
        }
        if (p.getCertNo() != null && p.getCertNo().length() > 64) {
            throw new CrmebException("资格证书编号过长");
        }
        // 开启审方权限 = 要承担法律责任，必须信息齐全
        if (Boolean.TRUE.equals(p.getReviewEnabled())) {
            if (p.getRegisterUnit() == null || p.getRegisterUnit().isEmpty()) {
                throw new CrmebException("开启审方权限前必须填写执业注册单位"
                        + "（依据《处方药网络零售合规指南》第二十二条，须为我方企业）");
            }
            Date end = p.getRegisterValidEnd();
            if (end != null && end.before(new Date())) {
                throw new CrmebException("执业注册有效期已过期，不能开启审方权限");
            }
            Date certEnd = p.getCertValidEnd();
            if (certEnd != null && certEnd.before(new Date())) {
                throw new CrmebException("执业药师资格证已过期，不能开启审方权限");
            }
        }
        // 公示的前提是这个人真的能审方，否则公示会误导用户
        if (Boolean.TRUE.equals(p.getIsPublic()) && !Boolean.TRUE.equals(p.getReviewEnabled())) {
            throw new CrmebException("只有具备审方权限的药师才能在商城前台公示"
                    + "（《处方药网络零售合规指南》第八条要求公示资格认定信息）");
        }
    }
}
