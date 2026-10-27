# 生成 StorApp 医药版图标与 banner
$ErrorActionPreference = "Stop"
$out = "D:\project\StorApp\crmeb_java\docs\brand\assets"
New-Item -ItemType Directory -Path $out -Force | Out-Null

function New-Icon($name, $inner) {
  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <rect width="48" height="48" rx="14" fill="#E6FFFA"/>
  <g stroke="#0D9488" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round">
$inner
  </g>
</svg>
"@
  [System.IO.File]::WriteAllText("$out\$name.svg", $svg, [System.Text.UTF8Encoding]::new($false))
}

# 1 感冒用药 - 胶囊
New-Icon "ic-cold" @"
    <g transform="rotate(-45 24 24)">
      <rect x="11" y="17.5" width="26" height="13" rx="6.5"/>
      <line x1="24" y1="17.5" x2="24" y2="30.5"/>
    </g>
"@

# 2 肠胃用药 - 胃
New-Icon "ic-stomach" @"
    <path d="M20 11v7c0 2.6-7.5 3.6-7.5 10.4C12.5 34.6 17 39 22.5 39S33 35.4 33 30c0-4.2-3.2-6.6-6.6-6.6"/>
    <path d="M20 11h-3.5"/>
"@

# 3 皮肤用药 - 水滴
New-Icon "ic-skin" @"
    <path d="M24 11c5.2 6.2 8.5 10 8.5 14.2A8.5 8.5 0 0 1 24 33.7a8.5 8.5 0 0 1-8.5-8.5C15.5 21 18.8 17.2 24 11z"/>
    <path d="M20.5 26.5c.6 1.6 2 2.6 3.8 2.6"/>
"@

# 4 慢病用药 - 心 + 心电
New-Icon "ic-chronic" @"
    <path d="M24 38S12.5 31 12.5 23.2A6.7 6.7 0 0 1 24 18.4a6.7 6.7 0 0 1 11.5 4.8C35.5 31 24 38 24 38z"/>
    <path d="M13 24.5h5l2-3.2 3 6.4 2-3.2h6"/>
"@

# 5 医疗器械 - 听诊器
New-Icon "ic-device" @"
    <path d="M16 11v9a6 6 0 0 0 12 0v-9"/>
    <path d="M22 26v3.5a7 7 0 0 0 7 7 7 7 0 0 0 7-7V28"/>
    <circle cx="36" cy="24.5" r="3.2"/>
"@

# 6 药品分类 - 宫格
New-Icon "ic-cate" @"
    <rect x="12" y="12" width="10" height="10" rx="3"/>
    <rect x="26" y="12" width="10" height="10" rx="3"/>
    <rect x="12" y="26" width="10" height="10" rx="3"/>
    <rect x="26" y="26" width="10" height="10" rx="3"/>
"@

# 7 健康资讯 - 文档
New-Icon "ic-news" @"
    <path d="M16.5 11h10.5l6 6v19a2 2 0 0 1-2 2h-14.5a2 2 0 0 1-2-2V13a2 2 0 0 1 2-2z"/>
    <path d="M27 11v6h6"/>
    <line x1="19" y1="24.5" x2="29" y2="24.5"/>
    <line x1="19" y1="30" x2="26" y2="30"/>
"@

# 8 健康积分 - 星
New-Icon "ic-points" @"
    <path d="M24 11.5l3.9 8.2 8.8 1.2-6.4 6.3 1.6 8.9-7.9-4.3-7.9 4.3 1.6-8.9-6.4-6.3 8.8-1.2z"/>
"@

# 9 我的订单 - 单据
New-Icon "ic-order" @"
    <rect x="13" y="14" width="22" height="24" rx="3.5"/>
    <path d="M19 14v-1.5a2.5 2.5 0 0 1 2.5-2.5h5A2.5 2.5 0 0 1 29 12.5V14"/>
    <line x1="19" y1="23.5" x2="29" y2="23.5"/>
    <line x1="19" y1="29.5" x2="26" y2="29.5"/>
"@

# 10 领优惠券 - 券
New-Icon "ic-coupon" @"
    <path d="M12 18.5a2 2 0 0 1 2-2h20a2 2 0 0 1 2 2v2.6a3.1 3.1 0 0 0 0 5.8v2.6a2 2 0 0 1-2 2H14a2 2 0 0 1-2-2v-2.6a3.1 3.1 0 0 0 0-5.8z"/>
    <line x1="21" y1="17" x2="21" y2="31" stroke-dasharray="3 3.5"/>
"@

# ---- Banner (750x320) ----
function New-Banner($name, $t1, $t2, $t3) {
  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 320" width="750" height="320">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#14B8A6"/>
      <stop offset="100%" stop-color="#0F766E"/>
    </linearGradient>
    <radialGradient id="r" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.22"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="750" height="320" fill="url(#g)"/>
  <circle cx="640" cy="60" r="170" fill="url(#r)"/>
  <circle cx="90" cy="290" r="130" fill="url(#r)"/>
  <g opacity="0.14" stroke="#FFFFFF" stroke-width="2" fill="none">
    <circle cx="628" cy="205" r="62"/>
    <circle cx="628" cy="205" r="96"/>
  </g>
  <g opacity="0.9">
    <rect x="592" y="169" width="72" height="72" rx="20" fill="#FFFFFF" opacity="0.18"/>
    <rect x="622" y="185" width="12" height="40" rx="4" fill="#FFFFFF"/>
    <rect x="608" y="199" width="40" height="12" rx="4" fill="#FFFFFF"/>
  </g>
  <text x="60" y="128" font-family="Helvetica,Arial,sans-serif" font-size="46" font-weight="700" fill="#FFFFFF">$t1</text>
  <text x="60" y="186" font-family="Helvetica,Arial,sans-serif" font-size="26" fill="#FFFFFF" opacity="0.92">$t2</text>
  <text x="60" y="232" font-family="Helvetica,Arial,sans-serif" font-size="20" fill="#FFFFFF" opacity="0.72">$t3</text>
</svg>
"@
  [System.IO.File]::WriteAllText("$out\$name.svg", $svg, [System.Text.UTF8Encoding]::new($false))
}

New-Banner "banner-1" "专业药房" "正品保障 · 药师在线" "持证经营 · 全程可追溯"
New-Banner "banner-2" "送药到家" "最快 30 分钟送达" "24 小时营业 · 夜间也可下单"
New-Banner "banner-3" "健康好物" "维生素 · 保健品 · 医疗器械" "满 99 减 20 · 会员更优惠"

$files = Get-ChildItem $out -Filter *.svg
Write-Host "生成完成: $($files.Count) 个文件"
$files | ForEach-Object { Write-Host ("  {0,-18} {1,6:N1} KB" -f $_.Name, ($_.Length/1KB)) }
