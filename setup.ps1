# DSH Workspace Setup 脚本
# 将仓库中的 .dsh 配置部署到用户目录

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DshSource = Join-Path $RepoDir ".dsh"
$DshTarget = "$env:USERPROFILE\.dsh"

Write-Host @"
╔══════════════════════════════════════════════╗
║      DSH Workspace 配置部署脚本              ║
╚══════════════════════════════════════════════╝
"@

# 检查源目录
if (-not (Test-Path $DshSource)) {
    Write-Host "[ERROR] 未找到 .dsh 配置目录: $DshSource" -ForegroundColor Red
    exit 1
}

# 创建目标目录
if (-not (Test-Path $DshTarget)) {
    New-Item -ItemType Directory -Path $DshTarget -Force | Out-Null
    Write-Host "[OK] 创建目录: $DshTarget" -ForegroundColor Green
}

# 复制配置文件（排除凭证文件）
$files = @(
    ".anonymous-user-id",
    "settings.yaml"
)

foreach ($file in $files) {
    $src = Join-Path $DshSource $file
    $dst = Join-Path $DshTarget $file
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "[OK] 复制: $file" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] 未找到: $file" -ForegroundColor Yellow
    }
}

# 复制会话数据
$srcSessions = Join-Path $DshSource "sessions"
$dstSessions = Join-Path $DshTarget "sessions"
if (Test-Path $srcSessions) {
    Copy-Item $srcSessions $dstSessions -Recurse -Force
    Write-Host "[OK] 复制: sessions/" -ForegroundColor Green
}

# 复制存储数据
$srcStorages = Join-Path $DshSource "storages"
$dstStorages = Join-Path $DshTarget "storages"
if (Test-Path $srcStorages) {
    Copy-Item $srcStorages $dstStorages -Recurse -Force
    Write-Host "[OK] 复制: storages/" -ForegroundColor Green
}

# 复制 profiles 配置（不含 node_modules）
$srcProfiles = Join-Path $DshSource "profiles"
$dstProfiles = Join-Path $DshTarget "profiles"
if (Test-Path $srcProfiles) {
    # 复制 profiles 目录，排除 node_modules
    Get-ChildItem $srcProfiles -Directory | ForEach-Object {
        $profileName = $_.Name
        $srcProfile = Join-Path $srcProfiles $profileName
        $dstProfile = Join-Path $dstProfiles $profileName
        New-Item -ItemType Directory -Path $dstProfile -Force | Out-Null
        
        Get-ChildItem $srcProfile -Exclude "node_modules" | ForEach-Object {
            Copy-Item $_.FullName $dstProfile -Recurse -Force
        }
        Write-Host "[OK] 复制: profiles/$profileName/" -ForegroundColor Green
    }
}

# 凭证文件提醒
Write-Host ""
Write-Host "════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  ⚠ 凭证文件需要手动配置！" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 复制凭证模板:" -ForegroundColor Cyan
Write-Host "   copy .dsh\.credentials.yaml.example `$env:USERPROFILE\.dsh\.credentials.yaml" -ForegroundColor White
Write-Host ""
Write-Host "2. 编辑凭证文件，填入你的 API key:" -ForegroundColor Cyan
Write-Host "   notepad `$env:USERPROFILE\.dsh\.credentials.yaml" -ForegroundColor White
Write-Host ""

Write-Host "部署完成！" -ForegroundColor Green
Write-Host "现在可以运行: dsh web" -ForegroundColor White