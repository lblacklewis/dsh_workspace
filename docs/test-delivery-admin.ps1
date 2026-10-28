$ErrorActionPreference = "Continue"
$API = "http://82.156.226.192"
$A = "$API/dev-api/api/admin"

[System.IO.File]::WriteAllText("$env:TEMP\l2.json", '{"account":"admin","pwd":"123456"}', [System.Text.UTF8Encoding]::new($false))
$at = (curl.exe -s -X POST "$API/dev-api/api/admin/login" -H "Content-Type: application/json" --data-binary "@$env:TEMP\l2.json" | ConvertFrom-Json).data.token

function Sql($q) {
    $s = "mysql -ujava_dev -pNPKntRXcCrx2AZ3i -N java_dev -e `"$q`" 2>/dev/null"
    $b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s))
    return (ssh -o StrictHostKeyChecking=no root@82.156.226.192 "echo $b | base64 -d | bash").Trim()
}

# 造一条测试订单（内容是演示用的，跑完删掉）
Sql "INSERT INTO eb_store_order (order_id, uid, real_name, user_phone, user_address, mark, cost, total_num, total_price, pro_total_price, pay_price, pay_postage, status, paid, shipping_type, type, create_time) VALUES ('TESTDELIVERY0001', 55, 'Demo', '13800138000', 'Test Address', '', 0.00, 1, 39.90, 39.90, 39.90, 0.00, 1, 0, 3, 0, NOW())" | Out-Null
$oid = Sql "SELECT id FROM eb_store_order WHERE order_id='TESTDELIVERY0001'"
Write-Host ("  test order id = " + $oid)

Write-Host "`n  --- dispatch ---"
$d = (curl.exe -s -X POST "$A/delivery/dispatch?orderId=$oid" -H "Authori-zation: $at" | ConvertFrom-Json)
Write-Host ("  code=" + $d.code + " provider=" + $d.data.provider + " outerNo=" + $d.data.outerNo + " status=" + $d.data.status + " receiver=" + $d.data.receiverName)

$d2 = (curl.exe -s -X POST "$A/delivery/dispatch?orderId=$oid" -H "Authori-zation: $at" | ConvertFrom-Json)
Write-Host ("  idempotent: sameId=" + ($d2.data.id -eq $d.data.id) + " sameOuterNo=" + ($d2.data.outerNo -eq $d.data.outerNo))

$l = (curl.exe -s "$A/delivery/list?status=1&limit=10" -H "Authori-zation: $at" | ConvertFrom-Json)
Write-Host ("  list(status=1) count=" + $l.data.Count)

Write-Host "`n  --- status progression ---"
foreach ($t in @(0, 10, 14, 16, 16)) {
    if ($t -gt 0) { Start-Sleep -Seconds $t }
    $i = (curl.exe -s "$A/delivery/info/$oid" -H "Authori-zation: $at" | ConvertFrom-Json).data
    Write-Host ("    [{0:HH:mm:ss}] status={1} {2} rider={3}" -f (Get-Date), $i.status, $i.statusDesc, $i.riderName)
}

Write-Host "`n  --- cancel a fresh one ---"
Sql "INSERT INTO eb_store_order (order_id, uid, real_name, user_phone, user_address, mark, cost, total_num, total_price, pro_total_price, pay_price, pay_postage, status, paid, shipping_type, type, create_time) VALUES ('TESTDELIVERY0002', 55, 'Demo2', '13800138000', 'Test Address 2', '', 0.00, 1, 39.90, 39.90, 39.90, 0.00, 1, 0, 3, 0, NOW())" | Out-Null
$oid2 = Sql "SELECT id FROM eb_store_order WHERE order_id='TESTDELIVERY0002'"
curl.exe -s -X POST "$A/delivery/dispatch?orderId=$oid2" -H "Authori-zation: $at" | Out-Null
$c = (curl.exe -s -X POST "$A/delivery/cancel?orderId=$oid2&reason=test" -H "Authori-zation: $at" | ConvertFrom-Json)
Write-Host ("  cancel: code=" + $c.code + " msg=" + $c.message + " data=" + $c.data)
$i2 = (curl.exe -s "$A/delivery/info/$oid2" -H "Authori-zation: $at" | ConvertFrom-Json).data
Write-Host ("  after cancel: status=" + $i2.status + " " + $i2.statusDesc)
