-- StorApp 演示用户收货地址
-- 跑「加入购物车 → 结算 → 下单」时，预下单会对空地址列表 .get(0) 抛
-- IndexOutOfBoundsException: Index: 0, Size: 0，用户必须先有地址。
SET NAMES utf8mb4;

DELETE FROM eb_user_address WHERE uid = 55;

INSERT INTO eb_user_address
  (uid, real_name, phone, province, city, city_id, district, detail,
   post_code, longitude, latitude, is_default, is_del, create_time, update_time)
VALUES
  (55, '张先生', '13800138000', '陕西省', '西安市', 0, '雁塔区',
   '科技路 1 号 StorApp 演示大厦 8 楼', '710000', '', '', 1, 0, NOW(), NOW());

SELECT CONCAT('uid=55 地址数: ', COUNT(*)) AS r FROM eb_user_address WHERE uid = 55 AND is_del = 0;
