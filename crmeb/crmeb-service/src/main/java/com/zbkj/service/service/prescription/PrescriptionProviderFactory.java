package com.zbkj.service.service.prescription;

import com.zbkj.common.exception.CrmebException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 处方平台工厂
 * 与 DeliveryProviderFactory 同构：按 code() 自动注册所有实现
 */
@Slf4j
@Component
public class PrescriptionProviderFactory {

    private final Map<String, PrescriptionProvider> registry = new HashMap<>();

    @Autowired
    public PrescriptionProviderFactory(List<PrescriptionProvider> providers) {
        for (PrescriptionProvider p : providers) {
            PrescriptionProvider dup = registry.put(p.code(), p);
            if (dup != null) {
                throw new CrmebException("处方平台 code 重复: " + p.code());
            }
        }
        log.info("[PrescriptionProviderFactory] 已注册处方平台 {} 个: {}", registry.size(), registry.keySet());
    }

    public PrescriptionProvider get(String code) {
        PrescriptionProvider p = registry.get(code);
        if (p == null) {
            throw new CrmebException("未找到处方平台: " + code + "，已注册: " + registry.keySet());
        }
        return p;
    }

    public boolean exists(String code) {
        return registry.containsKey(code);
    }

    public java.util.Set<String> codes() {
        return registry.keySet();
    }
}
