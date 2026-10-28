# 把主题商城的「生鲜主题 · 社群」导入 eb_theme
$ErrorActionPreference = "Stop"
$dst = "$env:TEMP\newtheme"
$BASE = "http://82.156.226.192/crmebimage/theme/download/images/"

$cfg = [System.IO.File]::ReadAllText("$dst\config.json", [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json

# 把 home_data / user_data / detail_data 里的 images/xxx 改写成服务器绝对 URL
$re = 'images\\/([A-Za-z0-9_\-.]+\.(?:png|jpg|jpeg|gif|svg))'
$eval = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $BASE + $m.Groups[1].Value }

$fields = @{
  home_data          = $cfg.home_data
  home_default_data  = $cfg.home_default_data
  detail_data        = $cfg.detail_data
  detail_default_data= $cfg.detail_default_data
  user_data          = $cfg.user_data
  user_default_data  = $cfg.user_default_data
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("SET NAMES utf8mb4;")
foreach ($k in $fields.Keys) {
  $orig = $fields[$k]
  if ([string]::IsNullOrEmpty($orig)) { Write-Host ("  {0,-20} 空，跳过" -f $k); continue }
  $new = [regex]::Replace($orig, $re, $eval)
  # 校验解出来仍是合法 JSON
  $null = $new | ConvertFrom-Json
  $n = ([regex]::Matches($new, [regex]::Escape($BASE))).Count
  $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($new))
  [void]$sb.AppendLine("UPDATE eb_theme SET $k = CONVERT(FROM_BASE64('$b64') USING utf8mb4) WHERE id = 1;")
  Write-Host ("  {0,-20} {1,8:N0} 字符 -> 改写 {2,3} 处 URL, base64 {3,7:N0}" -f $k, $orig.Length, $n, $b64.Length)
}

# theme_data（颜色）
$td = $cfg.theme_data | ConvertTo-Json -Compress -Depth 5
$tdB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($td))
[void]$sb.AppendLine("UPDATE eb_theme SET theme_data = CONVERT(FROM_BASE64('$tdB64') USING utf8mb4) WHERE id = 1;")
[void]$sb.AppendLine("UPDATE eb_theme SET theme_default_data = CONVERT(FROM_BASE64('$tdB64') USING utf8mb4) WHERE id = 1;")
Write-Host ("  theme_data           $td")

# 其它字段
[void]$sb.AppendLine("UPDATE eb_theme SET title = '生鲜主题 · 社群', home_image = 'theme/download/1_home_image.png', is_use = 1, is_del = 0, up_time = NOW() WHERE id = 1;")
[void]$sb.AppendLine("SELECT CONCAT('导入完成: home_data=', CHAR_LENGTH(home_data), ' theme_color=', theme_data) AS r FROM eb_theme WHERE id = 1;")

$sql = $sb.ToString()
[System.IO.File]::WriteAllText("$env:TEMP\import-theme.sql", $sql, [System.Text.UTF8Encoding]::new($false))
Write-Host ""
Write-Host ("SQL 生成完毕: " + [math]::Round($sql.Length/1MB, 2) + " MB")
