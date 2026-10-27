# 第三轮装修修正：替换 CRMEB logo 浮层
$ErrorActionPreference = "Stop"
$j = (Get-Content "$env:TEMP\hd.json" -Raw -Encoding UTF8) | ConvertFrom-Json

$LOGO = "http://82.156.226.192/crmebimage/brand/logo-storapp-white.svg"

# 轮播搜索里的两处 CRMEB logo
$c0 = $j.value.'1772508227561000'
$c0.logoConfig.url   = $LOGO
$c0.logoUpConfig.url = $LOGO
# 搜索框用文字，避免 logo 重复显示
$c0.searchBox.tabVal = 0
# 关闭顶部固定 logo（首页顶部已有 banner）
$c0.logoUpConfig.url = ""

# 富文本标题保持
$out = $j | ConvertTo-Json -Depth 100 -Compress
$null = $out | ConvertFrom-Json

Write-Host "logoConfig.url   = $($c0.logoConfig.url)"
Write-Host "logoUpConfig.url = '$($c0.logoUpConfig.url)'"
Write-Host "searchBox.tabVal = $($c0.searchBox.tabVal)"

$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($out))
$sql = "UPDATE eb_theme SET home_data = CONVERT(FROM_BASE64('$b64') USING utf8mb4) WHERE id = 1;"
[System.IO.File]::WriteAllText("$env:TEMP\theme_update3.sql", $sql, [System.Text.UTF8Encoding]::new($false))
Write-Host "SQL 已生成"
