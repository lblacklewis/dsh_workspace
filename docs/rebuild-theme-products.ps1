# 把首页装修里嵌入的旧演示商品替换为药品商品
$ErrorActionPreference = "Stop"
$j = (Get-Content "$env:TEMP\hd3.json" -Raw -Encoding UTF8) | ConvertFrom-Json

# 药品商品数据
$P = @(
  @{ id=101; n="感冒灵颗粒";     c=900;  cn="感冒用药";       p=18.80;  o=26.00;  cost=9.50;   st=500; u="盒"; k="感冒 发烧 头痛";    f=326 },
  @{ id=159; n="布洛芬缓释胶囊"; c=900;  cn="感冒用药";       p=22.50;  o=29.90;  cost=11.00;  st=300; u="盒"; k="退烧 止痛";        f=218 },
  @{ id=167; n="健胃消食片";     c=1000; cn="肠胃用药";       p=15.90;  o=21.00;  cost=7.80;   st=420; u="盒"; k="消化不良 健胃";    f=415 },
  @{ id=168; n="蒙脱石散";       c=1000; cn="肠胃用药";       p=26.00;  o=33.00;  cost=13.00;  st=260; u="盒"; k="止泻 腹泻";        f=173 },
  @{ id=170; n="维生素C咀嚼片";  c=1400; cn="维生素/保健品";  p=39.90;  o=52.00;  cost=19.00;  st=380; u="瓶"; k="维生素C 免疫";     f=289 },
  @{ id=100; n="电子血压计";     c=1500; cn="医疗器械";       p=199.00; o=259.00; cost=118.00; st=120; u="台"; k="血压计 家用";      f=96  },
  @{ id=102; n="云南白药创可贴"; c=1900; cn="家庭常备";       p=12.50;  o=16.80;  cost=6.20;   st=600; u="盒"; k="创可贴 止血";      f=537 }
)

# 模板：取第一个嵌入商品，克隆后改字段
$gt = $j.value.'1772508227561007'
$tpl = @($gt.tabConfig.list[0].goodsList.list)[0]

function New-Prod($p) {
  $o = $tpl | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
  $img = "crmebimage/brand/products/p$($p.id).svg"
  $o.id           = $p.id
  $o.store_name   = $p.n
  $o.cate_id      = $p.c
  $o.cate_name    = $p.cn
  $o.keyword      = $p.k
  $o.price        = $p.p
  $o.product_price = ('{0:N2}' -f $p.p)
  $o.ot_price     = $p.o
  $o.cost         = $p.cost
  $o.stock        = $p.st
  $o.unit_name    = $p.u
  $o.image        = "/" + $img
  $o.slider_image = @($img)
  $o.spec_type    = 0
  $o.is_show      = 1
  $o.is_del       = 0
  $o.is_best      = 1
  $o.is_new       = 1
  $o.is_hot       = 1
  $o.ficti        = $p.f
  $o.sales        = 0
  $o.vip_price    = 0
  $o.store_info   = ""
  return $o
}

$all = @(); foreach ($p in $P) { $all += (New-Prod $p) }
function Pick($ids) { $r = @(); foreach ($i in $ids) { $r += ($all | Where-Object { $_.id -eq $i }) }; return $r }

# ---- 商品选项卡 ----
$tabs = $gt.tabConfig.list
$tabs[0].goodsList.list = $all                       # 热销药品：全部
$tabs[1].goodsList.list = Pick @(101,159)            # 感冒用药
$tabs[2].goodsList.list = Pick @(167,168)            # 肠胃用药
$tabs[3].goodsList.list = Pick @(100)                # 医疗器械

# ---- 商品列表（为你推荐）----
$gl = $j.value.'1772508227561009'
$gl.goodsList.list = $all
$gl.numberConfig.val = 4

# ---- 序列化 + 校验 ----
$out = $j | ConvertTo-Json -Depth 100 -Compress
$null = $out | ConvertFrom-Json

$checks = @{
  "含 感冒灵颗粒"       = $out -match "感冒灵颗粒"
  "含 电子血压计"       = $out -match "电子血压计"
  "含 维生素C咀嚼片"    = $out -match "维生素C咀嚼片"
  "无 蓝牙音乐手表"     = -not ($out -match "蓝牙音乐手表")
  "无 Xiaomi"           = -not ($out -match "Xiaomi Civi")
  "无 ipad"             = -not ($out -match "iPad mini")
  "新图标仍在"          = $out -match "ic-cold\.svg"
  "新banner仍在"        = $out -match "banner-1\.svg"
  "热区仍隐藏"          = ($j.value.'1772508227561002'.isHide -eq $true)
}
Write-Host "=== 校验 ==="
$fail = 0
foreach ($c in $checks.Keys) { $ok = $checks[$c]; if (-not $ok) { $fail++ }; Write-Host ("  {0} {1}" -f $(if ($ok) { "[OK]" } else { "[!!]" }), $c) }
if ($fail -gt 0) { throw "校验未通过 $fail 项" }

$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($out))
[System.IO.File]::WriteAllText("$env:TEMP\theme_products.sql", "UPDATE eb_theme SET home_data = CONVERT(FROM_BASE64('$b64') USING utf8mb4) WHERE id = 1;", [System.Text.UTF8Encoding]::new($false))
Write-Host ""
Write-Host "SQL 已生成"
Write-Host ("  热销药品 tab: " + $tabs[0].goodsList.list.Count + " 个")
Write-Host ("  感冒用药 tab: " + $tabs[1].goodsList.list.Count + " 个")
Write-Host ("  肠胃用药 tab: " + $tabs[2].goodsList.list.Count + " 个")
Write-Host ("  医疗器械 tab: " + $tabs[3].goodsList.list.Count + " 个")
Write-Host ("  为你推荐:     " + $gl.goodsList.list.Count + " 个")
