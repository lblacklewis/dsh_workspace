# 原子化注入 H5 样式到服务器 /var/www/storapp/h5/index.html
#
# 注入三样东西（都在 head 结束标签之前）：
#   1. <link rel="stylesheet" href="/static/index.css">   uni-app 的 H5 基础样式（必须）
#   2. <style id="storapp-override">  h5-override.css     功能修复层
#   3. <style id="storapp-modern">    h5-modern.css       视觉设计层（换风格只改这个）
#
# ⚠️ 为什么必须原子写：
#   nginx 用 pread() 读静态文件。原地覆盖写（open(...,'w') 先截断再写）时，
#   写入窗口内访问站点的用户会拿到截断的 HTML -> 白屏。
#   日志特征：[alert] pread() read only N of M from ".../index.html" while sending response
#   所以：写临时文件 -> os.replace（同文件系统内原子）。
#
# ⚠️ 为什么要 reload nginx：
#   open_file_cache 按 inode 缓存句柄。原子替换后 inode 变了，不 reload 的话
#   nginx 会继续发旧内容（原配置 valid 120s，现已压到 5s 兜底）。
#
# 用法:
#   .\apply-h5-override.ps1            # 注入
#   .\apply-h5-override.ps1 -Revert    # 移除全部注入
param([switch]$Revert)

$ErrorActionPreference = "Stop"
$SshHost = "root@82.156.226.192"

$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "dummy"
$env:SSH_ASKPASS = "$env:TEMP\ssh_askpass.bat"
if (-not (Test-Path $env:SSH_ASKPASS)) {
  "@echo off`r`necho ofs;123" | Out-File $env:SSH_ASKPASS -Encoding ASCII
}

function Read-Css([string]$name) {
  $p = Join-Path $PSScriptRoot $name
  if (-not (Test-Path $p)) { throw "找不到 $p" }
  $css = [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false))
  foreach ($bad in @('</style>', '</head>', '</body>', '</html>')) {
    if ($css.Contains($bad)) { throw "$name 里含危险标签 $bad（会截断 style 块）" }
  }
  return $css.Trim()
}

if ($Revert) {
  Write-Host "[1/2] 移除全部注入（原子写）"
  $remote = @'
F=/var/www/storapp/h5/index.html
python3 - "$F" << 'PYEOF'
import sys, re, io, os
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
s = re.sub(r'<link[^>]*href="/static/index\.css"[^>]*>', '', s)
s = re.sub(r'<style id="storapp-override">.*?</style>', '', s, flags=re.S)
s = re.sub(r'<style id="storapp-modern">.*?</style>', '', s, flags=re.S)
# 连带移除样式重排脚本（它按 appendChild 特征识别）
s = re.sub(r'<script>\(function\(\)\{function bump\(\).*?</script>', '', s, flags=re.S)
tmp = p + '.tmp'
io.open(tmp, 'w', encoding='utf-8').write(s)
os.replace(tmp, p)
print('  已移除，%d 字节' % len(s))
PYEOF
'@
} else {
  $fix    = Read-Css "h5-override.css"
  $modern = Read-Css "h5-modern.css"
  if ($fix -notmatch 'page-footer') { throw "h5-override.css 内容异常：缺少 page-footer 规则" }
  if ($modern -notmatch '--sa-primary') { throw "h5-modern.css 内容异常：缺少设计变量" }

  # 用 base64 传，避免引号/换行/中文被 ssh 吞掉
  $b64fix    = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($fix))
  $b64modern = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($modern))
  Write-Host ("[1/2] 注入  修复层 " + $fix.Length + " 字符 + 视觉层 " + $modern.Length + " 字符（原子写）")

  $remote = @"
