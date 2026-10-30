$ErrorActionPreference = "Continue"
$API = "http://82.156.226.192"
$A = "$API/dev-api/api/admin"
$T = $env:TEMP
function W($n, $t) { [System.IO.File]::WriteAllText($n, $t, [System.Text.UTF8Encoding]::new($false)) }

# 登录
W "$T\a.json" '{"account":"admin","pwd":"123456"}'
$at = (curl.exe -s -X POST "$A/login" -H "Content-Type: application/json" --data-binary "@$T\a.json" | ConvertFrom-Json).data.token
$H = "Authori-zation: $at"
Write-Host ("  admin token: " + $at.Substring(0,10) + "…")

function PostJson($url, $json) {
  W "$T\body.json" $json
  return (curl.exe -s -X POST $url -H $H -H "Content-Type: application/json" --data-binary "@$T\body.json")
}
function GetApi($url) { return (curl.exe -s $url -H $H) }

Write-Host "`n=== 1) 初始状态：有没有可审方药师 ==="
GetApi "$A/pharmacist/has/reviewer"
Write-Host ""

Write-Host "`n=== 2) 尝试开启审方权限但不填注册单位（应被拒绝）==="
PostJson "$A/pharmacist/create" '{"name":"测试药师","certNo":"TEST-CERT-001","reviewEnabled":true}'
Write-Host ""

Write-Host "`n=== 3) 尝试开启审方权限但注册有效期已过期（应被拒绝）==="
PostJson "$A/pharmacist/create" '{"name":"测试药师","certNo":"TEST-CERT-001","reviewEnabled":true,"registerUnit":"StorApp健康药房","registerValidEnd":"2020-01-01"}'
Write-Host ""

Write-Host "`n=== 4) 尝试不开审方权限却要公示（应被拒绝）==="
PostJson "$A/pharmacist/create" '{"name":"测试药师","certNo":"TEST-CERT-001","isPublic":true}'
Write-Host ""

Write-Host "`n=== 5) 正常创建（可审方 + 公示 + 身份证应被加密）==="
PostJson "$A/pharmacist/create" '{"name":"王药师","certNo":"1102024001","certAuthority":"北京市药品监督管理局","registerUnit":"StorApp健康药房有限公司","registerValidEnd":"2030-12-31","certValidEnd":"2030-12-31","phone":"13800001111","idcard":"110101199001011234","reviewEnabled":true,"isPublic":true,"outPharmacistId":"PH001","remark":"演示用"}'
Write-Host ""

Write-Host "`n=== 6) 现在有可审方药师了吗 ==="
GetApi "$A/pharmacist/has/reviewer"
Write-Host ""

Write-Host "`n=== 7) 列表（身份证必须脱敏，不能出现明文）==="
GetApi "$A/pharmacist/list"
Write-Host ""