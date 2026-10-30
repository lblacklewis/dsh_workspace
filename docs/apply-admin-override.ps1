# 原子化注入后台样式覆盖层到服务器 /var/www/storapp/admin/index.html
#
# 注入两样东西（都在 head 结束标签之前）：
#   a) <style id="storapp-admin">  admin-override.css   后台布局修复 + 视觉统一
#   b) 一个重排脚本，运行时把自己的 style 节点 appendChild 到 head 末尾。
#      必要性同 H5：后台样式是 webpack 运行时注入 head 的，位置在我们的 style 之后，
#      遇到「特异性相同 + 双方都 !important」的规则按文档顺序后者胜，我们会输。
#      （后台这套样式大量用 !important，纯靠特异性扛不住，必须重排。）
#
# ⚠️ 原子写 + reload nginx 的原因与 H5 一致（open_file_cache 按 inode 缓存句柄）。
#
# 用法:
#   .\apply-admin-override.ps1            # 注入
#   .\apply-admin-override.ps1 -Revert    # 移除注入
param([switch]$Revert)

$ErrorActionPreference = "Stop"
$SshHost = "root@82.156.226.192"
$TARGET = "/var/www/storapp/admin/index.html"
$CSS    = "admin-override.css"
$CSS_DEST = "/var/www/storapp/admin/static/storapp-admin.css"
$CSS_HREF = "/static/storapp-admin.css"
$STYLE_ID = "storapp-admin"

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

$LT = [string][char]60
$GT = [string][char]62
$Q  = [string][char]34

function B64([string]$s) { return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($s)) }
function Push-Remote([string]$script) {
  ssh -o StrictHostKeyChecking=no $SshHost "echo $(B64 $script) | base64 -d > /tmp/admin-run.sh && bash /tmp/admin-run.sh"
  if ($LASTEXITCODE -ne 0) { throw "远程执行失败" }
}
function Read-Src([string]$name) {
  $p = Join-Path $PSScriptRoot $name
  if (-not (Test-Path $p)) { throw "找不到 $p" }
  $t = [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false))
  foreach ($bad in @(($LT + '/style' + $GT), ($LT + '/head' + $GT), ($LT + '/body' + $GT), ($LT + '/html' + $GT))) {
    if ($t.Contains($bad)) { throw "$name 里含危险标签 $bad" }
  }
  # 兜底层现在主要职责是把主题主色钉成 teal，所以按这个断言
  if ($t -notmatch '--prev-color-primary') { throw "$name 内容异常：缺少 --prev-color-primary 兜底" }
  return $t.Trim()
}

# ---- 远程 python 模板（单引号 here-string，占位符运行期替换）----
$PY_TMPL = @'
import sys, re, io, os, shutil, base64
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
shutil.copyfile(p, p + '.bak')

LT = chr(60); GT = chr(62); Q = chr(34)
STYLE_CLOSE = LT + '/style' + GT
HEAD_CLOSE  = LT + '/head' + GT
SCRIPT_OPEN = LT + 'script'
SCRIPT_CLOSE = LT + '/script' + GT

def strip_tag(pat, flags=0):
    global s
    s = re.sub(pat, '', s, flags=flags)

# 清掉历史注入（内联 style 版 + link 版都清，方便从旧方案平滑切过来）
strip_tag(LT + 'style id=' + Q + '__STYLE_ID__' + Q + GT + '.*?' + LT + '/style' + GT, re.S)
strip_tag(LT + 'link[^' + GT + ']*id=' + Q + '__STYLE_ID__' + Q + '[^' + GT + ']*' + GT)
strip_tag(LT + 'script data-sa-admin' + GT + '.*?' + LT + '/script' + GT, re.S)

assert s.count(HEAD_CLOSE) == 1, 'head 结束标签数不对'

if not __REVERT__:
    # ⚠️ 为什么用 <link> 而不是内联 <style>：
    # 实测把 6.7KB 的 <style id="storapp-admin"> 静态写进 index.html 后，
    # 页面加载完成时 DOM 里**查不到这个节点**（服务端返回的 HTML 里明明有）——
    # 后台的构建产物在启动过程中会重建 head，静态 style 节点被丢掉，
    # 所以内联方案在后台不可用（H5 那边没这个问题，可以用内联）。
    # <link> 是外部资源，不受 DOM 重建影响，且 index.html 保持小巧。
    link_tag = LT + 'link rel=' + Q + 'stylesheet' + Q + ' id=' + Q + '__STYLE_ID__' + Q + ' href=' + Q + '__CSS_HREF__' + Q + GT
    BUMP = base64.b64decode('__BUMP__').decode('utf-8')
    block = link_tag + SCRIPT_OPEN + ' data-sa-admin' + GT + BUMP + SCRIPT_CLOSE
    s = s.replace(HEAD_CLOSE, block + HEAD_CLOSE, 1)
    assert s.count(LT + 'script data-sa-admin' + GT) == 1, '重排脚本数不对'
    assert s.count('href=' + Q + '__CSS_HREF__' + Q) == 1, 'link 数不对'

