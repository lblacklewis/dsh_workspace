# 修正首页顶部 logo：白色版在白底不可见 -> 换彩色版
$ErrorActionPreference = "Stop"
$j = (Get-Content "$env:TEMP\hd3.json" -Raw -Encoding UTF8) | ConvertFrom-Json

$COLOR = "http://82.156.226.192/crmebimage/brand/logo-storapp.svg"
$c0 = $j.value.'1772508227561000'
$c0.logoConfig.url   = $COLOR
$c0.logoUpConfig.url = ""
Write-Host "logoConfig.url = $COLOR"

$out = $j | ConvertTo-Json -Depth 100 -Compress
$null = $out | ConvertFrom-Json
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($out))
[System.IO.File]::WriteAllText("$env:TEMP\theme_logo.sql", "UPDATE eb_theme SET home_data = CONVERT(FROM_BASE64('$b64') USING utf8mb4) WHERE id = 1;", [System.Text.UTF8Encoding]::new($false))
Write-Host "SQL 已生成"
