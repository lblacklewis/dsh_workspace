-- 处方平台回调日志
--
-- 为什么需要：
--   互联网处方流转是受监管链路。合作互联网医院回调推送处方时，
--   必须能还原"对方推了什么、我们怎么处理的、为什么失败"。
--   配送链路已有 eb_delivery_callback_log，处方此前没有。
--   验签失败/解析失败这类问题在联调期最常见，没有原始报文基本无法定位。
--
-- 写入策略：无论成功失败都写一条（is_parsed 区分）。
--   raw_body 会截断到 4000 字符，避免对方推大报文把表撑爆。

CREATE TABLE IF NOT EXISTS `eb_prescription_callback_log` (
  `id`          bigint(20)   NOT NULL AUTO_INCREMENT,
  `provider`    varchar(50)  DEFAULT NULL COMMENT '处方平台 code',
  `outer_rx_no` varchar(100) DEFAULT NULL COMMENT '对方处方号',
  `event_type`  varchar(50)  DEFAULT NULL COMMENT '事件类型',
  `raw_body`    varchar(4000) DEFAULT NULL COMMENT '原始报文（截断）',
  `headers`     varchar(1000) DEFAULT NULL COMMENT '关键请求头',
  `is_parsed`   tinyint(1)   DEFAULT 0 COMMENT '是否解析并处理成功',
  `err_msg`     varchar(500) DEFAULT NULL COMMENT '失败原因',
  `create_time` datetime     DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_provider_time` (`provider`, `create_time`),
  KEY `idx_outer_rx_no` (`outer_rx_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='处方平台回调日志';
