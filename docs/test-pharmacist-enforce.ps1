$ErrorActionPreference = "Continue"
$API = "http://82.156.226.192"
$A = "$API/dev-api/api/admin"
$T = $env:TEMP
function W($n, $t) { [System.IO.File]::WriteAllText($n, $t, [System.Text.UTF8Encoding]::new($false)) }

W "$T\a.json" '{"account":"admin","pwd":"123456"}'
$at = (curl.exe -s -X POST "$A/login" -H "Content-Type: application/json" --data-binary "@$T\a.json" | ConvertFrom-Json).data.token
$H = "Authori-zation: $at"
Write-Host ("  admin token: " + $at.Substring(0,10) + "…")

Write-Host "`n=== A) 打开 enforcement 的效果：有合格药师时，非药师 id 不能审方 ==="
Write-Host -NoNewline "  id=1 (王药师，合格)   -> "
curl.exe -s "$A/pharmacist/can/review?pharmacistId=1" -H $H
Write-Host ""
Write-Host -NoNewline "  id=999 (不存在的药师) -> "
curl.exe -s "$A/pharmacist/can/review?pharmacistId=999" -H $H
Write-Host ""
Write-Host -NoNewline "  id=0 (后台管理员id)   -> "
curl.exe -s "$A/pharmacist/can/review?pharmacistId=0" -H $H
Write-Host ""

Write-Host "`n=== B) 用 admin 账号走真实审方接口（admin.id 大概率不是 1，应被拦）==="
$rxId = 17
$r = curl.exe -s -X POST "$A/prescription/audit?id=$rxId&pass=true&remark=" -H $H
Write-Host "  $r"

Write-Host "`n=== C) 该处方的最终状态 ==="
Write-Host "  （见下一步 SQL 查询）"
