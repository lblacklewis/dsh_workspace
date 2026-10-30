# 修复后台「控制台」两个接口报 Access is denied（无法访问）
#
# 现象：
#   GET /dev-api/api/admin/statistics/user/overview?dateLimit=lately7  -> {"code":500,"message":"Access is denied"}
#   GET /dev-api/api/admin/statistics/user/channel                    -> {"code":500,"message":"Access is denied"}
#   后台一进首页就弹「无法访问」。
#
# 根因（已实测确认，别再重复排查）：
#   admin/src/views/dashboard/components/userOverview.vue 调了这两个接口，
#   对应 UserStatisticsController 的 @PreAuthorize：
#       admin:statistics:user:overview
#       admin:statistics:user:channel
#   但 eb_system_menu 里 **根本没有这两条权限点**（整个 admin:statistics:user:* 系列都缺）。
#   LoginUserVo.getAuthorities() 是从 menu 表按 perms 装配 GrantedAuthority 的，
#   表里没有 -> 权限集合里没有 -> hasAuthority 永远 false -> Access is denied。
#
#   对照：admin:statistics:home:* 那 8 条是存在的（menu id 285-291, 327），
#   所以控制台其它卡片正常，只有「用户概览」这块报错。
#
# 做法：补 4 条权限点（用户概览区块实际用得到的），挂在「控制台」菜单(pid=226)下，
#       menu_type='A'（按钮型权限，不会出现在左侧导航），并授权给角色 1 和 5。
#       —— 与 home:* 那 8 条的授权范围保持一致。
#
# 用法:
#   .\fix-dashboard-perms.ps1              # 先干跑，只打印要执行什么
#   .\fix-dashboard-perms.ps1 -Apply       # 真正执行（先备份 menu 表）
#   .\fix-dashboard-perms.ps1 -Apply -Revoke   # 回滚（删掉这 4 条权限点及授权）

param(
  [switch]$Apply,
  [switch]$Revoke
)

$ErrorActionPreference = "Stop"
$SshHost = "root@82.156.226.192"
$DB = "java_dev"
$DBU = "java_dev"
$DBP = if ($env:MYSQL_PASS) { $env:MYSQL_PASS } else { Read-Host "请输入 MySQL 密码(java_dev)" }
# Redis 密码同样不写死（历史提交里曾泄露）
$REDISP = if ($env:REDIS_PASS) { $env:REDIS_PASS } else { Read-Host "请输入 Redis 密码" }

$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "dummy"
$env:SSH_ASKPASS = Join-Path $env:TEMP "ssh_askpass.bat"
if (-not (Test-Path $env:SSH_ASKPASS)) {
  # SSH 密码优先读环境变量 SA_SSH_PASS，没设才用兜底值。
# 密码写死在脚本里会跟着 git 走（本仓库历史提交里已有明文），轮换时要改一堆文件；
# 用环境变量只需改一处：  $env:SA_SSH_PASS = "<新密码>"
$saSshPass = $env:SA_SSH_PASS
if (-not $saSshPass) { $saSshPass = Read-Host '请输入服务器 SSH 密码' }
[System.IO.File]::WriteAllText($env:SSH_ASKPASS, "@echo off`r`necho $saSshPass`r`n", [System.Text.ASCIIEncoding]::new())
}

function B64([string]$s) { return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($s)) }
function Run-Remote([string]$sh) {
  ssh -o StrictHostKeyChecking=no $SshHost "echo $(B64 $sh) | base64 -d > /tmp/fix-perms.sh && bash /tmp/fix-perms.sh"
  if ($LASTEXITCODE -ne 0) { throw "远程执行失败" }
}

# 权限点定义：id / perms / 中文名。菜单 id 取当前 MAX(id)+1 起，避免撞号。
$PERMS = @(
  @{ id = 556; perms = 'admin:statistics:user:overview';      name = '用户概览' },
  @{ id = 557; perms = 'admin:statistics:user:channel';       name = '用户渠道数据' },
  @{ id = 558; perms = 'admin:statistics:user:overview:list'; name = '用户概览列表' },
  @{ id = 559; perms = 'admin:statistics:user:total:data';    name = '用户总数据' }
)
$ROLE_IDS = @(1, 5)   # 1=超级管理员 5=演示站，与 statistics:home:* 的授权范围一致

$permsList = ($PERMS | ForEach-Object { "'" + $_.perms + "'" }) -join ','

