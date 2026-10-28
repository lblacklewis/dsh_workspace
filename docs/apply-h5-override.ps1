# 原子化注入 H5 覆盖样式到服务器 /var/www/storapp/h5/index.html
#
# ⚠️ 为什么必须原子写：
#   nginx 用 pread() 读静态文件。如果直接原地覆盖写（open(...,'w') 先截断再写），
#   写入窗口内访问站点的用户会拿到「截断的 HTML」——浏览器收到半截页面 -> 白屏。
#   日志特征：[alert] pread() read only N of M from ".../index.html" while sending response
#   正确做法：写临时文件 -> os.replace（同文件系统内是原子的）。
#
# 用法:
#   .\apply-h5-override.ps1            # 注入 docs/h5-override.css
#   .\apply-h5-override.ps1 -Revert    # 移除覆盖样式
param([switch]$Revert)

$ErrorActionPreference = "Stop"
$SshHost = "root@82.156.226.192"
$CssFile = Join-Path $PSScriptRoot "h5-override.css"

$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "dummy"
$env:SSH_ASKPASS = "$env:TEMP\ssh_askpass.bat"
if (-not (Test-Path $env:SSH_ASKPASS)) {
  "@echo off`r`necho ofs;123" | Out-File $env:SSH_ASKPASS -Encoding ASCII
}

if ($Revert) {
  Write-Host "[1/2] 移除覆盖样式（原子写）"
  $remote = @'
F=/var/www/storapp/h5/index.html
python3 - "$F" << 'PYEOF'
import sys, re, io, os
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
s = re.sub(r'<style id="storapp-override">.*?</style>', '', s, flags=re.S)
tmp = p + '.tmp'
io.open(tmp, 'w', encoding='utf-8').write(s)
os.replace(tmp, p)
print('  已移除，%d 字节' % len(s))
PYEOF
'@
} else {
  if (-not (Test-Path $CssFile)) { throw "找不到 $CssFile" }
  $css = [System.IO.File]::ReadAllText($CssFile, [System.Text.UTF8Encoding]::new($false))
  if ($css -notmatch 'page-footer') { throw "h5-override.css 内容异常：缺少 page-footer 规则" }
  # CSS 走 base64，避免引号/换行被 ssh 吞掉
  $cssB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($css))
  Write-Host ("[1/2] 注入覆盖样式（" + $css.Length + " 字符，原子写）")
  $remote = @"
F=/var/www/storapp/h5/index.html
echo '$cssB64' | base64 -d > /tmp/override.css
python3 - "`$F" << 'PYEOF'
import sys, re, io, os
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
css = io.open('/tmp/override.css', encoding='utf-8').read()
s = re.sub(r'<style id="storapp-override">.*?</style>', '', s, flags=re.S)
s = s.replace('</head>', '<style id="storapp-override">' + css + '</style></head>', 1)
tmp = p + '.tmp'
io.open(tmp, 'w', encoding='utf-8').write(s)
os.replace(tmp, p)          # 原子替换，nginx 不会读到半截文件
print('  已注入，%d 字节' % len(s))
PYEOF
"@
}

$rb64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($remote))
ssh -o StrictHostKeyChecking=no $SshHost "echo $rb64 | base64 -d | bash"

Write-Host "[2/2] 校验"
$check = @'
# ⚠️ 必须 reload：open_file_cache 按 inode 缓存文件句柄，原子替换后 inode 变了，
#    不 reload 的话 nginx 会继续发旧内容（原配置 valid 120s）。
#    已把 /etc/nginx/conf.d/performance.conf 的 valid/inactive 压到 5s 兜底。
systemctl reload nginx
sleep 1
F=/var/www/storapp/h5/index.html
echo -n "  磁盘文件: "; wc -c < $F
echo -n "  nginx 返回: "; curl -s --compressed http://127.0.0.1:8092/ | wc -c
echo -n "  style 标签数: "; grep -o '<style' $F | wc -l
echo -n "  含覆盖样式: "; grep -c 'storapp-override' $F
echo -n "  连续 10 次一致性: "
want=$(wc -c < $F)
ok=0; bad=0
for i in $(seq 1 10); do
  n=$(curl -s --compressed --max-time 8 http://127.0.0.1:8092/ | wc -c)
  if [ "$n" -eq "$want" ]; then ok=$((ok+1)); else bad=$((bad+1)); fi
done
echo "一致 $ok / 不一致 $bad"
'@
$cb64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($check))
ssh -o StrictHostKeyChecking=no $SshHost "echo $cb64 | base64 -d | bash"
Remove-Item "$env:TEMP\ssh_askpass.bat" -Force -ErrorAction SilentlyContinue
Write-Host "完成。刷新 H5 请用 Ctrl+Shift+R。"
