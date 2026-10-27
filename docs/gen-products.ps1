# 生成 StorApp 药品商品图 + 商品数据 SQL
$ErrorActionPreference = "Stop"
$root = "D:\project\StorApp\crmeb_java"
$dir  = "$root\docs\brand\products"
New-Item -ItemType Directory -Path $dir -Force | Out-Null

# id, 名称, 规格, 分类id, 售价, 原价, 成本, 库存, 关键词, 单位, 卖点
$products = @(
  @{ id=101; n="感冒灵颗粒";     s="10袋/盒";     c=900;  p=18.80;  o=26.00;  cost=9.50;  st=500; k="感冒 发烧 头痛";    u="盒"; info="清热解毒，用于感冒引起的头痛发热" },
  @{ id=159; n="布洛芬缓释胶囊"; s="0.3g*20粒";   c=900;  p=22.50;  o=29.90;  cost=11.00; st=300; k="退烧 止痛 布洛芬"; u="盒"; info="缓解轻至中度疼痛，退热" },
  @{ id=167; n="健胃消食片";     s="0.8g*32片";   c=1000; p=15.90;  o=21.00;  cost=7.80;  st=420; k="消化不良 健胃";   u="盒"; info="健胃消食，用于脾胃虚弱所致的食积" },
  @{ id=168; n="蒙脱石散";       s="3g*10袋";     c=1000; p=26.00;  o=33.00;  cost=13.00; st=260; k="止泻 腹泻";       u="盒"; info="用于成人及儿童急、慢性腹泻" },
  @{ id=170; n="维生素C咀嚼片";  s="100片/瓶";    c=1400; p=39.90;  o=52.00;  cost=19.00; st=380; k="维生素C 补充";    u="瓶"; info="补充维生素C，增强免疫力" },
  @{ id=100; n="电子血压计";     s="上臂式 家用";  c=1500; p=199.00; o=259.00; cost=118.00; st=120; k="血压计 家用";    u="台"; info="上臂式电子血压计，一键测量，语音播报" },
  @{ id=102; n="云南白药创可贴"; s="100片/盒";    c=1900; p=12.50;  o=16.80;  cost=6.20;  st=600; k="创可贴 止血";    u="盒"; info="止血镇痛，消炎愈创，家庭常备" }
)

foreach ($p in $products) {
  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">
  <defs>
    <linearGradient id="h" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#14B8A6"/>
      <stop offset="100%" stop-color="#0D9488"/>
    </linearGradient>
  </defs>
  <rect width="800" height="800" fill="#F1F5F9"/>
  <rect x="170" y="250" width="460" height="320" rx="22" fill="#FFFFFF" stroke="#E2E8F0" stroke-width="3"/>
  <path d="M170 272a22 22 0 0 1 22-22h416a22 22 0 0 1 22 22v88H170z" fill="url(#h)"/>
  <text x="400" y="318" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="24" fill="#FFFFFF" opacity="0.9" letter-spacing="6">StorApp 健康药房</text>
  <rect x="612" y="176" width="96" height="96" rx="14" fill="#0D9488"/>
  <text x="660" y="238" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="30" font-weight="700" fill="#FFFFFF">OTC</text>
  <text x="400" y="428" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="46" font-weight="700" fill="#0F172A">$($p.n)</text>
  <text x="400" y="478" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="26" fill="#64748B">$($p.s)</text>
  <rect x="352" y="516" width="96" height="26" rx="13" fill="#E6FFFA"/>
  <text x="400" y="535" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="16" fill="#0D9488" letter-spacing="2">正品保障</text>
  <g transform="translate(348,614)">
    <rect width="104" height="104" rx="26" fill="#E6FFFA"/>
    <rect x="44" y="24" width="16" height="56" rx="6" fill="#0D9488"/>
    <rect x="24" y="44" width="56" height="16" rx="6" fill="#0D9488"/>
  </g>
</svg>
"@
  [System.IO.File]::WriteAllText("$dir\p$($p.id).svg", $svg, [System.Text.UTF8Encoding]::new($false))
}

Write-Host "商品图生成: $((Get-ChildItem $dir -Filter *.svg).Count) 个"

# ---- 生成 SQL ----
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- StorApp 药品商品数据")
[void]$sb.AppendLine("SET NAMES utf8mb4;")
[void]$sb.AppendLine("DELETE FROM eb_store_product_cate;")
foreach ($p in $products) {
  $img = "crmebimage/brand/products/p$($p.id).svg"
  $slider = '["' + $img + '"]'
  [void]$sb.AppendLine("UPDATE eb_store_product SET")
  [void]$sb.AppendLine("  store_name='$($p.n)', keyword='$($p.k)', cate_id='$($p.c)',")
  [void]$sb.AppendLine("  price=$($p.p), ot_price=$($p.o), cost=$($p.cost), stock=$($p.st),")
  [void]$sb.AppendLine("  unit_name='$($p.u)', store_info='$($p.info)',")
  [void]$sb.AppendLine("  image='$img', slider_image='$slider',")
  [void]$sb.AppendLine("  is_show=1, is_del=0, is_best=1, is_new=1, is_hot=1, spec_type=0")
  [void]$sb.AppendLine("WHERE id=$($p.id);")
  [void]$sb.AppendLine("INSERT INTO eb_store_product_cate (product_id, cate_id, add_time) VALUES ($($p.id), $($p.c), UNIX_TIMESTAMP());")
}
# 下架未改造的其它演示商品
[void]$sb.AppendLine("UPDATE eb_store_product SET is_show=0 WHERE id NOT IN (101,159,167,168,170,100,102);")
[void]$sb.AppendLine("SELECT CONCAT('药品商品: ', COUNT(*)) AS r FROM eb_store_product WHERE is_show=1 AND is_del=0;")

$sql = $sb.ToString()
[System.IO.File]::WriteAllText("$root\docs\药品商品数据.sql", $sql, [System.Text.UTF8Encoding]::new($false))
Write-Host "SQL 已生成: docs\药品商品数据.sql ($($sql.Length) 字符)"