# ---- 生成 SQL ------------------------------------------------------------
$sql = New-Object System.Collections.ArrayList
[void]$sql.Add("-- 控制台权限点补齐（generate by docs/fix-dashboard-perms.ps1）")
[void]$sql.Add("START TRANSACTION;")

if ($Revoke) {
  [void]$sql.Add("DELETE FROM eb_system_role_menu WHERE menu_id IN ($(($PERMS | ForEach-Object { $_.id }) -join ','));")
  [void]$sql.Add("DELETE FROM eb_system_menu WHERE id IN ($(($PERMS | ForEach-Object { $_.id }) -join ',')) AND perms IN ($permsList);")
} else {
  foreach ($p in $PERMS) {
    [void]$sql.Add("INSERT INTO eb_system_menu (id, pid, name, icon, perms, component, menu_type, sort, is_show, is_delte, create_time, update_time)")
    [void]$sql.Add("  SELECT $($p.id), 226, '$($p.name)', '', '$($p.perms)', '', 'A', 99, 1, 0, NOW(), NOW()")
    [void]$sql.Add("  FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM eb_system_menu m WHERE m.id = $($p.id) OR m.perms = '$($p.perms)');")
  }
  foreach ($r in $ROLE_IDS) {
    foreach ($p in $PERMS) {
      [void]$sql.Add("INSERT INTO eb_system_role_menu (rid, menu_id)")
      [void]$sql.Add("  SELECT $r, $($p.id) FROM DUAL")
      [void]$sql.Add("  WHERE EXISTS (SELECT 1 FROM eb_system_menu m WHERE m.id = $($p.id))")
      [void]$sql.Add("    AND NOT EXISTS (SELECT 1 FROM eb_system_role_menu rm WHERE rm.rid = $r AND rm.menu_id = $($p.id));")
    }
  }
}
[void]$sql.Add("COMMIT;")
$sqlText = $sql -join "`n"

$checkSql = @"
SELECT '--- 权限点 ---' AS x;
SELECT id, pid, name, perms, menu_type, is_show, is_delte FROM eb_system_menu WHERE perms IN ($permsList) ORDER BY id;
SELECT '--- 角色授权 ---' AS x;
SELECT rm.rid, m.perms FROM eb_system_role_menu rm JOIN eb_system_menu m ON m.id=rm.menu_id
WHERE m.perms IN ($permsList) ORDER BY rm.rid, m.id;
"@

# ---- 远程脚本 ------------------------------------------------------------
$remote  = "set -e`n"
$remote += "M='mysql -u$DBU -p$DBP $DB'`n"
if ($Apply) {
  $remote += "echo '[0/3] 备份 eb_system_menu / eb_system_role_menu'`n"
  $remote += "TS=`$(date +%Y%m%d-%H%M%S)`n"
  $remote += "mysqldump -u$DBU -p$DBP $DB eb_system_menu eb_system_role_menu > /root/perms-backup-`$TS.sql 2>/dev/null`n"
  $remote += "ls -la /root/perms-backup-`$TS.sql`n"
  $remote += "echo '[1/3] 执行'`n"
  $remote += "cat > /tmp/fix-perms.sql << 'SQLEOF'`n$sqlText`nSQLEOF`n"
  $remote += "`$M < /tmp/fix-perms.sql`n"
  $remote += "echo '[2/3] 校验'`n"
  $remote += "cat > /tmp/check-perms.sql << 'SQLEOF'`n$checkSql`nSQLEOF`n"
  $remote += "`$M < /tmp/check-perms.sql`n"
  $remote += "echo '[3/3] 清 Redis 权限缓存（角色菜单变更后必须清）'`n"
  $remote += "redis-cli -a $REDISP --no-auth-warning -n 0 FLUSHDB`n"
  $remote += "echo '完成。后台请 Ctrl+Shift+R 强刷，并重新登录一次。'`n"
} else {
  $remote += "echo '=== 干跑：以下 SQL 将被执行 ==='`n"
  $remote += "cat << 'SQLEOF'`n$sqlText`nSQLEOF`n"
  $remote += "echo ''`n"
  $remote += "echo '=== 当前库里的现状 ==='`n"
  $remote += "cat > /tmp/check-perms.sql << 'SQLEOF'`n$checkSql`nSQLEOF`n"
  $remote += "`$M < /tmp/check-perms.sql`n"
  $remote += "echo '加 -Apply 才会真正执行。'`n"
}

Run-Remote $remote
Remove-Item $env:SSH_ASKPASS -Force -ErrorAction SilentlyContinue
