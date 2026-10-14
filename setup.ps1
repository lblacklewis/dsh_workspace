# ============================================================================
#  DSH Workspace 配置部署脚本
# ----------------------------------------------------------------------------
#  支持两种模式（-Mode）：
#    web      Web 版（dsh web）：复制完整 settings + profiles/web
#    desktop  桌面版（DSH Desktop / Electron）：只复制通用 settings，
#             不碰 profiles/（桌面版 profile 由 Electron 独占管理），
#             并剔除 remote-web-ui（避免 403 配对门控问题）
#    auto     自动识别（默认）：检测到 ~/.dsh/profiles/desktop 就按桌面版处理
#
#  用法：
#    .\setup.ps1                  # 自动识别
#    .\setup.ps1 -Mode desktop    # 强制桌面版（家里那台）
#    .\setup.ps1 -Mode web        # 强制 Web 版（公司这台）
#
#  ⚠ 编码：本 .ps1 保存为 UTF-8 with BOM（PowerShell 5.1 中文兼容）；
#     但它写入的 YAML/JSON 配置必须是 UTF-8 无 BOM（见脚本内注释）。
# ============================================================================

param(
    [switch]$Force,
    [ValidateSet('auto', 'web', 'desktop')]
    [string]$Mode = 'auto'
)

$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DshSource = Join-Path $RepoDir ".dsh"
$DshTarget = "$env:USERPROFILE\.dsh"

Write-Host ""
Write-Host "=============================================="
Write-Host "      DSH Workspace 配置部署脚本"
Write-Host "=============================================="
Write-Host ""

# 检查源目录
if (-not (Test-Path $DshSource)) {
    Write-Host "[ERROR] 未找到 .dsh 配置目录: $DshSource" -ForegroundColor Red
    exit 1
}

# ---- 模式判定 ----
$desktopProfile = Join-Path $DshTarget "profiles\desktop"
$isDesktopInstalled = Test-Path $desktopProfile

if ($Mode -eq 'auto') {
    if ($isDesktopInstalled) {
        $Mode = 'desktop'
        Write-Host "[AUTO] 检测到桌面版 profile（profiles\desktop），按【桌面版】模式处理" -ForegroundColor Cyan
    } else {
        $Mode = 'web'
        Write-Host "[AUTO] 未检测到桌面版 profile，按【Web 版】模式处理" -ForegroundColor Cyan
    }
} else {
    Write-Host "[MODE] 手动指定: $Mode" -ForegroundColor Cyan
}

if ($Mode -eq 'web' -and $isDesktopInstalled) {
    Write-Host ""
    Write-Host "[WARN] 本机同时存在桌面版 profile，但你要按 Web 版部署。" -ForegroundColor Yellow
    Write-Host "       Web 版 settings 含 remote-web-ui（绑 0.0.0.0 + 配对门控），" -ForegroundColor Yellow
    Write-Host "       可能让桌面版客户端访问 /api 返回 403。如只用桌面版请用 -Mode desktop。" -ForegroundColor Yellow
    Write-Host ""
}

# 创建目标目录
if (-not (Test-Path $DshTarget)) {
    New-Item -ItemType Directory -Path $DshTarget -Force | Out-Null
    Write-Host "[OK] 创建目录: $DshTarget" -ForegroundColor Green
}

# ---- 1. settings.yaml ----
# 桌面版用精简模板（无 remote-web-ui 等 Web 专有段），Web 版用完整配置
if ($Mode -eq 'desktop') {
    $settingsSrc = Join-Path $DshSource "settings.desktop.yaml"
    $settingsDesc = "settings.desktop.yaml（桌面版精简：无 remote-web-ui）"
} else {
    $settingsSrc = Join-Path $DshSource "settings.yaml"
    $settingsDesc = "settings.yaml（Web 版完整）"
}

if (Test-Path $settingsSrc) {
    $dst = Join-Path $DshTarget "settings.yaml"
    # 备份已有 settings（避免覆盖用户手工调整）
    if (Test-Path $dst) {
        $bak = "$dst.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item $dst $bak -Force
        Write-Host "[BAK] 已备份原 settings.yaml -> $(Split-Path $bak -Leaf)" -ForegroundColor DarkGray
    }
    Copy-Item $settingsSrc $dst -Force
    Write-Host "[OK] 复制: $settingsDesc" -ForegroundColor Green
} else {
    Write-Host "[SKIP] 未找到 settings 源文件: $settingsSrc" -ForegroundColor Yellow
}

# ---- 2. 匿名用户标识 ----
$anonSrc = Join-Path $DshSource ".anonymous-user-id"
if (Test-Path $anonSrc) {
    Copy-Item $anonSrc (Join-Path $DshTarget ".anonymous-user-id") -Force
    Write-Host "[OK] 复制: .anonymous-user-id" -ForegroundColor Green
}

