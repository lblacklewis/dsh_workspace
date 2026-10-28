-- Quartz 定时任务全部停摆的修复
--
-- 现象：
--   eb_schedule_job 里 19 个任务 status 全为 0，qrtz_TRIGGERS 的 PREV_FIRE_TIME
--   停在 2025-11-14，admin.log 里没有任何任务执行记录。
--   Redis 队列 orderPaySuccessTask 中的订单号一直堆积不消费。
--   后果：自动取消未支付订单、自动完成、自动收货、库存操作、佣金冻结、
--         优惠券过期、积分冻结、支付成功后置处理（积分/佣金/短信/配送自动发单）全部不执行。
--
-- 根因（两层，都会让 Quartz 启动失败）：
--   1) spring.quartz.properties.org.quartz.jobStore.tablePrefix 配的是大写 QRTZ_，
--      但库里的表是小写 qrtz_*。MySQL 的 lower_case_table_names=0（Linux 默认）
--      下大小写敏感，Quartz 一张表都找不到。
--   2) Quartz 内部的表名是 tablePrefix + 硬编码大写后缀（LOCKS / TRIGGERS /
--      JOB_DETAILS ...），所以即使前缀改成小写，表名仍须是 qrtz_LOCKS 这种
--      「小写前缀 + 大写后缀」形式，而实际表是全小写。
--
-- 修复步骤一：改配置（已改，见 crmeb-admin/src/main/resources/application.yml）
--   tablePrefix: QRTZ_  ->  tablePrefix: qrtz_
--
-- 修复步骤二：重命名 Quartz 表（本文件）
--   注意 lower_case_table_names=0 下 qrtz_locks 与 QRTZ_LOCKS 是两个不同的表，
--   不要用 CREATE TABLE IF NOT EXISTS 去补，那样会建出一张 Quartz 永远用不到的表。
--
-- 执行后需要重启 admin。启动日志应出现：
--   QuartzStartupGuard：调度器原本处于 standby，已解除
--   QuartzStartupGuard：处理后 started=true standby=false
-- 并且 qrtz_TRIGGERS 的 PREV_FIRE_TIME 应推进到当前时间。

RENAME TABLE qrtz_blob_triggers       TO qrtz_BLOB_TRIGGERS;
RENAME TABLE qrtz_cron_triggers       TO qrtz_CRON_TRIGGERS;
RENAME TABLE qrtz_fired_triggers      TO qrtz_FIRED_TRIGGERS;
RENAME TABLE qrtz_job_details         TO qrtz_JOB_DETAILS;
RENAME TABLE qrtz_locks               TO qrtz_LOCKS;
RENAME TABLE qrtz_paused_trigger_grps TO qrtz_PAUSED_TRIGGER_GRPS;
RENAME TABLE qrtz_scheduler_state     TO qrtz_SCHEDULER_STATE;
RENAME TABLE qrtz_simple_triggers     TO qrtz_SIMPLE_TRIGGERS;
RENAME TABLE qrtz_simprop_triggers    TO qrtz_SIMPROP_TRIGGERS;
RENAME TABLE qrtz_triggers            TO qrtz_TRIGGERS;