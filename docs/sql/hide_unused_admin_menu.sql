-- 后台菜单精简：隐藏与"只卖药"无关的模块
--
-- 依据：docs/接口可用性盘点.md 第七节。
-- 营销/分销/财务/应用/装修/移动端管理 这几个模块的数据几乎全为 0
-- （秒杀 0、砍价 0、拼团 0、充值 0、提现 0、佣金 0），药品业务也不做这些玩法。
--
-- 做法：只置 is_show=0，**不删行**。
--   - 完全可逆：改回 is_show=1 即恢复
--   - 不影响权限数据，不影响接口
--   - 菜单由 getMenus() 返回，is_show=0 即不可见
--
-- 注意：is_show 只控制"可不可见"，接口仍可被直接调用。
-- 若需要真正阻断后台操作，还要从 eb_system_role_menu 移除对应权限。
-- 本脚本不做这一步 —— 对超级管理员没有意义（他本来就能做任何事）。
--
-- 用名称而不是硬编码 id 匹配：id 在不同环境（重装、二次导入）会漂移，
-- 而且这个库确实被反复导入过。

-- 一级菜单：直接隐藏
UPDATE eb_system_menu
SET is_show = 0
WHERE is_delte = 0
  AND pid = 0
  AND name IN ('营销', '分销', '财务', '应用', '装修', '移动端管理');

-- 这些一级菜单下的二级菜单
UPDATE eb_system_menu
SET is_show = 0
WHERE is_delte = 0
  AND pid IN (
    SELECT id FROM (
      SELECT id FROM eb_system_menu
      WHERE is_delte = 0 AND pid = 0
        AND name IN ('营销', '分销', '财务', '应用', '装修', '移动端管理')
    ) t1
  );

-- 二级菜单下的按钮
UPDATE eb_system_menu
SET is_show = 0
WHERE is_delte = 0
  AND pid IN (
    SELECT id FROM (
      SELECT id FROM eb_system_menu
      WHERE is_delte = 0
        AND pid IN (
          SELECT id FROM (
            SELECT id FROM eb_system_menu
            WHERE is_delte = 0 AND pid = 0
              AND name IN ('营销', '分销', '财务', '应用', '装修', '移动端管理')
          ) t2
        )
    ) t3
  );

-- 明确保留（写在这里是为了让后来人一眼看到哪些是"有意留着"的）
--   商品 / 订单 / 用户 / 内容 / 运营(控制台) / 设置 / 维护
--   处方管理(550) / 配送管理(553) —— 医药版新增，必须保留

-- 回滚：
-- UPDATE eb_system_menu SET is_show = 1
--  WHERE is_delte = 0
--    AND (name IN ('营销','分销','财务','应用','装修','移动端管理')
--         OR pid IN (SELECT id FROM (SELECT id FROM eb_system_menu WHERE is_delte=0 AND pid=0 AND name IN ('营销','分销','财务','应用','装修','移动端管理')) a)
--         OR pid IN (SELECT id FROM (SELECT id FROM eb_system_menu WHERE is_delte=0 AND pid IN (SELECT id FROM (SELECT id FROM eb_system_menu WHERE is_delte=0 AND pid=0 AND name IN ('营销','分销','财务','应用','装修','移动端管理')) b)) c));
