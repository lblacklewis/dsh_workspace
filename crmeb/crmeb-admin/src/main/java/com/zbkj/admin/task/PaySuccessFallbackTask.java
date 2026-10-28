package com.zbkj.admin.task;

import com.zbkj.service.service.OrderTaskService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

/**
 * 支付成功后置处理的兜底调度。
 *
 * 背景：本部署里 Quartz 调度器没有真正启动（admin.log 里没有 "Scheduler started"，
 * eb_schedule_job 的 19 条任务 status 全为 0，qrtz_triggers 的 PREV_FIRE_TIME
 * 停在 2025-11-14）。结果是 OrderTaskServiceImpl.orderPaySuccessAfter() 从未被调用，
 * Redis 队列 orderPaySuccessTask 里的订单号一直堆积。
 *
 * 影响面远超配送：下单赠送积分、商品赠送积分、经验值、佣金记录、
 * 支付成功短信/模板通知、以及同城即时配送的自动发单，全都挂在这条链路上。
 *
 * 这里用 Spring 的 @Scheduled 直接驱动同一个方法作为兜底：
 * orderPaySuccessAfter() 是从 Redis 队列右端弹出，每条只处理一次，
 * 即使 Quartz 以后恢复运行也不会重复处理。
 *
 * 注意：这只是兜底，不是根治。其余 18 个任务（自动取消、自动完成、
 * 库存操作、佣金冻结等）仍然是停摆的，需要单独排查 Quartz 启动问题。
 */
@Configuration
@EnableScheduling
public class PaySuccessFallbackTask {

    private static final Logger logger = LoggerFactory.getLogger(PaySuccessFallbackTask.class);

    @Autowired
    private OrderTaskService orderTaskService;

    /**
     * 每 60 秒跑一次，启动后延迟 30 秒（避开启动期）。
     *
     * 整个方法 try-catch：调度线程里抛出未捕获异常会导致后续调度被取消。
     */
    @Scheduled(initialDelay = 30000, fixedDelay = 60000)
    public void orderPaySuccessAfter() {
        try {
            orderTaskService.orderPaySuccessAfter();
        } catch (Exception e) {
            logger.error("支付成功后置处理（兜底调度）异常：{}", e.getMessage(), e);
        }
    }
}
