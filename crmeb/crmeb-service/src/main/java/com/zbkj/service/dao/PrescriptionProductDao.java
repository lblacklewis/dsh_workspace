package com.zbkj.service.dao;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zbkj.common.model.prescription.PrescriptionProduct;
import org.apache.ibatis.annotations.Mapper;

/**
 * 处方药品明细
 */
@Mapper
public interface PrescriptionProductDao extends BaseMapper<PrescriptionProduct> {
}