# ---- 2b. Doctor 角色定义（全局 AGENTS.md，DSH 自动加载进所有会话）----
$agentsSrc = Join-Path $DshSource "AGENTS.md"
if (Test-Path $agentsSrc) {
    Copy-Item $agentsSrc (Join-Path $DshTarget "AGENTS.md") -Force
    Write-Host "[OK] 复制: AGENTS.md（Doctor 角色 + 环境维护手册）" -ForegroundColor Green
}

# ---- 3. 会话记忆 ----
$srcSessions = Join-Path $DshSource "sessions"
if (Test-Path $srcSessions) {
    Copy-Item $srcSessions (Join-Path $DshTarget "sessions") -Recurse -Force
    Write-Host "[OK] 复制: sessions/（会话记忆）" -ForegroundColor Green
}

# ---- 4. 存储数据 ----
$srcStorages = Join-Path $DshSource "storages"
if (Test-Path $srcStorages) {
    Copy-Item $srcStorages (Join-Path $DshTarget "storages") -Recurse -Force
    Write-Host "[OK] 复制: storages/" -ForegroundColor Green
}

# ---- 5. profiles（仅 Web 版）----
if ($Mode -eq 'web') {
    $srcProfiles = Join-Path $DshSource "profiles"
    if (Test-Path $srcProfiles) {
        Get-ChildItem $srcProfiles -Directory | ForEach-Object {
            $profileName = $_.Name
            $srcProfile = Join-Path $srcProfiles $profileName
            $dstProfile = Join-Path $DshTarget "profiles\$profileName"
            New-Item -ItemType Directory -Path $dstProfile -Force | Out-Null
            Get-ChildItem $srcProfile -Exclude "node_modules" | ForEach-Object {
                Copy-Item $_.FullName $dstProfile -Recurse -Force
            }
            Write-Host "[OK] 复制: profiles/$profileName/" -ForegroundColor Green
        }
    }
} else {
    Write-Host "[SKIP] 桌面版模式：不复制 profiles/（由 Electron 独占管理）" -ForegroundColor DarkGray
}

# ---- 6. 桌面版专属检查 ----
if ($Mode -eq 'desktop') {
    Write-Host ""
    Write-Host "----- 桌面版检查 -----" -ForegroundColor Cyan

    # 检查 desktop profile 是否装了 web-all 全家桶（含 remote-web-ui）
    $desktopPkg = Join-Path $DshTarget "profiles\desktop\package.json"
    if (Test-Path $desktopPkg) {
        $pkgText = Get-Content $desktopPkg -Raw -Encoding UTF8
        if ($pkgText -match 'dsh-web-all|dsh-remote-web-ui') {
            Write-Host "[WARN] 桌面版 profile 里装了 web-all / remote-web-ui" -ForegroundColor Yellow
            Write-Host "       该插件的配对门控会让桌面版客户端访问 /api 返回 403。" -ForegroundColor Yellow
            Write-Host "       请在【桌面版应用内】的插件管理里卸载它（不要手动改 desktop profile）。" -ForegroundColor Yellow
        } else {
            Write-Host "[OK] 桌面版 profile 未装 web-all（无 403 风险）" -ForegroundColor Green
        }
    }

    # 提示可能残留的 web profile
    $webProfile = Join-Path $DshTarget "profiles\web"
    if (Test-Path $webProfile) {
        Write-Host "[INFO] 存在 profiles\web（Web 版配置）。桌面版不读它，可忽略；" -ForegroundColor DarkGray
        Write-Host "       若本机只用桌面版，可删除该目录以保持整洁。" -ForegroundColor DarkGray
    }
}

# ---- 凭证提醒 ----
Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  [注意] 凭证文件需要手动配置！" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 复制凭证模板:" -ForegroundColor Cyan
Write-Host "   copy `"$DshSource\.credentials.yaml.example`" `"$DshTarget\.credentials.yaml`"" -ForegroundColor White
Write-Host ""
Write-Host "2. 编辑并填入你的 API key（DEEPSEEK_API_KEY + SCNET_API_KEY）:" -ForegroundColor Cyan
Write-Host "   notepad `"$DshTarget\.credentials.yaml`"" -ForegroundColor White
Write-Host ""
Write-Host "部署完成！（模式: $Mode）" -ForegroundColor Green
if ($Mode -eq 'desktop') {
    Write-Host "现在可以启动 DSH Desktop 应用。" -ForegroundColor White
} else {
    Write-Host "现在可以运行: dsh web" -ForegroundColor White
}
Write-Host ""