tmp = p + '.tmp'
io.open(tmp, 'w', encoding='utf-8').write(s)
os.replace(tmp, p)
print('  %s，%d 字符' % ('已注入' if not __REVERT__ else '已移除', len(s)))
'@

$BUMP_JS  = '(function(){'
$BUMP_JS += 'var ID=' + $Q + $STYLE_ID + $Q + ',HREF=' + $Q + $CSS_HREF + $Q + ';'
$BUMP_JS += 'function ensure(){'
$BUMP_JS += 'if(document.getElementById(ID))return;'
$BUMP_JS += 'var e=document.createElement(' + $Q + 'link' + $Q + ');'
$BUMP_JS += 'e.id=ID;e.rel=' + $Q + 'stylesheet' + $Q + ';e.href=HREF;'
$BUMP_JS += 'document.head.appendChild(e);}'
# ⚠️ 为什么不是「静态写死 link」就完事：
#   后台构建产物在启动时会**丢掉 head 里静态写入的节点**（link 和内联 style 都一样：
#   实测服务端返回的 HTML 里明明有，页面跑起来后 DOM 里查不到）。
#   所以必须在**运行时自己建**节点并守住它：启动阶段轮询 + MutationObserver 兜底。
$BUMP_JS += 'ensure();'
$BUMP_JS += 'document.addEventListener(' + $Q + 'DOMContentLoaded' + $Q + ',ensure);'
$BUMP_JS += 'window.addEventListener(' + $Q + 'load' + $Q + ',ensure);'
$BUMP_JS += 'var n=0,t=setInterval(function(){ensure();if(++n>60)clearInterval(t);},250);'
$BUMP_JS += 'try{new MutationObserver(ensure).observe(document.head,{childList:true});}catch(e){}'
$BUMP_JS += '})();'

function Get-Py([bool]$revert) {
  $rev = 'False'
  if ($revert) { $rev = 'True' }
  $t = $PY_TMPL.Replace('__REVERT__', $rev).Replace('__STYLE_ID__', $STYLE_ID)
  return $t.Replace('__BUMP__', (B64 $BUMP_JS)).Replace('__CSS_HREF__', $CSS_HREF)
}

$CHECK = @(
  'systemctl reload nginx',
  'sleep 1',
  ('F=' + $TARGET),
  'want=$(wc -c < $F)',
  'echo "  磁盘文件: $want 字节"',
  'echo -n "  nginx 返回: "; got=$(curl -s --compressed http://127.0.0.1/ | wc -c); echo "$got 字节"',
  ('echo "  含后台样式层: $(grep -c ' + $STYLE_ID + ' $F)   含重排脚本: $(grep -c data-sa-admin $F)"'),
  ('echo "  css 文件: $( [ -f ' + $CSS_DEST + ' ] && stat -c %s ' + $CSS_DEST + ' || echo 已移除 )   nginx 取 css: $(curl -s -o /dev/null -w %{http_code} http://127.0.0.1' + $CSS_HREF + ')"'),
  'echo -n "  连续 6 次一致性: "',
  'ok=0; bad=0',
  'for i in $(seq 1 6); do',
  '  n=$(curl -s --compressed --max-time 8 http://127.0.0.1/ | wc -c)',
  '  if [ "$n" -eq "$want" ]; then ok=$((ok+1)); else bad=$((bad+1)); fi',
  'done',
  'echo "一致 $ok / 不一致 $bad"',
  'if [ "$want" != "$got" ]; then echo "  [!] 磁盘与 nginx 不一致 —— 缓存没刷掉"; fi'
) -join "`n"

if ($Revert) {
  Write-Host "[1/2] 移除后台注入（原子写）"
  $sh  = "echo " + (B64 (Get-Py $true)) + " | base64 -d > /tmp/sa-admin.py`n"
  $sh += "python3 /tmp/sa-admin.py $TARGET`n"
  $sh += "rm -f $CSS_DEST`n"
  Push-Remote $sh
} else {
  $css = Read-Src $CSS
  Write-Host ("[1/2] 注入后台样式层 " + $css.Length + " 字符（css 落文件 + index.html 挂 link，原子写）")
  $sh  = "echo " + (B64 $css)              + " | base64 -d > /tmp/sa-admin.css`n"
  $sh += "cp /tmp/sa-admin.css $CSS_DEST`n"
  $sh += "chmod 644 $CSS_DEST`n"
  $sh += "echo " + (B64 (Get-Py $false)) + " | base64 -d > /tmp/sa-admin.py`n"
  $sh += "python3 /tmp/sa-admin.py $TARGET`n"
  Push-Remote $sh
}

Write-Host "[2/2] reload nginx 并校验"
Push-Remote $CHECK
Remove-Item $env:SSH_ASKPASS -Force -ErrorAction SilentlyContinue
Write-Host "完成。刷新后台请用 Ctrl+Shift+R。"
