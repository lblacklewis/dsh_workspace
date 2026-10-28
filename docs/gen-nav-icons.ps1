# 生成底部导航图标（teal 选中态 + 灰常态）
$ErrorActionPreference = "Stop"
$out = "D:\project\StorApp\crmeb_java\docs\brand\nav"
New-Item -ItemType Directory -Path $out -Force | Out-Null

$ON  = "#0D9488"
$OFF = "#94A3B8"

# 每个图标的 path 内容（48x48 线性图标）
$icons = @{
  "home" = @"
    <path d="M9 21V19.5L24 8l15 11.5V21"/>
    <path d="M13 21v-7.5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2V21"/>
    <path d="M9 21h30"/>
"@
  "cate" = @"
    <rect x="9" y="9" width="12" height="12" rx="3.5"/>
    <rect x="27" y="9" width="12" height="12" rx="3.5"/>
    <rect x="9" y="27" width="12" height="12" rx="3.5"/>
    <rect x="27" y="27" width="12" height="12" rx="3.5"/>
"@
  "cart" = @"
    <path d="M7 10h4.2l3.6 18.5h19.4L38 15H13"/>
    <circle cx="18" cy="34.5" r="3"/>
    <circle cx="32" cy="34.5" r="3"/>
"@
  "user" = @"
    <circle cx="24" cy="16.5" r="6.5"/>
    <path d="M11.5 39.5c0-7 5.6-11.5 12.5-11.5s12.5 4.5 12.5 11.5"/>
"@
}

foreach ($k in $icons.Keys) {
  foreach ($state in @(@{suffix=""; color=$OFF}, @{suffix="-on"; color=$ON})) {
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <g stroke="$($state.color)" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round">
$($icons[$k])
  </g>
</svg>
"@
    [System.IO.File]::WriteAllText("$out\nav-$k$($state.suffix).svg", $svg, [System.Text.UTF8Encoding]::new($false))
  }
}

$files = Get-ChildItem $out -Filter *.svg
Write-Host "生成 $($files.Count) 个导航图标:"
$files | ForEach-Object { Write-Host ("  " + $_.Name) }
