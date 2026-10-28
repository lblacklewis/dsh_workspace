package com.zbkj.admin.task;

import org.quartz.Scheduler;
import org.quartz.SchedulerException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * Quartz 调度器启动守卫。
 *
 * 现象：本部署里 Quartz 被完整创建（admin.log 可见 SchedulerFactoryBean、
 * SimpleThreadPool 10 线程、LocalDataSourceJobStore 支持持久化），
 * 但日志里从来没有 "started"，调度器一直没真正跑起来。
 * 结果是 eb_schedule_job 里 19 个任务全部停摆，
 * qrtz_triggers 的 PREV_FIRE_TIME 停在 2025-11-14。
 *
 * 影响面：自动取消未支付订单、自动完成、自动收货、库存操作、佣金冻结、
 * 优惠券过期、积分冻结、支付成功后置处理（积分/佣金/短信/同城配送自动发单）全都依赖它。
 *
 * 这里只做一件事：应用启动后检查调度器状态，如果没在运行就把它启动起来。
 * 不做别的干预 —— 任务的启停仍然完全由 eb_schedule_job.status 控制。
 */
@Component
public class QuartzStartupGuard implements ApplicationRunner {

    private static final Logger logger = LoggerFactory.getLogger(QuartzStartupGuard.class);

    @Autowired(required = false)
    private Scheduler scheduler;

    @Override
    public void run(ApplicationArguments args) {
        if (scheduler == null) {
            logger.error("QuartzStartupGuard：容器里没有 Scheduler，Quartz 自动配置可能未生效，全部定时任务不会执行");
            return;
        }
        try {
            String name = scheduler.getSchedulerName();
            boolean started = scheduler.isStarted();
            boolean standby = scheduler.isInStandbyMode();
            logger.info("QuartzStartupGuard：调度器 [{}] started={} standby={}", name, started, standby);

            if (!started || standby) {
                // 先解除 standby（若有），再启动。两步都不怕重复调用。
                if (standby) {
                    scheduler.start();
                    logger.warn("QuartzStartupGuard：调度器原本处于 standby，已解除");
                }
                if (!scheduler.isStarted()) {
                    scheduler.start();
                    logger.warn("QuartzStartupGuard：调度器原本未启动，已启动");
                }
                logger.info("QuartzStartupGuard：处理后 started={} standby={}",
                        scheduler.isStarted(), scheduler.isInStandbyMode());
            } else {
                logger.info("QuartzStartupGuard：调度器运行正常，无需干预");
            }
        } catch (SchedulerException e) {
            logger.error("QuartzStartupGuard：处理调度器状态失败，全部定时任务可能仍不执行：{}", e.getMessage(), e);
        } catch (Exception e) {
            logger.error("QuartzStartupGuard：意外异常：{}", e.getMessage(), e);
        }
    }
}
