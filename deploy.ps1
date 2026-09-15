# ============================================================
#  StorApp 前端一键部署脚本
#  用法: .\deploy.ps1 -Target admin|h5|all
# ============================================================

param(
  [ValidateSet("admin","h5","all")]
  [string]$Target = "all"
)

$ErrorActionPreference = "Stop"
$SERVER = "root@82.156.226.192"
$SSH_PASS = "ofs;123"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  StorApp 前端部署脚本" -ForegroundColor Cyan
Write-Host "  目标: $Target" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---- Admin ----
function Deploy-Admin {
    Write-Host "[1/4] 打包 Admin ..." -ForegroundColor Yellow
    Push-Location "D:\project\StorApp\crmeb_java\admin"
    npm run build:prod 2>&1 | Select-String "DONE|ERROR|Build complete"
    Pop-Location
    
    Write-Host "[2/4] 压缩 admin/dist ..." -ForegroundColor Yellow
    $tarPath = "$env:TEMP\storapp-admin.tar.gz"
    Push-Location "D:\project\StorApp\crmeb_java\admin\dist"
    tar -czf $tarPath *
    Pop-Location
    
    Write-Host "[3/4] 上传到服务器 ..." -ForegroundColor Yellow
    scp $tarPath "${SERVER}:/tmp/storapp-admin.tar.gz"
    
    Write-Host "[4/4] 部署 ..." -ForegroundColor Yellow
    plink -pw $SSH_PASS $SERVER "mkdir -p /var/www/storapp/admin && cd /var/www/storapp/admin && rm -rf * && tar -xzf /tmp/storapp-admin.tar.gz && rm /tmp/storapp-admin.tar.gz && echo 'Admin deployed OK'"
    
    Remove-Item $tarPath -Force -ErrorAction SilentlyContinue
    Write-Host "Admin 部署完成!" -ForegroundColor Green
}

# ---- H5 ----
function Deploy-H5 {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  H5 需要手动构建！" -ForegroundColor Magenta
    Write-Host "  请在 HBuilderX 中执行:" -ForegroundColor Magenta
    Write-Host "  发行 → 网站-H5 → 勾选启用摇树优化 → 发行" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    $h5Dist = "D:\project\StorApp\crmeb_java\app\unpackage\dist\build\h5"
    
    if (-not (Test-Path $h5Dist)) {
        Write-Host "H5 dist 目录不存在: $h5Dist" -ForegroundColor Red
        Write-Host "请先在 HBuilderX 中发行 H5，然后重新运行本脚本。" -ForegroundColor Red
        return
    }
    
    Write-Host "[H5] 压缩上传..." -ForegroundColor Yellow
    $tarPath = "$env:TEMP\storapp-h5.tar.gz"
    Push-Location $h5Dist
    tar -czf $tarPath *
    Pop-Location
    
    scp $tarPath "${SERVER}:/tmp/storapp-h5.tar.gz"
    plink -pw $SSH_PASS $SERVER "mkdir -p /var/www/storapp/h5 && cd /var/www/storapp/h5 && rm -rf * && tar -xzf /tmp/storapp-h5.tar.gz && rm /tmp/storapp-h5.tar.gz && echo 'H5 deployed OK'"
    
    Remove-Item $tarPath -Force -ErrorAction SilentlyContinue
    Write-Host "H5 部署完成!" -ForegroundColor Green
}

# ---- Main ----
Write-Host ""

switch ($Target) {
    "admin" { Deploy-Admin }
    "h5"    { Deploy-H5 }
    "all"   { Deploy-Admin; Deploy-H5 }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  部署完成!" -ForegroundColor Green
Write-Host "  Admin: http://82.156.226.192/" -ForegroundColor Cyan
Write-Host "  H5:    http://82.156.226.192:8092/" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan