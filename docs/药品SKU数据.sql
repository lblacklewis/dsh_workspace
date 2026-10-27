-- StorApp 药品 SKU 重建
-- 原 CRMEB 演示数据在 eb_store_product_attr_value 里留了 375 条旧 SKU
-- （墨镜/外套/靠垫/冰箱 的颜色尺码），价格与药品完全不符。
-- 这里把 7 个药品全部重置为单规格「默认」，价格库存与 eb_store_product 一致。
SET NAMES utf8mb4;

DELETE FROM eb_store_product_attr_value  WHERE product_id IN (100,101,102,159,167,168,170);
DELETE FROM eb_store_product_attr_option WHERE product_id IN (100,101,102,159,167,168,170);
DELETE FROM eb_store_product_attr        WHERE product_id IN (100,101,102,159,167,168,170);

-- id, 商品id, 规格名, 售价, 原价, 成本, 库存
INSERT INTO eb_store_product_attr (id, product_id, attr_name, attr_values, type, is_del, is_show_image) VALUES
 (9101, 101, '规格', '默认', 0, 0, 0),
 (9159, 159, '规格', '默认', 0, 0, 0),
 (9167, 167, '规格', '默认', 0, 0, 0),
 (9168, 168, '规格', '默认', 0, 0, 0),
 (9170, 170, '规格', '默认', 0, 0, 0),
 (9100, 100, '规格', '默认', 0, 0, 0),
 (9102, 102, '规格', '默认', 0, 0, 0);

INSERT INTO eb_store_product_attr_option (id, product_id, attr_id, option_name, image, sort, is_del) VALUES
 (9201, 101, 9101, '默认', '', 0, 0),
 (9259, 159, 9159, '默认', '', 0, 0),
 (9267, 167, 9167, '默认', '', 0, 0),
 (9268, 168, 9168, '默认', '', 0, 0),
 (9270, 170, 9170, '默认', '', 0, 0),
 (9200, 100, 9100, '默认', '', 0, 0),
 (9202, 102, 9102, '默认', '', 0, 0);

-- product_id, suk, stock, sales, price, image, unique, cost, ot_price, attr_value
INSERT INTO eb_store_product_attr_value
 (product_id, suk, stock, sales, price, image, `unique`, cost, bar_code, ot_price,
  weight, volume, brokerage, brokerage_two, type, quota, quota_show, attr_value,
  is_del, version, is_default, is_show) VALUES
 (101, '默认', 500, 0,  18.80, '', '',  9.50, '',  26.00, 0, 0, 0, 0, 0, 0, 0, '默认', 0, 0, 0, 1),
 (159, '默认', 300, 0,  22.50, '', '', 11.00, '',  29.90, 0, 0, 0, 0, 0, 0, 0, '默认', 0, 0, 0, 1),
 (167, '默认', 420, 0,  15.90, '', '',  7.80, '',  21.00, 0, 0, 0, 0, 0, 0, 0, '默认', 0, 0, 0, 1),
 (168, '默认', 260, 0,  26.00, '', '', 13.00, '',  33.00, 0, 0, 0, 0, 0, 0, 0, '默认', 0, 0, 0, 1),
 (170, '默认', 380, 0,  39.90, '', '', 19.00, '',  52.00, 0, 0, 0, 0, 0, 0, 0, '默认', 0, 0, 0, 1),
 (100, '默认', 120, 0, 199.00, '', '',118.00, '', 259.00, 0, 0, 0, 0, 0, 0, 0, '默认', 0, 0, 0, 1),
 (102, '默认', 600, 0,  12.50, '', '',  6.20, '',  16.80, 0, 0, 0, 0, 0, 0, 0, '默认', 0, 0, 0, 1);

SELECT CONCAT('SKU 数量: ', COUNT(*)) AS r FROM eb_store_product_attr_value WHERE product_id IN (100,101,102,159,167,168,170);
