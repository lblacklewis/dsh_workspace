# 部署 H5（uni-app）构建产物到服务器 /var/www/storapp/h5
#
# 与 deploy-admin.ps1 同构，区别只在目标目录和最后一步：
#   H5 的 index.html 里有注入的样式层（storapp-override / storapp-modern + DOM 注入脚本），
#   构建产物是干净的，所以换完目录**必须**重跑 apply-h5-override.ps1 把那几层挂回去。
#
# 用法:
#   .\deploy-h5.ps1                     # 干跑：打包并报告体积、分块数
#   .\deploy-h5.ps1 -Apply              # 打包 + 分块上传 + 原子换目录 + 重注入
#   .\deploy-h5.ps1 -Apply -SkipUpload  # 复用服务器上已传好的包，只换目录
#   .\deploy-h5.ps1 -Apply -Revert      # 换完目录后不注入样式层（只要干净的原始构建）
#
# ⚠️ 构建命令（在 app/ 目录）：
#     $env:UNI_INPUT_DIR="D:\project\StorApp\crmeb_java\app"
#     npm run build:h5
#   这是个 HBuilderX 布局的工程（源码在根目录，不在 src/），
#   不设 UNI_INPUT_DIR 会报 "src\manifest.json does not exist"。

param(
  [switch]$Apply,
  [switch]$SkipUpload,
  [switch]$Revert
)

$ErrorActionPreference = "Stop"
$SshHost = "root@82.156.226.192"
# ⚠️🔥 输出目录是 app\dist\build\h5 —— **不是** app\unpackage\dist\build\h5！
# 这个 HBuilderX 布局的工程用 vue-cli 构建时，产物落在 app\dist\build\h5；
# app\unpackage\dist\build\h5 只是历史上留下的一份**陈旧副本**（时间戳停在不带新页面的那次）。
# 我因为这个坑排查了很久：新加的页面明明进了 pages.json、也生成了 chunk，
# 但我一直在 unpackage 那份旧目录里找，当然找不到，还误判成「构建不编译新页面」。
$DistDir = Join-Path (Split-Path $PSScriptRoot -Parent) "app\dist\build\h5"
$StaleDist = Join-Path (Split-Path $PSScriptRoot -Parent) "app\unpackage\dist\build\h5"
$Remote  = "/var/www/storapp/h5"
$TarName = "sa-h5-dist.tar.gz"
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
  # 远程脚本走 base64：引号 / 换行 / 中文 / 重定向符都不会被 ssh 吞掉
  ssh -o StrictHostKeyChecking=no $SshHost "echo $(B64 $sh) | base64 -d > /tmp/sa-h5-step.sh && bash /tmp/sa-h5-step.sh"
  if ($LASTEXITCODE -ne 0) { throw "远程步骤失败" }
}

# ---- 1. 打包 ------------------------------------------------------------
if (-not (Test-Path $DistDir)) { throw "找不到 $DistDir，先跑 npm run build:h5" }
if (-not (Test-Path (Join-Path $DistDir "index.html"))) { throw "$DistDir 里没有 index.html，构建不完整" }
# 陈旧副本防呆：它存在很容易让人看错目录（我就栽过）
if (Test-Path $StaleDist) {
  $staleTime = (Get-Item $StaleDist).LastWriteTime
  $realTime = (Get-Item $DistDir).LastWriteTime
  Write-Host "[警告] 存在陈旧产物目录 $StaleDist" -ForegroundColor Yellow
  Write-Host "        它最后修改于 $staleTime，真实产物目录是 $realTime" -ForegroundColor Yellow
  Write-Host "        本脚本只用真实的那个；建议删掉旧的以免误导：Remove-Item '$StaleDist' -Recurse" -ForegroundColor Yellow
}
$tarLocal = Join-Path $env:TEMP $TarName
if (Test-Path $tarLocal) { Remove-Item $tarLocal -Force }

Write-Host "[1/4] 打包 $DistDir"
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
  Write-Host "[2/4] 跳过上传（-SkipUpload，复用服务器 /tmp/sa-h5-dist.b64）"
  $remoteSize = (ssh -o StrictHostKeyChecking=no $SshHost "stat -c %s /tmp/sa-h5-dist.b64 2>/dev/null || echo 0").Trim()
  if ($remoteSize -ne "$($b64.Length)") {
    throw "服务器上的 /tmp/sa-h5-dist.b64 大小 $remoteSize 与本地 $($b64.Length) 不一致，去掉 -SkipUpload 重传"
  }
  Write-Host "      服务器 base64 大小校验通过：$remoteSize"
} else {
  Write-Host "[2/4] 分块上传（每块 $ChunkSize 字符）"
  Run-Remote "rm -f /tmp/sa-h5-dist.b64"
  for ($i = 0; $i -lt $chunks; $i++) {
    $start = $i * $ChunkSize
    $len = [Math]::Min($ChunkSize, $b64.Length - $start)
    $part = $b64.Substring($start, $len)
    ssh -o StrictHostKeyChecking=no $SshHost "printf '%s' '$part' >> /tmp/sa-h5-dist.b64"
    if ($LASTEXITCODE -ne 0) { throw "第 $($i+1) 块上传失败" }
    if ((($i + 1) % 20) -eq 0 -or ($i + 1) -eq $chunks) { Write-Host "      $($i + 1)/$chunks" }
  }
}

# ---- 3. 服务器端原子替换 ------------------------------------------------
Write-Host "[3/4] 解包并原子替换 $Remote"
# ⚠️ 两条纪律（都踩过，详见 docs/交接_视觉升级.md 第六节坑 16）：
#   1. 给 shell 用的变量一律先在远程脚本开头定义（REMOTE=...），不要在 PowerShell 里拼单引号字符串
#   2. 注释里绝对不能出现「反引号 + 美元 + 左括号」，PowerShell 会当子表达式立即执行
$swap = @(
  'set -e',
  'B64=/tmp/sa-h5-dist.b64',
  ('TAR=/tmp/' + $TarName),
  ('REMOTE=' + $Remote),
  'base64 -d $B64 > $TAR',
  'echo "  tar 包: $(stat -c %s $TAR) 字节"',
  'tar -tzf $TAR > /dev/null',
  'STAGE=/var/www/storapp/.h5-staging',
  'rm -rf $STAGE && mkdir -p $STAGE',
  'tar -xzf $TAR -C $STAGE',
  'test -f $STAGE/index.html || { echo "解包后没有 index.html"; exit 1; }',
  'test -d $STAGE/static   || { echo "解包后没有 static 目录"; exit 1; }',
  'rm -rf /var/www/storapp/.h5-backup',
  'mv $REMOTE /var/www/storapp/.h5-backup 2>/dev/null || true',
  'mv $STAGE $REMOTE',
  'chmod -R 755 $REMOTE',
  'echo "  解包文件数: $(find $REMOTE -type f | wc -l)"',
  'echo "  备份在: /var/www/storapp/.h5-backup"'
) -join "`n"
Run-Remote $swap

# ---- 4. 重新注入样式层 --------------------------------------------------
if ($Revert) {
  Write-Host "[4/4] 跳过样式层注入（-Revert），线上是干净的原始构建"
} else {
  Write-Host "[4/4] 重新注入 H5 样式层（构建覆盖了 index.html）"
  & (Join-Path $PSScriptRoot "apply-h5-override.ps1")
}

Remove-Item $env:SSH_ASKPASS -Force -ErrorAction SilentlyContinue
Write-Host "完成。刷新 H5 请用 Ctrl+Shift+R。"
