-- StorApp 药品商品数据
SET NAMES utf8mb4;
DELETE FROM eb_store_product_cate;
UPDATE eb_store_product SET
  store_name='感冒灵颗粒', keyword='感冒 发烧 头痛', cate_id='900',
  price=18.8, ot_price=26, cost=9.5, stock=500,
  unit_name='盒', store_info='清热解毒，用于感冒引起的头痛发热',
  image='crmebimage/brand/products/p101.svg', slider_image='["crmebimage/brand/products/p101.svg"]',
  is_show=1, is_del=0, is_best=1, is_new=1, is_hot=1, spec_type=0
WHERE id=101;
INSERT INTO eb_store_product_cate (product_id, cate_id, add_time) VALUES (101, 900, UNIX_TIMESTAMP());
UPDATE eb_store_product SET
  store_name='布洛芬缓释胶囊', keyword='退烧 止痛 布洛芬', cate_id='900',
  price=22.5, ot_price=29.9, cost=11, stock=300,
  unit_name='盒', store_info='缓解轻至中度疼痛，退热',
  image='crmebimage/brand/products/p159.svg', slider_image='["crmebimage/brand/products/p159.svg"]',
  is_show=1, is_del=0, is_best=1, is_new=1, is_hot=1, spec_type=0
WHERE id=159;
INSERT INTO eb_store_product_cate (product_id, cate_id, add_time) VALUES (159, 900, UNIX_TIMESTAMP());
UPDATE eb_store_product SET
  store_name='健胃消食片', keyword='消化不良 健胃', cate_id='1000',
  price=15.9, ot_price=21, cost=7.8, stock=420,
  unit_name='盒', store_info='健胃消食，用于脾胃虚弱所致的食积',
  image='crmebimage/brand/products/p167.svg', slider_image='["crmebimage/brand/products/p167.svg"]',
  is_show=1, is_del=0, is_best=1, is_new=1, is_hot=1, spec_type=0
WHERE id=167;
INSERT INTO eb_store_product_cate (product_id, cate_id, add_time) VALUES (167, 1000, UNIX_TIMESTAMP());
UPDATE eb_store_product SET
  store_name='蒙脱石散', keyword='止泻 腹泻', cate_id='1000',
  price=26, ot_price=33, cost=13, stock=260,
  unit_name='盒', store_info='用于成人及儿童急、慢性腹泻',
  image='crmebimage/brand/products/p168.svg', slider_image='["crmebimage/brand/products/p168.svg"]',
  is_show=1, is_del=0, is_best=1, is_new=1, is_hot=1, spec_type=0
WHERE id=168;
INSERT INTO eb_store_product_cate (product_id, cate_id, add_time) VALUES (168, 1000, UNIX_TIMESTAMP());
UPDATE eb_store_product SET
  store_name='维生素C咀嚼片', keyword='维生素C 补充', cate_id='1400',
  price=39.9, ot_price=52, cost=19, stock=380,
  unit_name='瓶', store_info='补充维生素C，增强免疫力',
  image='crmebimage/brand/products/p170.svg', slider_image='["crmebimage/brand/products/p170.svg"]',
  is_show=1, is_del=0, is_best=1, is_new=1, is_hot=1, spec_type=0
WHERE id=170;
INSERT INTO eb_store_product_cate (product_id, cate_id, add_time) VALUES (170, 1400, UNIX_TIMESTAMP());
UPDATE eb_store_product SET
  store_name='电子血压计', keyword='血压计 家用', cate_id='1500',
  price=199, ot_price=259, cost=118, stock=120,
  unit_name='台', store_info='上臂式电子血压计，一键测量，语音播报',
  image='crmebimage/brand/products/p100.svg', slider_image='["crmebimage/brand/products/p100.svg"]',
  is_show=1, is_del=0, is_best=1, is_new=1, is_hot=1, spec_type=0
WHERE id=100;
INSERT INTO eb_store_product_cate (product_id, cate_id, add_time) VALUES (100, 1500, UNIX_TIMESTAMP());
UPDATE eb_store_product SET
  store_name='云南白药创可贴', keyword='创可贴 止血', cate_id='1900',
  price=12.5, ot_price=16.8, cost=6.2, stock=600,
  unit_name='盒', store_info='止血镇痛，消炎愈创，家庭常备',
  image='crmebimage/brand/products/p102.svg', slider_image='["crmebimage/brand/products/p102.svg"]',
  is_show=1, is_del=0, is_best=1, is_new=1, is_hot=1, spec_type=0
WHERE id=102;
INSERT INTO eb_store_product_cate (product_id, cate_id, add_time) VALUES (102, 1900, UNIX_TIMESTAMP());
UPDATE eb_store_product SET is_show=0 WHERE id NOT IN (101,159,167,168,170,100,102);
SELECT CONCAT('药品商品: ', COUNT(*)) AS r FROM eb_store_product WHERE is_show=1 AND is_del=0;
