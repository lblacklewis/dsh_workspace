-- 身份证号加密改造：加宽字段
--
-- 明文身份证 18 字符，AES-GCM + Base64 + "enc:" 前缀后是 68 字符，
-- 原列宽放不下，插入会直接抛 SQL 异常。
-- 注意：这个异常被全局异常处理包成了「服务器数据异常，请联系管理员」，
-- 排查时看不到 Data too long，容易误判成业务代码问题。
ALTER TABLE eb_prescription
  MODIFY COLUMN patient_idcard VARCHAR(255) DEFAULT NULL
  COMMENT '患者身份证号（AES-GCM 加密，enc: 前缀）';