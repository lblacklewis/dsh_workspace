package com.zbkj.service.dao;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zbkj.common.model.prescription.PrescriptionCallbackLog;
import org.apache.ibatis.annotations.Mapper;

/**
 * 处方平台回调日志
 */
@Mapper
public interface PrescriptionCallbackLogDao extends BaseMapper<PrescriptionCallbackLog> {
}
