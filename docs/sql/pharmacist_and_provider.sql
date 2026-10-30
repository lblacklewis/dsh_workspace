-- ============================================================
-- StorApp 健康药房 — 执业药师档案 + 处方平台配置
-- 创建日期：2026-10-30
--
-- 为什么需要这两张表：
--
-- 1) eb_pharmacist —— 合规硬要求
--    《处方药网络零售合规指南》（药监综药管函〔2026〕282号）
--      第八条：应当按规定配备执业药师，并在主页面显著位置**持续公示**其资格认定信息
--      第二十二条：处方审核**必须由本企业执业药师开展，不得由其他岗位人员或人工智能代为实施**
--    且桃子云处方的 3.5 接口要求回传 outPharmacistID（客户审方药师ID），
--    而 eb_prescription.pharmacist_id 原来只存"后台管理员id"，不是真实药师实体。
--
-- 2) eb_prescription_provider —— 对接配置
--    PrescriptionServiceImpl.currentProvider() 目前硬编码 providerFactory.get("mock")，
--    接入桃子后要改成从配置表读（与 DeliveryOrderServiceImpl.currentProvider() 同构）。
--    ⚠️ secretKey 是敏感凭证：库里存**密文**，与 patient_idcard 用同一套加密服务。
--
-- 字段类型对齐 CRMEB 既有约定（见 delivery_module.sql 头部说明）
-- 执行方式：MYSQL_PWD=xxx mysql -ujava_dev java_dev < this.sql
-- ============================================================

-- ------------------------------------------------------------
-- 1. 执业药师档案
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_pharmacist` (
  `id`                  int unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name`                varchar(32)  NOT NULL DEFAULT '' COMMENT '药师姓名',

  -- 执业药师资格证（合规要求公示的信息）
  `cert_no`             varchar(64)  NOT NULL DEFAULT '' COMMENT '执业药师资格证书编号',
  `cert_authority`      varchar(128) NOT NULL DEFAULT '' COMMENT '发证机关',
  `cert_valid_start`    date DEFAULT NULL COMMENT '资格证有效期起',
  `cert_valid_end`      date DEFAULT NULL COMMENT '资格证有效期止',

  -- 执业注册信息（注册单位必须是我方，否则不能审方）
  `register_no`         varchar(64)  NOT NULL DEFAULT '' COMMENT '执业注册证号',
  `register_unit`       varchar(128) NOT NULL DEFAULT '' COMMENT '执业注册单位（须为我方企业）',
  `register_valid_start` date DEFAULT NULL COMMENT '注册有效期起',
  `register_valid_end`  date DEFAULT NULL COMMENT '注册有效期止',

  -- 联系方式与身份（身份证加密存储）
  `phone`               varchar(20)  NOT NULL DEFAULT '' COMMENT '手机号',
  `idcard`              varchar(255) DEFAULT NULL COMMENT '身份证号（AES-GCM 加密，enc: 前缀）',

  -- 审方授权
  `review_enabled`      tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否有审方权限 1有 0无',
  `out_pharmacist_id`   varchar(64)  NOT NULL DEFAULT '' COMMENT '回传给处方平台的药师ID(桃子 outPharmacistID)',

  -- 公示（第八条要求主页面公示）
  `is_public`           tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否在商城前台公示 1是 0否',

  `status`              tinyint(1)   NOT NULL DEFAULT '1' COMMENT '1在职 0离职',
  `remark`              varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `is_del`              tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否删除（离职也不物理删，便于追溯历史审方）',
  `create_time`         timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`,`is_del`),
  KEY `idx_public` (`is_public`),
  KEY `idx_out_pharmacist` (`out_pharmacist_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='执业药师档案';

