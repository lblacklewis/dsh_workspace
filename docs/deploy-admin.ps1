# 部署后台构建产物到服务器 /var/www/storapp/admin
#
# 做三件事：
#   1. 打包本地 admin/dist（tar.gz）并按 base64 分块上传 —— 避开 Windows 命令行 32K 上限
#   2. 服务器上原子替换：解到临时目录 -> 备份现有 admin -> 换过去
#   3. 重新注入后台样式层（构建会把 index.html 覆盖掉，注入必须重跑）
#
# ⚠️ 不要直接 scp 整个目录：本会话环境里 scp 依赖的 askpass 容易挂住，
#    而且 286 个文件逐个 scp 很慢。打包 + base64 分块是实测最稳的方式。
#
# 用法:
#   .\deploy-admin.ps1              # 干跑：只打包并报告体积、分块数
#   .\deploy-admin.ps1 -Apply       # 真正部署
#   .\deploy-admin.ps1 -Apply -SkipRestyle   # 只传文件，不重跑样式注入
#   .\deploy-admin.ps1 -Apply -SkipUpload    # 复用服务器上已传好的 /tmp/sa-dist.b64，
#                                            # 只做解包换目录（分块上传一趟要几分钟）

param(
  [switch]$Apply,
  [switch]$SkipRestyle,
  [switch]$SkipUpload
)

$ErrorActionPreference = "Stop"
$SshHost = "root@82.156.226.192"
$DistDir = Join-Path (Split-Path $PSScriptRoot -Parent) "admin\dist"
$Remote  = "/var/www/storapp/admin"
$TarName = "sa-admin-dist.tar.gz"
# 每块 base64 字符数。Windows 命令行上限约 32K，20000 字符 → 命令约 21KB，安全。
# 块越小越安全但趟数爆炸：6000 字符 = 1857 块，慢到不可接受（实测）；20000 后约 560 块。
$ChunkSize = 20000

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
  ssh -o StrictHostKeyChecking=no $SshHost "echo $(B64 $sh) | base64 -d > /tmp/sa-deploy-step.sh && bash /tmp/sa-deploy-step.sh"
  if ($LASTEXITCODE -ne 0) { throw "远程步骤失败" }
}

# ---- 1. 打包 ------------------------------------------------------------
if (-not (Test-Path $DistDir)) { throw "找不到 $DistDir，先跑 npm run build:prod" }
$tarLocal = Join-Path $env:TEMP $TarName
if (Test-Path $tarLocal) { Remove-Item $tarLocal -Force }

Write-Host "[1/4] 打包 $DistDir"
# 用 tar 打包（Windows 10+ 自带 bsdtar）；-C 保证包内是相对路径
& tar -czf $tarLocal -C $DistDir .
if ($LASTEXITCODE -ne 0) { throw "tar 打包失败" }
$sizeMB = [math]::Round((Get-Item $tarLocal).Length / 1MB, 2)
$b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($tarLocal))
$chunks = [math]::Ceiling($b64.Length / $ChunkSize)
Write-Host "      产物 $sizeMB MB  ->  base64 $($b64.Length) 字符  ->  $chunks 块"

if (-not $Apply) {
  Write-Host "[干跑] 加 -Apply 才会真正上传部署。"
  exit 0
}

