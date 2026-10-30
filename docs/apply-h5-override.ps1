# 原子化注入 H5 样式/脚本到服务器 /var/www/storapp/h5/index.html
#
# 注入四样东西（都在 head 结束标签之前）：
#   a) <link rel="stylesheet" href="/static/index.css">   uni-app 的 H5 基础样式（必须）
#   b) <style id="storapp-override">  h5-override.css     功能修复层
#   c) <style id="storapp-modern">    h5-modern.css       视觉设计层（换风格只改这个）
#   d) <script data-sa-inject>        h5-inject.js        运行时 DOM 注入（服务保障条等）
#
# ⚠️ 为什么必须原子写：
#   nginx 用 pread() 读静态文件。原地覆盖写（先截断再写）时，
#   写入窗口内访问站点的用户会拿到截断的 HTML -> 白屏。
#   日志特征：[alert] pread() read only N of M from ".../index.html" while sending response
#   所以：写临时文件 -> os.replace（同文件系统内原子）。
#
# ⚠️ 为什么要 reload nginx：
#   open_file_cache 按 inode 缓存句柄。原子替换后 inode 变了，不 reload 的话
#   nginx 会继续发旧内容（原配置 valid 120s，现已压到 5s 兜底）。
#
# ⚠️ 为什么远程 python 不再用 here-string 嵌 bash heredoc：
#   之前那版报 "Missing file specification after redirection operator"，
#   是 PowerShell here-string 里出现 << 被当重定向符，排查成本很高。
#   现在远程 python 用**单引号** here-string 写，占位符在运行期替换，
#   PowerShell 侧只剩最朴素的单引号字符串，零嵌套转义。
#
# 用法:
#   .\apply-h5-override.ps1            # 注入
#   .\apply-h5-override.ps1 -Revert    # 移除全部注入
param([switch]$Revert)

$ErrorActionPreference = "Stop"
$SshHost = "root@82.156.226.192"

$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "dummy"
$env:SSH_ASKPASS = Join-Path $env:TEMP "ssh_askpass.bat"

# SSH 密码：优先读环境变量 SA_SSH_PASS，没设才用兜底值。
#
# 为什么要这样：密码写死在脚本里会跟着 git 走（这个仓库的历史提交里已经有明文），
# 将来轮换密码时还得改一堆脚本。用环境变量就只改一处：
#     $env:SA_SSH_PASS = "<新密码>"      # 当前会话
# 或写进用户级环境变量长期生效。
$sshPass = $env:SA_SSH_PASS
if (-not $sshPass) { $sshPass = Read-Host '请输入服务器 SSH 密码' }
if (-not (Test-Path $env:SSH_ASKPASS)) {
  $ask = '@echo off' + "`r`n" + "echo $sshPass" + "`r`n"
  [System.IO.File]::WriteAllText($env:SSH_ASKPASS, $ask, [System.Text.ASCIIEncoding]::new())
}

# 用 chr() 拼标签，脚本本体里不出现会截断 HTML 的字面量
$LT = [string][char]60
$GT = [string][char]62
$Q  = [string][char]34

function B64([string]$s) { return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($s)) }

function Read-Src([string]$name, [string]$kind) {
  $p = Join-Path $PSScriptRoot $name
  if (-not (Test-Path $p)) { throw "找不到 $p" }
  $t = [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false))
  foreach ($bad in @(($LT + '/head' + $GT), ($LT + '/body' + $GT), ($LT + '/html' + $GT))) {
    if ($t.Contains($bad)) { throw "$name 里含危险标签 $bad" }
  }
  if ($kind -eq 'css') {
    if ($t.Contains($LT + '/style' + $GT)) { throw "$name 里含闭合 style 标签（会截断 style 块）" }
  } else {
    if ($t.Contains($LT + '/script')) { throw "$name 里含闭合 script 标签" }
  }
  return $t.Trim()
}

function Push-Remote([string]$script) {
  # 远程脚本也 base64 传：引号 / 换行 / 中文 / 重定向符都不会被 ssh 吞掉
  $b = B64 $script
  ssh -o StrictHostKeyChecking=no $SshHost "echo $b | base64 -d > /tmp/sa-run.sh && bash /tmp/sa-run.sh"
}

# ⚠️ Windows 命令行上限约 32K。
#    视觉层已经涨到 24KB，base64 后 ~33K，一次 ssh 传就报
#    "The filename or extension is too long"（踩过两次）。
#    所以大文件必须分块追加：每块 20000 字符（命令约 21KB），最后再校验字节数。
$ChunkSize = 20000

