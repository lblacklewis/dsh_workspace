# 重建 StorApp 医药版首页装修（第二轮：精简结构 + 换图标/banner）
$ErrorActionPreference = "Stop"
$f = "$env:TEMP\hd.json"
$j = (Get-Content $f -Raw -Encoding UTF8) | ConvertFrom-Json

$IMG = "http://82.156.226.192/crmebimage/brand/"

# ---------- 1. 轮播搜索：换 banner ----------
$c0 = $j.value.'1772508227561000'
$banners = @(
  @{ i = "banner-1.svg"; l = "/pages/goods_cate/goods_cate" },
  @{ i = "banner-2.svg"; l = "/pages/goods/goods_list/index?cid=900&title=感冒用药" },
  @{ i = "banner-3.svg"; l = "/pages/goods/goods_list/index?cid=1400&title=维生素保健品" }
)
$sw = @()
foreach ($b in $banners) {
  $sw += [pscustomobject]@{
    img  = $IMG + $b.i
    icon = ""
    type = 0
    info = @(
      [pscustomobject]@{ max=4;   title="标题"; value=""; tips="选填，不超过4个字" }
      [pscustomobject]@{ max=100; title="链接"; value=$b.l; tips="请输入链接" }
    )
  }
}
$c0.swiperConfig.list = $sw

# ---------- 2. 导航组：换新图标 ----------
$navItems = @(
  @{n="感冒用药"; i="ic-cold.svg";     l="/pages/goods/goods_list/index?cid=900&title=感冒用药"},
  @{n="肠胃用药"; i="ic-stomach.svg";  l="/pages/goods/goods_list/index?cid=1000&title=肠胃用药"},
  @{n="皮肤用药"; i="ic-skin.svg";     l="/pages/goods/goods_list/index?cid=1100&title=皮肤用药"},
  @{n="慢病用药"; i="ic-chronic.svg";  l="/pages/goods/goods_list/index?cid=1200&title=慢病用药"},
  @{n="医疗器械"; i="ic-device.svg";   l="/pages/goods/goods_list/index?cid=1500&title=医疗器械"},
  @{n="药品分类"; i="ic-cate.svg";     l="/pages/goods_cate/goods_cate"},
  @{n="健康资讯"; i="ic-news.svg";     l="/pages/news/news_list/index"},
  @{n="健康积分"; i="ic-points.svg";   l="/pages/users/user_integral/index"},
  @{n="我的订单"; i="ic-order.svg";    l="/pages/users/order_list/index"},
  @{n="领优惠券"; i="ic-coupon.svg";   l="/pages/users/user_get_coupon/index"}
)
$c1 = $j.value.'1772508227561001'
$mlist = @()
foreach ($it in $navItems) {
  $mlist += [pscustomobject]@{
    img  = $IMG + $it.i
    show = $true
    icon = ""
    type = 0
    info = @(
      [pscustomobject]@{ max=4;   title="标题"; value=$it.n; tips="选填，不超过4个字" }
      [pscustomobject]@{ max=100; title="链接"; value=$it.l; tips="请输入链接" }
    )
  }
}
$c1.menuConfig.list = $mlist
# 图标是浅底方形，不要再叠加圆角裁切
$c1.filletImg.val  = 0
$c1.gridItemStyle.itemRadius = 0
$c1.gridItemStyle.itemBgColor = "#ffffff"

# ---------- 3. 隐藏演示营销模块 ----------
$j.value.'1772508227561002'.isHide = $true   # 热区（精选榜单/本周值得买/值得拼/HWB榜单 拼图）
$j.value.'1772508227561005'.isHide = $true   # 秒杀（演示秒杀商品）

# ---------- 4. 富文本标题 ----------
$ft = $j.value.'1772508227561008'
$ft.richText.val = '<p data-we-empty-p="" style="text-align:center;"><b><font color="#333333" size="3">————&nbsp; 为你推荐&nbsp; ————</font></b></p>'

# ---------- 5. 序列化 ----------
$out = $j | ConvertTo-Json -Depth 100 -Compress
$null = $out | ConvertFrom-Json   # 校验

Write-Host "新 JSON 长度: $($out.Length)"
Write-Host "可见组件:"
foreach ($p in ($j.value.PSObject.Properties)) {
  if ($p.Value.isHide -ne $true) { Write-Host ("  " + $p.Value.cname) }
}

$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($out))
$sql = "UPDATE eb_theme SET home_data = CONVERT(FROM_BASE64('$b64') USING utf8mb4) WHERE id = 1;"
[System.IO.File]::WriteAllText("$env:TEMP\theme_update2.sql", $sql, [System.Text.UTF8Encoding]::new($false))
Write-Host "SQL 已生成 (base64 $($b64.Length) 字符)"