# ---- 2. 分块上传 --------------------------------------------------------
if ($SkipUpload) {
  Write-Host "[2/4] 跳过上传（-SkipUpload，复用服务器 /tmp/sa-dist.b64）"
  $remoteSize = (ssh -o StrictHostKeyChecking=no $SshHost "stat -c %s /tmp/sa-dist.b64 2>/dev/null || echo 0").Trim()
  if ($remoteSize -ne "$($b64.Length)") {
    throw "服务器上的 /tmp/sa-dist.b64 大小 $remoteSize 与本地 base64 $($b64.Length) 不一致，去掉 -SkipUpload 重传"
  }
  Write-Host "      服务器 base64 大小校验通过：$remoteSize"
} else {
  Write-Host "[2/4] 分块上传（每块 $ChunkSize 字符）"
  Run-Remote "rm -f /tmp/sa-dist.b64"
  for ($i = 0; $i -lt $chunks; $i++) {
    $start = $i * $ChunkSize
    $len = [Math]::Min($ChunkSize, $b64.Length - $start)
    $part = $b64.Substring($start, $len)
    ssh -o StrictHostKeyChecking=no $SshHost "printf '%s' '$part' >> /tmp/sa-dist.b64"
    if ($LASTEXITCODE -ne 0) { throw "第 $($i+1) 块上传失败" }
    if ((($i + 1) % 20) -eq 0 -or ($i + 1) -eq $chunks) {
      Write-Host "      $($i + 1)/$chunks"
    }
  }
}

# ---- 3. 服务器端原子替换 ------------------------------------------------
Write-Host "[3/4] 解包并原子替换 $Remote"
# ⚠️⚠️ 这个数组里的每一条都是 PowerShell 字符串，容易被两件事咬到（都踩过）：
#   1. 用单引号包住的元素里，PowerShell 的美元变量**不会**展开（远端会收到空的 $REMOTE）。
#      解法：先用双引号把 $Remote 的值拼进去，赋给 REMOTE=... 再用 shell 变量。
#   2. 注释里如果写了「反引号 + 美元 + 括号」，PowerShell 会当**子表达式立即执行**，
#      把命令输出按行拼进远程脚本 —— 脚本直接废掉（出现过 if 条件被拆成 3 行）。
#      解法：注释里永远别写那个组合，要举例也写成中文字面描述。
$swap = @(
  'set -e',
  'B64=/tmp/sa-dist.b64',
  ('TAR=/tmp/' + $TarName),
  ('REMOTE=' + $Remote),
  'base64 -d $B64 > $TAR',
  'echo "  tar 包: $(stat -c %s $TAR) 字节"',
  '# 校验 tar 可读，避免半包把线上搞坏',
  'tar -tzf $TAR > /dev/null',
  'STAGE=/var/www/storapp/.admin-staging',
  'rm -rf $STAGE && mkdir -p $STAGE',
  'tar -xzf $TAR -C $STAGE',
  'test -f $STAGE/index.html || { echo "解包后没有 index.html"; exit 1; }',
  'test -d $STAGE/static   || { echo "解包后没有 static 目录"; exit 1; }',
  '# 保留线上已注入的 index.html：构建产物的 index.html 是干净的，直接换上去会把',
  '# 样式层的 link 和守卫脚本一起冲掉。先把线上那份留在暂存目录做对照。',
  'if [ -f $REMOTE/index.html ]; then',
  '  cp $REMOTE/index.html $STAGE/index.html.injected',
  '  echo "  已保留线上 index.html（留给第 4 步对比）"',
  'fi',
  'rm -rf /var/www/storapp/.admin-backup',
  'mv $REMOTE /var/www/storapp/.admin-backup 2>/dev/null || true',
  'mv $STAGE $REMOTE',
  'chmod -R 755 $REMOTE',
  'echo "  解包文件数: $(find $REMOTE -type f | wc -l)"',
  'echo "  备份在: /var/www/storapp/.admin-backup"'
) -join "`n"
Run-Remote $swap

# ---- 4. 重新注入样式层 --------------------------------------------------
if ($SkipRestyle) {
  Write-Host "[4/4] 跳过样式注入（-SkipRestyle）"
} else {
  Write-Host "[4/4] 重新注入后台样式层（构建覆盖了 index.html）"
  & (Join-Path $PSScriptRoot "apply-admin-override.ps1")
}

Remove-Item $env:SSH_ASKPASS -Force -ErrorAction SilentlyContinue
Write-Host "完成。刷新后台请用 Ctrl+Shift+R。"
