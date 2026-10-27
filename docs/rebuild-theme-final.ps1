# StorApp 医药版首页装修 —— 最终合并版（图标/banner/结构/logo 一次到位）
$ErrorActionPreference = "Stop"
$src = "$env:TEMP\hd2.json"
$j = (Get-Content $src -Raw -Encoding UTF8) | ConvertFrom-Json

$IMG = "http://82.156.226.192/crmebimage/brand/"

# ---------- 1. 轮播 banner ----------
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
$c0.inputConfig.value = "搜索药品、症状、品牌"
# 去掉 CRMEB logo 浮层
$c0.logoConfig.url    = $IMG + "logo-storapp-white.svg"
$c0.logoUpConfig.url  = ""
$c0.searchBox.tabVal  = 0

# ---------- 2. 金刚区 ----------
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
$c1.filletImg.val   = 0
$c1.gridItemStyle.itemRadius  = 0
$c1.gridItemStyle.itemBgColor = "#ffffff"
$c1.rowsNum.tabVal  = 1
$c1.number.tabVal   = 2

# ---------- 3. 隐藏演示营销模块 ----------
$j.value.'1772508227561002'.isHide = $true   # 热区
$j.value.'1772508227561004'.isHide = $true   # 拼团
$j.value.'1772508227561005'.isHide = $true   # 秒杀
$j.value.'1772508227561006'.isHide = $true   # 砍价

# ---------- 4. 富文本 ----------
$j.value.'1772508227561008'.richText.val = '<p data-we-empty-p="" style="text-align:center;"><b><font color="#333333" size="3">————&nbsp; 为你推荐&nbsp; ————</font></b></p>'

# ---------- 5. 商品选项卡副标题 ----------
$subs = @("正品保障","退烧止痛","健胃消食","家用常备")
$k = 0
foreach ($t in $j.value.'1772508227561007'.tabConfig.list) {
  if ($k -lt $subs.Count) { $t.chiild[1].val = $subs[$k] }
  $k++
}

# ---------- 序列化 ----------
$out = $j | ConvertTo-Json -Depth 100 -Compress
$null = $out | ConvertFrom-Json

# ---------- 应用前校验 ----------
$checks = @{
  "新图标 ic-cold"    = $out -match "ic-cold\.svg"
  "无旧图标"          = -not ($out -match "respiratory\.svg")
  "新 banner-1"       = $out -match "banner-1\.svg"
  "无旧 banner 3_"    = -not ($out -match "images/3_5ed09dd2")
  "热区已隐藏"        = ($j.value.'1772508227561002'.isHide -eq $true)
  "秒杀已隐藏"        = ($j.value.'1772508227561005'.isHide -eq $true)
  "拼团已隐藏"        = ($j.value.'1772508227561004'.isHide -eq $true)
  "砍价已隐藏"        = ($j.value.'1772508227561006'.isHide -eq $true)
  "无 CRMEB logo 1_"  = -not ($out -match "1_5d7ac2fad9a59e16084b1460c4fd62a4")
  "白色 logo"         = $out -match "logo-storapp-white\.svg"
  "为你推荐"          = $out -match "为你推荐"
  "搜索词"            = $out -match "搜索药品、症状、品牌"
}
Write-Host "=== 应用前校验 ==="
$fail = 0
foreach ($k2 in $checks.Keys) {
  $ok = $checks[$k2]
  if (-not $ok) { $fail++ }
  Write-Host ("  {0} {1}" -f $(if ($ok) { "[OK]" } else { "[!!]" }), $k2)
}

Write-Host ""
Write-Host "可见组件:"
foreach ($p in $j.value.PSObject.Properties) {
  if ($p.Value.isHide -ne $true) { Write-Host ("  " + $p.Value.cname) }
}

if ($fail -gt 0) { throw "校验未通过 ($fail 项)，已中止" }

$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($out))
$sql = "UPDATE eb_theme SET home_data = CONVERT(FROM_BASE64('$b64') USING utf8mb4) WHERE id = 1;"
[System.IO.File]::WriteAllText("$env:TEMP\theme_final.sql", $sql, [System.Text.UTF8Encoding]::new($false))
Write-Host ""
Write-Host "SQL 已生成 (base64 $($b64.Length) 字符)"
