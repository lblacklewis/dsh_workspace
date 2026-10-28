-- ============================================================
-- StorApp 健康药房 — 即时配送模块
-- 创建日期：2026-10-28
-- 字段命名与类型严格对齐 CRMEB 既有约定：
--   id           int unsigned AUTO_INCREMENT
--   varchar      utf8mb4_general_ci NOT NULL DEFAULT ''
--   布尔         tinyint(1) NOT NULL DEFAULT '0'
--   create_time  timestamp NULL DEFAULT CURRENT_TIMESTAMP
--   update_time  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
--   ENGINE=InnoDB CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC
-- ============================================================

-- ------------------------------------------------------------
-- 1. 配送单：一笔订单对应一条配送记录
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_delivery_order` (
  `id`            int unsigned NOT NULL AUTO_INCREMENT COMMENT '配送单id',
  `order_id`      int unsigned NOT NULL DEFAULT '0' COMMENT '关联 eb_store_order.id',
  `order_no`      varchar(64)  NOT NULL DEFAULT '' COMMENT '订单号',
  `provider`      varchar(32)  NOT NULL DEFAULT 'mock' COMMENT '运力商 wx/meituan/fengniao/kuaidi100/mock',
  `outer_no`      varchar(64)  NOT NULL DEFAULT '' COMMENT '运力商订单号',
  `status`        tinyint(1)   NOT NULL DEFAULT '0' COMMENT '0待发单 1已发单 2已接单 3已取货 4配送中 5已送达 6已取消 7发单失败',
  `rider_name`    varchar(32)  NOT NULL DEFAULT '' COMMENT '骑手姓名',
  `rider_phone`   varchar(20)  NOT NULL DEFAULT '' COMMENT '骑手电话',
  `rider_lat`     decimal(10,7) DEFAULT NULL COMMENT '骑手纬度',
  `rider_lng`     decimal(10,7) DEFAULT NULL COMMENT '骑手经度',
  `fee`           decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '配送费',
  `distance`      int          NOT NULL DEFAULT '0' COMMENT '配送距离(米)',
  `estimate_min`  int          NOT NULL DEFAULT '0' COMMENT '预计送达(分钟)',
  `receiver_name` varchar(32)  NOT NULL DEFAULT '' COMMENT '收件人',
  `receiver_phone` varchar(20) NOT NULL DEFAULT '' COMMENT '收件人电话',
  `receiver_address` varchar(255) NOT NULL DEFAULT '' COMMENT '收件地址',
  `fail_reason`   varchar(255) NOT NULL DEFAULT '' COMMENT '发单失败原因',
  `callback_time` timestamp NULL DEFAULT NULL COMMENT '最后一次回调时间',
  `is_del`        tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否删除',
  `create_time`   timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`   timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_id` (`order_id`),
  KEY `idx_outer_no` (`provider`,`outer_no`),
  KEY `idx_status` (`status`),
  KEY `idx_order_no` (`order_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='即时配送单';

-- ------------------------------------------------------------
-- 2. 运力商配置：密钥放 config_json（生产环境应加密，见方案文档）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_delivery_provider` (
  `id`          int unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `code`        varchar(32)  NOT NULL DEFAULT '' COMMENT '运力商标识',
  `name`        varchar(64)  NOT NULL DEFAULT '' COMMENT '运力商名称',
  `config_json` text COMMENT 'appKey/secret/门店映射等配置',
  `remark`      varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `sort`        int          NOT NULL DEFAULT '0' COMMENT '排序',
  `is_enable`   tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否启用',
  `is_del`      tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否删除',
  `create_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='配送运力商配置';

-- ------------------------------------------------------------
-- 3. 回调原始日志：运力商回调丢单时全靠这张表排查
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_delivery_callback_log` (
  `id`          bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `provider`    varchar(32)  NOT NULL DEFAULT '' COMMENT '运力商标识',
  `outer_no`    varchar(64)  NOT NULL DEFAULT '' COMMENT '运力商订单号',
  `event_type`  varchar(32)  NOT NULL DEFAULT '' COMMENT '事件类型',
  `raw_body`    text COMMENT '原始报文体',
  `headers`     text COMMENT '原始请求头',
  `is_parsed`   tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否解析成功',
  `err_msg`     varchar(500) NOT NULL DEFAULT '' COMMENT '错误信息',
  `create_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_provider_time` (`provider`,`create_time`),
  KEY `idx_outer_no` (`outer_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='配送回调原始日志';

-- ------------------------------------------------------------
-- 4. 初始化：先只启用 Mock，真实运力商等签约后再开
--    shipping_type 增加取值 3 = 同城即时配送（无需改表，tinyint 够用）
-- ------------------------------------------------------------
INSERT INTO `eb_delivery_provider` (`code`,`name`,`config_json`,`remark`,`sort`,`is_enable`)
VALUES
  ('mock',      '本地模拟（开发用）', '{}', '不调外部接口，模拟骑手状态推进，用于前后端联调', 0, 1),
  ('wx',        '微信即时配送',       '{}', '微信物流助手-即时配送，聚合美团/蜂鸟/达达/顺丰同城', 10, 0),
  ('kuaidi100', '快递100同城急送',    '{}', '聚合运力，H5 也能用，作为兜底', 20, 0),
  ('meituan',   '美团配送',           '{}', '需门店入驻，单量起来后再开', 30, 0),
  ('fengniao',  '蜂鸟即配',           '{}', '需商户资质签约', 40, 0)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `remark` = VALUES(`remark`), `sort` = VALUES(`sort`);