-- ------------------------------------------------------------
-- 2. 处方平台配置（当前只有 mock 和 taozhi 两个 code）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `eb_prescription_provider` (
  `id`             int unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `code`           varchar(32)  NOT NULL DEFAULT '' COMMENT '平台 code：mock/taozhi/...',
  `name`           varchar(64)  NOT NULL DEFAULT '' COMMENT '平台名称',
  `client_id`      varchar(64)  NOT NULL DEFAULT '' COMMENT '平台分配的 clientID',
  `secret_key`     varchar(255) DEFAULT NULL COMMENT '签名密钥（AES-GCM 加密存储，enc: 前缀；禁止明文）',
  `biz_id_prefix`  varchar(32)  NOT NULL DEFAULT '' COMMENT 'bizID 前缀（如需要）',
  `api_base`       varchar(128) NOT NULL DEFAULT '' COMMENT '接口域名（生产）',
  `api_base_test`  varchar(128) NOT NULL DEFAULT '' COMMENT '接口域名（测试）',
  `test_mode`      tinyint(1)   NOT NULL DEFAULT '1' COMMENT '1用测试域名 0用生产域名',

  -- 我方提供给对方的回调地址（对方调我方时用）
  `callback_url`   varchar(255) NOT NULL DEFAULT '' COMMENT '3.2 事件推送回调地址',
  `redirect_url`   varchar(255) NOT NULL DEFAULT '' COMMENT '问诊结束回跳地址(redirectUrl)',
  `audit_url`      varchar(255) NOT NULL DEFAULT '' COMMENT '3.4 待审核处方接收地址',

  `is_enable`      tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否启用',
  `sort`           int          NOT NULL DEFAULT '0' COMMENT '排序',
  `remark`         varchar(255) NOT NULL DEFAULT '' COMMENT '备注',
  `is_del`         tinyint(1)   NOT NULL DEFAULT '0' COMMENT '是否删除',
  `create_time`    timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`    timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`),
  KEY `idx_enable` (`is_enable`,`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='处方平台配置';

-- ------------------------------------------------------------
-- 3. 初始化配置
--    ⚠️ 默认只启用 mock（与配送模块的教训一致：配置开了但代码没实现 = 发单必然失败）
--    taozhi 的 clientID/secretKey 等对方给正式凭证后再填并启用
-- ------------------------------------------------------------
INSERT INTO `eb_prescription_provider`
  (`code`, `name`, `is_enable`, `sort`, `test_mode`, `remark`)
VALUES
  ('mock', '本地模拟（开发用）', 1, 0, 1,
   '不调外部接口，本地生成处方，用于前后端联调。生产环境务必置 0'),
  ('taozhi', '桃子云处方（100CBC）', 0, 10, 1,
   '复诊开方。代码未接入前不要启用；凭证到位后填 clientID/secret_key 再开启')
ON DUPLICATE KEY UPDATE `update_time` = CURRENT_TIMESTAMP;

-- ------------------------------------------------------------
-- 4. 处方表补字段（对接桃子需要，2026-10-30）
-- ------------------------------------------------------------
-- ⚠️ 踩坑：MySQL 8.0（本机 8.0.46）**不支持** `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`，
--    那是 MariaDB 的扩展语法，用了会直接 ERROR 1064。
--    这里改用查 information_schema + 动态 SQL 的写法，可重复执行（幂等）。
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sa_add_col_if_absent`;
DELIMITER $$
CREATE PROCEDURE `sa_add_col_if_absent`(
  IN p_table VARCHAR(64), IN p_col VARCHAR(64), IN p_def TEXT)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table AND COLUMN_NAME = p_col
  ) THEN
    SET @ddl = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_col, '` ', p_def);
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

-- 科室（桃子给 sectionCode/sectionName，处方留存要素）
CALL sa_add_col_if_absent('eb_prescription', 'section_code',
  "varchar(16) NOT NULL DEFAULT '' COMMENT '科室code(桃子 sectionCode)' AFTER `diagnosis`");
CALL sa_add_col_if_absent('eb_prescription', 'section_name',
  "varchar(64) NOT NULL DEFAULT '' COMMENT '科室名称(桃子 sectionName)' AFTER `section_code`");
-- 对方问诊单号（桃子 orderID）
CALL sa_add_col_if_absent('eb_prescription', 'outer_order_no',
  "varchar(64) NOT NULL DEFAULT '' COMMENT '对方问诊单号(桃子 orderID)' AFTER `outer_rx_no`");
-- 审方药师姓名冗余（药师离职后仍可追溯）
CALL sa_add_col_if_absent('eb_prescription', 'pharmacist_name',
  "varchar(32) NOT NULL DEFAULT '' COMMENT '审方药师姓名(冗余存，药师离职后仍可追溯)' AFTER `pharmacist_id`");
CALL sa_add_col_if_absent('eb_prescription', 'audit_source',
  "tinyint(1) NOT NULL DEFAULT '0' COMMENT '审核来源 0未审 1我方药师 2平台药师(仅记录，不能替代我方审方)'");

DROP PROCEDURE IF EXISTS `sa_add_col_if_absent`;

-- 处方防重说明：
-- 合规指南第二十一条要求"避免处方重复使用"。
-- 已有 idx_outer_rx_no 是普通索引，这里不改成唯一索引
-- （历史脏数据会导致加索引失败），先由应用层判重；
-- 上线前清理数据后再评估加 UNIQUE KEY uk_provider_outer (provider, outer_rx_no)。
