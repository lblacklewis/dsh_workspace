package com.zbkj.service.service.delivery;

import com.zbkj.common.exception.CrmebException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 配送运力商工厂
 *
 * Spring 启动时把容器里所有 DeliveryProvider 实现按 code() 注册进 Map。
 * 新增一家运力商只需要写一个 @Component 实现类，这里不用改。
 */
@Slf4j
@Component
public class DeliveryProviderFactory {

    private final Map<String, DeliveryProvider> registry = new HashMap<>();

    @Autowired
    public DeliveryProviderFactory(List<DeliveryProvider> providers) {
        for (DeliveryProvider p : providers) {
            DeliveryProvider dup = registry.put(p.code(), p);
            if (dup != null) {
                // code 重复会导致发单发到错误的运力商，必须让启动就失败
                throw new CrmebException("配送运力商 code 重复: " + p.code()
                        + "（" + dup.getClass().getSimpleName() + " 与 " + p.getClass().getSimpleName() + "）");
            }
        }
        log.info("[DeliveryProviderFactory] 已注册运力商 {} 个: {}", registry.size(), registry.keySet());
    }

    /**
     * 按 code 取运力商，不存在则抛异常（配置写错要立刻暴露，不要静默降级）
     */
    public DeliveryProvider get(String code) {
        DeliveryProvider provider = registry.get(code);
        if (provider == null) {
            throw new CrmebException("未找到配送运力商: " + code + "，已注册: " + registry.keySet());
        }
        return provider;
    }

    /**
     * 是否存在该运力商
     */
    public boolean exists(String code) {
        return registry.containsKey(code);
    }

    /**
     * 全部已注册的 code
     */
    public java.util.Set<String> codes() {
        return registry.keySet();
    }
}
