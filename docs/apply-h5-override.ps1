# 把 docs/h5-override.css 注入到 H5 构建产物的 index.html
# 用法: .\apply-h5-override.ps1 -IndexHtml "D:\project\StorApp\crmeb_java\app\unpackage\dist\build\h5\index.html"
param(
  [Parameter(Mandatory = $true)][string]$IndexHtml
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $IndexHtml)) { throw "找不到 $IndexHtml" }
$cssPath = Join-Path $PSScriptRoot "h5-override.css"
$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.UTF8Encoding]::new($false))

$html = [System.IO.File]::ReadAllText($IndexHtml, [System.Text.UTF8Encoding]::new($false))

# 幂等：先移除旧块
$html = [regex]::Replace($html, '<style id="storapp-override">.*?</style>', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)

$block = '<style id="storapp-override">' + "`n" + $css + "`n" + '</style>'
if ($html -notmatch '</head>') { throw "index.html 里找不到 </head>" }
$html = $html -replace '</head>', ($block + '</head>')

[System.IO.File]::WriteAllText($IndexHtml, $html, [System.Text.UTF8Encoding]::new($false))
Write-Host "已注入覆盖样式 -> $IndexHtml"
