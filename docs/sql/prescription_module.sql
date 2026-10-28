-- ============================================================
-- StorApp 健康药房 — 互联网处方模块
-- 创建日期：2026-10-28
-- 合规依据：
--   1. 先方后药——处方药必须凭有效处方销售
--   2. 药师审核——处方须经执业药师审核通过方可售药
--   3. 处方留存——处方及审核记录保存 >= 2 年
-- 字段类型对齐 CRMEB 既有约定（见 delivery_module.sql 头部说明）
-- ============================================================

-- ------------------------------------------------------------
-- 1. 处方单
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_prescription` (
  `id`               int unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `rx_no`            varchar(64)  NOT NULL DEFAULT '' COMMENT '处方编号(我方生成)',
  `uid`              int unsigned NOT NULL DEFAULT '0' COMMENT '用户id',
  `source`           tinyint(1)   NOT NULL DEFAULT '1' COMMENT '来源 1用户上传 2互联网医院 3线下医院',
  `provider`         varchar(32)  NOT NULL DEFAULT '' COMMENT '合作平台 code，上传的为空',
  `outer_rx_no`      varchar(64)  NOT NULL DEFAULT '' COMMENT '对方处方号',
  `patient_name`     varchar(32)  NOT NULL DEFAULT '' COMMENT '患者姓名(实名)',
  `patient_idcard`   varchar(64)  NOT NULL DEFAULT '' COMMENT '身份证号(AES加密存储，禁止明文)',
  `images`           text COMMENT '处方图片/PDF url，JSON 数组',
  `diagnosis`        varchar(255) NOT NULL DEFAULT '' COMMENT '诊断',
  `doctor_name`      varchar(32)  NOT NULL DEFAULT '' COMMENT '开方医师',
  `doctor_hospital`  varchar(128) NOT NULL DEFAULT '' COMMENT '医师所属医院',
  `pharmacist_id`    int unsigned NOT NULL DEFAULT '0' COMMENT '审核药师(后台管理员id)',
  `audit_status`     tinyint(1)   NOT NULL DEFAULT '0' COMMENT '0待审核 1通过 2驳回',
  `audit_remark`     varchar(255) NOT NULL DEFAULT '' COMMENT '审核意见',
  `audit_time`       timestamp NULL DEFAULT NULL COMMENT '审核时间',
  `valid_start`      date DEFAULT NULL COMMENT '处方有效期起',
  `valid_end`        date DEFAULT NULL COMMENT '处方有效期止',
  `status`           tinyint(1)   NOT NULL DEFAULT '1' COMMENT '1有效 0失效',
  `is_del`           tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否删除',
  `create_time`      timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`      timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rx_no` (`rx_no`),
  KEY `idx_uid_status` (`uid`,`status`),
  KEY `idx_audit_status` (`audit_status`),
  KEY `idx_outer_rx_no` (`provider`,`outer_rx_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='处方单';

-- ------------------------------------------------------------
-- 2. 处方-商品关联（一个处方可含多个药）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_prescription_product` (
  `id`              int unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `prescription_id` int unsigned NOT NULL DEFAULT '0' COMMENT '处方id',
  `product_id`      int unsigned NOT NULL DEFAULT '0' COMMENT '商品id',
  `sku_id`          int unsigned NOT NULL DEFAULT '0' COMMENT '规格id',
  `quantity`        int          NOT NULL DEFAULT '1' COMMENT '数量',
  `create_time`     timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_prescription` (`prescription_id`),
  KEY `idx_product` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='处方与商品关联';

-- ------------------------------------------------------------
-- 3. 订单-处方关联（合规留痕，监管检查就看这张表）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_order_prescription` (
  `id`              bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `order_id`        int unsigned NOT NULL DEFAULT '0' COMMENT '订单id',
  `prescription_id` int unsigned NOT NULL DEFAULT '0' COMMENT '处方id',
  `create_time`     timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_rx` (`order_id`,`prescription_id`),
  KEY `idx_prescription` (`prescription_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='订单使用的处方（合规留痕）';

-- ------------------------------------------------------------
-- 4. 在线问诊记录（走合作互联网医院时用）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_consultation` (
  `id`           int unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `consult_no`   varchar(64)  NOT NULL DEFAULT '' COMMENT '问诊单号',
  `uid`          int unsigned NOT NULL DEFAULT '0' COMMENT '用户id',
  `provider`     varchar(32)  NOT NULL DEFAULT '' COMMENT '合作平台 code',
  `outer_no`     varchar(64)  NOT NULL DEFAULT '' COMMENT '对方问诊单号',
  `status`       tinyint(1)   NOT NULL DEFAULT '0' COMMENT '0发起 1问诊中 2已开方 3已结束 4已取消',
  `redirect_url` varchar(500) NOT NULL DEFAULT '' COMMENT '跳转合作平台的 url（跳转式对接用）',
  `rx_no`        varchar(64)  NOT NULL DEFAULT '' COMMENT '开出的处方号',
  `remark`       varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `is_del`       tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否删除',
  `create_time`  timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_consult_no` (`consult_no`),
  KEY `idx_uid` (`uid`),
  KEY `idx_outer_no` (`provider`,`outer_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='在线问诊记录';

-- ------------------------------------------------------------
-- 5. 商品表增加处方药标记
--    is_rx=1 的商品在加购/下单时会被强制校验处方
-- ------------------------------------------------------------
SET @exist := (SELECT COUNT(*) FROM information_schema.COLUMNS
               WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'eb_store_product' AND COLUMN_NAME = 'is_rx');
SET @sql := IF(@exist = 0,
  'ALTER TABLE `eb_store_product` ADD COLUMN `is_rx` tinyint(1) NOT NULL DEFAULT ''0'' COMMENT ''是否处方药 0否 1是'' , ADD KEY `idx_is_rx` (`is_rx`)',
  'SELECT ''is_rx 已存在，跳过''');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
