# 一键恢复首页装修（把 docs/首页装修_最终版.sql 写回 eb_theme）
#
# 背景：2026-10-27 17:43 首页装修数据被还原成了 CRMEB 默认模板
#       （eb_theme.home_data 被 home_default_data 覆盖），
#       表现为：首页变回「FUN PARADISE 动物园 banner + 彩色秒杀/拼团金刚区」，
#       底部也跟着变回演示样式。
#
# 用法：
#   .\restore-theme.ps1                      # 只生成本地 SQL，不动服务器
#   .\restore-theme.ps1 -Apply               # 生成并直接应用到服务器
#   .\restore-theme.ps1 -Apply -SshHost root@1.2.3.4
param(
  [switch]$Apply,
  [string]$SshHost = "root@82.156.226.192",
  [string]$MysqlUser = "java_dev",
  [string]$MysqlPass = $(if($env:MYSQL_PASS){$env:MYSQL_PASS}else{"‹环境变量 MYSQL_PASS›"}),
  [string]$MysqlDb = "java_dev",
  [string]$RedisPass = $(if($env:REDIS_PASS){$env:REDIS_PASS}else{"‹环境变量 REDIS_PASS›"})
)
$ErrorActionPreference = "Stop"

$sqlPath = Join-Path $PSScriptRoot "首页装修_最终版.sql"
if (-not (Test-Path $sqlPath)) { throw "找不到 $sqlPath" }

$sql = [System.IO.File]::ReadAllText($sqlPath, [System.Text.UTF8Encoding]::new($false))

# 本地校验：base64 能解出合法 JSON，且带医药版标记
$b64 = [regex]::Match($sql, "FROM_BASE64\('([^']+)'\)").Groups[1].Value
if (-not $b64) { throw "SQL 里没找到 FROM_BASE64(...)" }
$json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
$null = $json | ConvertFrom-Json
foreach ($mark in @("ic-cold", "banner-1", "感冒灵")) {
  if ($json -notmatch [regex]::Escape($mark)) { throw "备份内容异常：缺少标记 $mark" }
}
if ($json -match "限时秒杀") { throw "备份内容异常：仍是 CRMEB 默认模板" }
# 必须同时写 home_default_data，否则后台点一次「恢复默认」就会把装修覆盖回去
# （2026-10-27 17:43 那次事故就是这个机制，2026-10-28 15:15 又复现了一次）
if ($sql -notmatch "home_default_data") { throw "SQL 异常：没有同时写 home_default_data，点「恢复默认」会再次被覆盖" }
Write-Host "本地校验通过：$($json.Length) 字符，含医药版图标 / banner / 药品商品（home_data + home_default_data 同时写）"

if (-not $Apply) {
  Write-Host ""
  Write-Host "未加 -Apply，仅校验。要应用请执行："
  Write-Host "  .\restore-theme.ps1 -Apply"
  return
}

$out = Join-Path $env:TEMP "restore-theme.sql"
[System.IO.File]::WriteAllText($out, $sql, [System.Text.UTF8Encoding]::new($false))
Write-Host "已写出 $out"
Write-Host "上传并应用..."
scp -o StrictHostKeyChecking=no $out "${SshHost}:/tmp/restore-theme.sql"

$remote = @"
mysql -u$MysqlUser -p$MysqlPass $MysqlDb < /tmp/restore-theme.sql 2>&1 | grep -v 'Using a password'
# 主题色单独存在 theme_data 里（不是 home_data），改了 home_data 也要同步改它，
# 否则前端 --view-theme 还是别的颜色。
# 注意：这里必须「直接赋值」，不能用「把 #E93323 替换成 #0D9488」的写法 ——
#       换成主题商城的主题后 theme_data 会是别的颜色（如生鲜主题的 #057748），
#       替换模式匹配不上就静默失败了。
mysql -u$MysqlUser -p$MysqlPass $MysqlDb -e "UPDATE eb_theme SET theme_data = '{\"theme_color\":\"#0D9488\",\"gradient_color\":\"#14B8A6\",\"sub_color\":\"#0D9488\",\"light_color\":\"rgba(13, 148, 136, 0.1)\"}', theme_default_data = '{\"theme_color\":\"#0D9488\",\"gradient_color\":\"#14B8A6\",\"sub_color\":\"#0D9488\",\"light_color\":\"rgba(13, 148, 136, 0.1)\"}', title = 'StorApp 健康药房' WHERE id = 1;" 2>&1 | grep -v 'Using a password'
redis-cli -a $RedisPass --no-auth-warning -n 10 FLUSHDB >/dev/null 2>&1
redis-cli -a $RedisPass --no-auth-warning -n 0  FLUSHDB >/dev/null 2>&1
mysql -u$MysqlUser -p$MysqlPass -N -e "SELECT CONCAT('  home ic-cold=',IF(home_data LIKE '%ic-cold%','Y','N'),'  感冒灵=',IF(home_data LIKE '%感冒灵%','Y','N'),'  限时秒杀=',IF(home_data LIKE '%限时秒杀%','Y','N'),'  nav图标=',IF(home_data LIKE '%nav-home-on%','Y','N')) FROM eb_theme WHERE id=1" $MysqlDb 2>/dev/null
mysql -u$MysqlUser -p$MysqlPass -N -e "SELECT CONCAT('  theme_color=',theme_data) FROM eb_theme WHERE id=1" $MysqlDb 2>/dev/null
"@
# 远端脚本用 base64 传，避免引号在 PowerShell -> ssh -> bash 之间被吞
$rb64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($remote))
ssh -o StrictHostKeyChecking=no $SshHost "echo $rb64 | base64 -d | bash"
Write-Host "恢复完成，刷新 H5 即可（建议 Ctrl+Shift+R）"