function Send-RemoteFile([string]$path, [string]$content) {
  $b = B64 $content
  $want = [System.Text.Encoding]::UTF8.GetByteCount($content)
  ssh -o StrictHostKeyChecking=no $SshHost "rm -f $path.b64"
  if ($LASTEXITCODE -ne 0) { throw "清理 $path.b64 失败" }
  $chunks = [math]::Ceiling($b.Length / $ChunkSize)
  for ($i = 0; $i -lt $chunks; $i++) {
    $start = $i * $ChunkSize
    $len = [Math]::Min($ChunkSize, $b.Length - $start)
    $part = $b.Substring($start, $len)
    ssh -o StrictHostKeyChecking=no $SshHost "printf '%s' '$part' >> $path.b64"
    if ($LASTEXITCODE -ne 0) { throw "上传 $path 第 $($i+1) 块失败" }
  }
  # base64 -d 解码 + 校验字节数，不一致直接报错（避免半包让页面白屏）
  # ⚠️ 校验脚本必须走 base64 传：里面既有 $ 又有双引号，直接拼进 ssh 会被
  #    PowerShell 和远端 shell 各吃一层引号 —— 实测直接把 python 脚本当 shell 跑了（踩过）。
  $verify = "base64 -d $path.b64 > $path`nrm -f $path.b64`n" +
            "got=`$(stat -c %s $path)`n" +
            "if [ `"`$got`" != `"$want`" ]; then echo `"字节数不符: got=`$got want=$want`"; exit 1; fi"
  $vb = B64 $verify
  ssh -o StrictHostKeyChecking=no $SshHost "echo $vb | base64 -d > /tmp/sa-verify.sh && bash /tmp/sa-verify.sh"
  if ($LASTEXITCODE -ne 0) { throw "上传 $path 失败（字节数校验不通过）" }
}

# ---- 远程 python 源码模板（单引号 here-string，占位符运行期替换）----------
$PY_TMPL = @'
import sys, re, io, os, shutil, base64
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
shutil.copyfile(p, p + '.bak')

LT = chr(60); GT = chr(62); Q = chr(34)
STYLE_CLOSE  = LT + '/style' + GT
HEAD_CLOSE   = LT + '/head' + GT
SCRIPT_OPEN  = LT + 'script'
SCRIPT_CLOSE = LT + '/script' + GT

def strip_tag(pat, flags=0):
    global s
    s = re.sub(pat, '', s, flags=flags)

# 1) 清掉历史注入
strip_tag(LT + 'link[^' + GT + ']*href=' + Q + '/static/index[.]css' + Q + '[^' + GT + ']*' + GT)
strip_tag(LT + 'style id=' + Q + 'storapp-override' + Q + GT + '.*?' + LT + '/style' + GT, re.S)
strip_tag(LT + 'style id=' + Q + 'storapp-modern' + Q + GT + '.*?' + LT + '/style' + GT, re.S)
strip_tag(LT + 'script data-sa-inject' + GT + '.*?' + LT + '/script' + GT, re.S)
strip_tag(LT + 'script' + GT + '.*?function bump.*?' + LT + '/script' + GT, re.S)

assert s.count(LT + 'style') == 0 and s.count(LT + 'link') == 0, '清理不干净'
assert 'sa-inject' not in s, '旧 DOM 注入脚本没清掉'
assert s.count(HEAD_CLOSE) == 1, 'head 结束标签数不对'

if not __REVERT__:
    fix    = io.open('/tmp/sa-fix.css',    encoding='utf-8').read().strip()
    modern = io.open('/tmp/sa-modern.css', encoding='utf-8').read().strip()
    inject = io.open('/tmp/sa-inject.js',  encoding='utf-8').read().strip()
    assert 'page-footer' in fix and '--sa-primary' in modern and 'sa-trustbar' in inject

    # CRMEB 组件样式由 webpack 运行时注入 head，位置在我们的 style 之后。
    # 遇到「特异性相同 + 双方都 !important」的规则（如 .grid-four[data-v-x] 的
    # grid-template-columns），按文档顺序后者胜 —— 我们的样式会输。
    # 解：注入重排脚本，运行时把自己的 style 节点 appendChild 到 head 末尾。
    BUMP = base64.b64decode('__BUMP__').decode('utf-8')
    BUMP_TAG = SCRIPT_OPEN + GT + BUMP + SCRIPT_CLOSE

    block = (LT + 'link rel=' + Q + 'stylesheet' + Q + ' href=' + Q + '/static/index.css' + Q + GT
             + LT + 'style id=' + Q + 'storapp-override' + Q + GT + fix + STYLE_CLOSE
             + LT + 'style id=' + Q + 'storapp-modern' + Q + GT + modern + STYLE_CLOSE
             + BUMP_TAG
             + SCRIPT_OPEN + ' data-sa-inject' + GT + inject + SCRIPT_CLOSE)
    s = s.replace(HEAD_CLOSE, block + HEAD_CLOSE, 1)

    assert s.count(STYLE_CLOSE) == 2, 'style 闭合标签数不对'
    # ⚠️ 这个属性名**只能**在 h5-inject.js 里出现一次（就是构建时拼出来的那一处）。
    #    之前在 h5-inject.js 的注释里写了一次这个名字，导致计数变 2、断言假失败，
    #    排查了很久。以后要么改断言、要么别在 JS 正文里写这个名字 —— 现在靠"别写"。
    assert s.count('data-sa-inject') == 1, 'DOM 注入脚本数不对（检查 h5-inject.js 正文里是否出现了这个属性名）'
    assert 'storapp-modern' in s and 'appendChild' in s, '样式重排脚本丢了'
    assert s.count(LT + '/body' + GT) == 1 and s.count(LT + '/html' + GT) == 1
    assert '/static/js/index.' in s, 'JS 入口丢了'

