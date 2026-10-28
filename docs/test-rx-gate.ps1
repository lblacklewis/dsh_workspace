$ErrorActionPreference = "Continue"
$API = "http://82.156.226.192"
$P = "$API/front-api/api/front"

function PostJson($url, $token, $file) {
    if ($token) {
        return (curl.exe -s -X POST $url -H "Authori-zation: $token" -H "Content-Type: application/json" --data-binary "@$file")
    }
    return (curl.exe -s -X POST $url -H "Content-Type: application/json" --data-binary "@$file")
}
function WriteJson($name, $text) {
    [System.IO.File]::WriteAllText($name, $text, [System.Text.UTF8Encoding]::new($false))
    return $name
}

$T = $env:TEMP
WriteJson "$T\a1.json" '{"account":"13800138000","password":"123456","type":"h5"}'
WriteJson "$T\a2.json" '{"account":"admin","pwd":"123456"}'
$ft = (PostJson "$P/login" $null "$T\a1.json" | ConvertFrom-Json).data.token
$at = (PostJson "$API/dev-api/api/admin/login" $null "$T\a2.json" | ConvertFrom-Json).data.token
Write-Host ("  tokens: front=" + $ft.Substring(0,8) + " admin=" + $at.Substring(0,8))

function GetCartId($token) {
    $j = (curl.exe -s "$P/cart/list?isValid=true" -H "Authori-zation: $token") | ConvertFrom-Json
    if ($j.data -and $j.data.list -and $j.data.list.Count -gt 0) { return $j.data.list[0].id }
    return 0
}

# 纯 ASCII 判定：有 orderId 即建单成功；否则看 code=500 的 message
function TryCreate($token) {
    $cid = GetCartId $token
    if ($cid -eq 0) { return "NO_CART" }
    WriteJson "$T\po.json" ('{"preOrderType":"shoppingCart","orderDetails":[{"shoppingCartId":' + $cid + ',"productNum":1}]}') | Out-Null
    $pre = (PostJson "$P/order/pre/order" $token "$T\po.json" | ConvertFrom-Json)
    if (-not $pre.data -or -not $pre.data.preOrderNo) { return ("PRE_FAIL: " + $pre.message) }
    WriteJson "$T\co.json" ('{"preOrderNo":"' + $pre.data.preOrderNo + '","shippingType":1,"addressId":13,"useIntegral":false}') | Out-Null
    $r = PostJson "$P/order/create" $token "$T\co.json"
    try { $j = $r | ConvertFrom-Json } catch { return ("RAW: " + $r) }
    if ($j.data -and $j.data.orderId) { return "PASSED (orderId=" + $j.data.orderId + ")" }
    return ("BLOCKED [" + $j.code + "] " + $j.message)
}

Write-Host ""
Write-Host ("  step1 no-rx          -> " + (TryCreate $ft))
WriteJson "$T\rx.json" '{"patientName":"Zhang","idcard":"610113199001011234","images":"[\"/crmebimage/brand/ic-rx.svg\"]","diagnosis":"flu"}'
$rx = (PostJson "$P/prescription/upload" $ft "$T\rx.json" | ConvertFrom-Json).data
Write-Host ("  step2 uploaded       -> id=" + $rx.id + " status=" + $rx.auditStatus)
Write-Host ("  step3 pending-review -> " + (TryCreate $ft))
# audit 是 @RequestParam 接口，不需要 body；传 --data-binary @null 会让 curl 报错
$auditUrl = "$API/dev-api/api/admin/prescription/audit?id=$($rx.id)&pass=true&remark=OK"
$au = (curl.exe -s -X POST $auditUrl -H "Authori-zation: $at") | ConvertFrom-Json
if ($au.data) {
    Write-Host ("  step4 approved       -> auditStatus=" + $au.data.auditStatus + " validEnd=" + $au.data.validEnd)
} else {
    Write-Host ("  step4 approved       -> FAILED: " + $au.message)
}
Write-Host ("  step5 approved+nomark-> " + (TryCreate $ft))