F=/var/www/storapp/h5/index.html
echo '$b64fix'    | base64 -d > /tmp/sa-fix.css
echo '$b64modern' | base64 -d > /tmp/sa-modern.css
python3 - "`$F" << 'PYEOF'
import sys, re, io, os
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
fix    = io.open('/tmp/sa-fix.css',    encoding='utf-8').read().strip()
modern = io.open('/tmp/sa-modern.css', encoding='utf-8').read().strip()
assert 'page-footer' in fix and '--sa-primary' in modern

s = re.sub(r'<link[^>]*href="/static/index\.css"[^>]*>', '', s)
s = re.sub(r'<style id="storapp-override">.*?</style>', '', s, flags=re.S)
s = re.sub(r'<style id="storapp-modern">.*?</style>', '', s, flags=re.S)
assert s.count('<style') == 0 and s.count('<link') == 0, '清理不干净'

block = ('<link rel="stylesheet" href="/static/index.css">'
         '<style id="storapp-override">' + fix + '</style>'
         '<style id="storapp-modern">' + modern + '</style>'
         # 关键：CRMEB 组件样式由 webpack 运行时注入 head，位置在我们的 style 之后。
         # 遇到「特异性相同 + 双方都 !important」的规则（如 .grid-four[data-v-x] 的
         # grid-template-columns），按文档顺序后者胜 —— 我们的样式会输。
         # 解决：运行时把自己的 style 节点重新 append 到 head 末尾，确保排最后。
         '<script>(function(){function bump(){["storapp-override","storapp-modern"].forEach(function(id){var e=document.getElementById(id);if(e&&e.parentNode){e.parentNode.appendChild(e);}});}document.addEventListener("DOMContentLoaded",bump);window.addEventListener("load",bump);setTimeout(bump,600);setTimeout(bump,2000);setTimeout(bump,5000);})();</script>')
s = s.replace('</head>', block + '</head>', 1)

assert s.count('</style>') == 2, '</style> 数不对'
assert s.count('</head>') == 1, 'head 结束标签数不对'
assert s.count('</body>') == 1 and s.count('</html>') == 1
assert 'storapp-modern' in s and 'appendChild' in s, '样式重排脚本丢了'
assert '/static/js/index.' in s, 'JS 入口丢了'

tmp = p + '.tmp'
io.open(tmp, 'w', encoding='utf-8').write(s)
os.replace(tmp, p)
print('  已写入 %d 字符' % len(s))
PYEOF
"@
}

$rb64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($remote))
ssh -o StrictHostKeyChecking=no $SshHost "echo $rb64 | base64 -d | bash"

Write-Host "[2/2] reload nginx 并校验"
$check = @'
systemctl reload nginx
sleep 1
F=/var/www/storapp/h5/index.html
want=$(wc -c < $F)
echo "  磁盘文件: $want 字节"
echo -n "  nginx 返回: "; got=$(curl -s --compressed http://127.0.0.1:8092/ | wc -c); echo "$got 字节"
echo "  style 标签: $(grep -o '<style' $F | wc -l)   link: $(grep -o '<link' $F | wc -l)"
echo "  含修复层: $(grep -c 'storapp-override' $F)   含视觉层: $(grep -c 'storapp-modern' $F)"
echo -n "  连续 10 次一致性: "
ok=0; bad=0
for i in $(seq 1 10); do
  n=$(curl -s --compressed --max-time 8 http://127.0.0.1:8092/ | wc -c)
  if [ "$n" -eq "$want" ]; then ok=$((ok+1)); else bad=$((bad+1)); fi
done
echo "一致 $ok / 不一致 $bad"
if [ "$want" != "$got" ]; then echo "  [!] 磁盘与 nginx 不一致 —— 缓存没刷掉"; fi
'@
$cb64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($check))
ssh -o StrictHostKeyChecking=no $SshHost "echo $cb64 | base64 -d | bash"
Remove-Item "$env:TEMP\ssh_askpass.bat" -Force -ErrorAction SilentlyContinue
Write-Host "完成。刷新 H5 请用 Ctrl+Shift+R。"
