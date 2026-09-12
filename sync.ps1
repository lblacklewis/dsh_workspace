# DSH Workspace 同步脚本
# 将本地 ~/.dsh 配置同步到 Git 仓库

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DshSource = "$env:USERPROFILE\.dsh"
$DshTarget = Join-Path $RepoDir ".dsh"

Write-Host "🔄 同步 DSH 配置到 Git 仓库..." -ForegroundColor Cyan

# 清除旧数据
if (Test-Path $DshTarget) {
    Remove-Item $DshTarget -Recurse -Force
}

# 创建目标目录
New-Item -ItemType Directory -Path $DshTarget -Force | Out-Null

# 同步根目录文件（排除凭证文件）
$rootFiles = @(".anonymous-user-id", "settings.yaml")
foreach ($file in $rootFiles) {
    $src = Join-Path $DshSource $file
    if (Test-Path $src) {
        Copy-Item $src $DshTarget -Force
        Write-Host "[OK] $file" -ForegroundColor Green
    }
}

# 同步会话数据
$srcSessions = Join-Path $DshSource "sessions"
if (Test-Path $srcSessions) {
    Copy-Item $srcSessions "$DshTarget\sessions" -Recurse -Force
    Write-Host "[OK] sessions/" -ForegroundColor Green
}

# 同步存储数据
$srcStorages = Join-Path $DshSource "storages"
if (Test-Path $srcStorages) {
    Copy-Item $srcStorages "$DshTarget\storages" -Recurse -Force
    Write-Host "[OK] storages/" -ForegroundColor Green
}

# 同步 profiles 配置（排除 node_modules）
$srcProfiles = Join-Path $DshSource "profiles"
if (Test-Path $srcProfiles) {
    New-Item -ItemType Directory -Path "$DshTarget\profiles" -Force | Out-Null
    Get-ChildItem $srcProfiles -Directory | ForEach-Object {
        $profileName = $_.Name
        $dstProfile = "$DshTarget\profiles\$profileName"
        New-Item -ItemType Directory -Path $dstProfile -Force | Out-Null
        Get-ChildItem $_.FullName -Exclude "node_modules" | ForEach-Object {
            Copy-Item $_.FullName $dstProfile -Recurse -Force
        }
        Write-Host "[OK] profiles/$profileName/" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "同步完成！运行以下命令提交到 Git:" -ForegroundColor Green
Write-Host "  git add -A" -ForegroundColor White
Write-Host '  git commit -m "更新 DSH 配置"' -ForegroundColor White
Write-Host "  git push" -ForegroundColor White