tmp = p + '.tmp'
io.open(tmp, 'w', encoding='utf-8').write(s)
os.replace(tmp, p)
print('  %s，%d 字符' % ('已注入' if not __REVERT__ else '已移除', len(s)))
'@

# 重排脚本（内联到 index.html），用 chr 拼避免出现裸标签
$BUMP_JS = '(function(){function bump(){[' + $Q + 'storapp-override' + $Q + ',' + $Q + 'storapp-modern' + $Q + ']'
$BUMP_JS += '.forEach(function(id){var e=document.getElementById(id);'
$BUMP_JS += 'if(e&&e.parentNode){e.parentNode.appendChild(e);}});}'
$BUMP_JS += 'document.addEventListener(' + $Q + 'DOMContentLoaded' + $Q + ',bump);'
$BUMP_JS += 'window.addEventListener(' + $Q + 'load' + $Q + ',bump);'
$BUMP_JS += 'setTimeout(bump,600);setTimeout(bump,2000);setTimeout(bump,5000);})();'

function Get-ReinitPy([bool]$revert) {
  # PS 5.1 里 if 是语句不是表达式，不能直接塞进方法参数
  $revertLiteral = 'False'
  if ($revert) { $revertLiteral = 'True' }
  $t = $PY_TMPL.Replace('__REVERT__', $revertLiteral)
  return $t.Replace('__BUMP__', (B64 $BUMP_JS))
}

$CHECK = @(
  'systemctl reload nginx',
  'sleep 1',
  'F=/var/www/storapp/h5/index.html',
  'want=$(wc -c < $F)',
  'echo "  磁盘文件: $want 字节"',
  'echo -n "  nginx 返回: "; got=$(curl -s --compressed http://127.0.0.1:8092/ | wc -c); echo "$got 字节"',
  'echo "  style 标签: $(grep -o "<style" $F | wc -l)   link: $(grep -o "<link" $F | wc -l)"',
  'echo "  含修复层: $(grep -c storapp-override $F)   含视觉层: $(grep -c storapp-modern $F)   含 DOM 注入: $(grep -c data-sa-inject $F)"',
  'echo -n "  连续 10 次一致性: "',
  'ok=0; bad=0',
  'for i in $(seq 1 10); do',
  '  n=$(curl -s --compressed --max-time 8 http://127.0.0.1:8092/ | wc -c)',
  '  if [ "$n" -eq "$want" ]; then ok=$((ok+1)); else bad=$((bad+1)); fi',
  'done',
  'echo "一致 $ok / 不一致 $bad"',
  'if [ "$want" != "$got" ]; then echo "  [!] 磁盘与 nginx 不一致 —— 缓存没刷掉"; fi'
) -join "`n"

# ---- 主流程 --------------------------------------------------------------

if ($Revert) {
  Write-Host "[1/2] 移除全部注入（原子写）"
  Send-RemoteFile "/tmp/sa-reinit.py" (Get-ReinitPy $true)
  Push-Remote "python3 /tmp/sa-reinit.py /var/www/storapp/h5/index.html`n"
} else {
  $fix    = Read-Src "h5-override.css" "css"
  $modern = Read-Src "h5-modern.css"   "css"
  $inject = Read-Src "h5-inject.js"    "js"
  if ($fix -notmatch 'page-footer') { throw "h5-override.css 内容异常：缺少 page-footer 规则" }
  if ($modern -notmatch '--sa-primary') { throw "h5-modern.css 内容异常：缺少设计变量" }
  if ($inject -notmatch 'sa-trustbar') { throw "h5-inject.js 内容异常：缺少 sa-trustbar" }

  Write-Host ("[1/2] 注入  修复层 " + $fix.Length + " 字符 + 视觉层 " + $modern.Length + " 字符 + DOM 注入 " + $inject.Length + " 字符（原子写）")

  Send-RemoteFile "/tmp/sa-fix.css"    $fix
  Send-RemoteFile "/tmp/sa-modern.css" $modern
  Send-RemoteFile "/tmp/sa-inject.js"  $inject
  Send-RemoteFile "/tmp/sa-reinit.py"  (Get-ReinitPy $false)
  Push-Remote "python3 /tmp/sa-reinit.py /var/www/storapp/h5/index.html`n"
}

Write-Host "[2/2] reload nginx 并校验"
Push-Remote $CHECK
Remove-Item $env:SSH_ASKPASS -Force -ErrorAction SilentlyContinue
Write-Host "完成。刷新 H5 请用 Ctrl+Shift+R。"
