# 同城配送回归测试（第 21 轮修复后）
#
# 为什么跑两轮：本轮把 currentProvider() 从「取 sort 最小的一条」改成
# 「按 sort 遍历、跳过代码未实现的」。要验证两件事：
#   1. 正常发单链路没被改坏（第一轮）
#   2. 同一订单重复支付不会重复发单（幂等，第二轮复用同一订单再走一次支付回调路径）
#
# 只清购物车，**不清 eb_delivery_order** —— 要留证据，也避免误删线上演示数据。

$ErrorActionPreference = "Continue"
$API = "http://82.156.226.192"
$P = "$API/front-api/api/front"
$A = "$API/dev-api/api/admin"
$T = $env:TEMP

function W($n, $t) { [System.IO.File]::WriteAllText($n, $t, [System.Text.UTF8Encoding]::new($false)) }
function Post($url, $token, $file) {
    if ($token) { return (curl.exe -s -X POST $url -H "Authori-zation: $token" -H "Content-Type: application/json" --data-binary "@$file") }
    return (curl.exe -s -X POST $url -H "Content-Type: application/json" --data-binary "@$file")
}
function Sql($q) {
    # MySQL 密码不写死：优先环境变量，没设则交互输入
    $mp = if ($env:MYSQL_PASS) { $env:MYSQL_PASS } else { Read-Host "请输入 MySQL 密码(java_dev)" }
    $s = "MYSQL_PWD=$mp mysql -ujava_dev java_dev -N -e `"$q`" 2>/dev/null"
    $b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s))
    return (ssh -o StrictHostKeyChecking=no root@82.156.226.192 "echo $b | base64 -d | bash" 2>&1 | Out-String).Trim()
}

$env:SSH_ASKPASS_REQUIRE = "force"; $env:DISPLAY = "dummy"
$env:SSH_ASKPASS = Join-Path $env:TEMP "ssh_askpass.bat"

W "$T\p1.json" '{"account":"13800138000","password":"123456","type":"h5"}'
$ft = (Post "$P/login" $null "$T\p1.json" | ConvertFrom-Json).data.token
Write-Host ("  前台 token: " + $ft.Substring(0,8) + "…")

# 发单前的配送单总数（用于判断是否新增）
$before = Sql "SELECT COUNT(*) FROM eb_delivery_order"
Write-Host "  发单前配送单总数: $before"

Sql "DELETE FROM eb_store_cart WHERE uid=55" | Out-Null

W "$T\c.json" '{"productId":170,"productAttrUnique":"3401","cartNum":1}'
$save = Post "$P/cart/save" $ft "$T\c.json" | ConvertFrom-Json
Write-Host ("  加购: code=" + $save.code)
$cart = (curl.exe -s "$P/cart/list?isValid=true" -H "Authori-zation: $ft" | ConvertFrom-Json).data.list
if (-not $cart -or $cart.Count -eq 0) { Write-Host "  [!] 购物车为空，终止"; exit 1 }
$cid = $cart[0].id

W "$T\po.json" ('{"preOrderType":"shoppingCart","orderDetails":[{"shoppingCartId":' + $cid + ',"productNum":1}]}')
$pre = (Post "$P/order/pre/order" $ft "$T\po.json" | ConvertFrom-Json)
if (-not $pre.data -or -not $pre.data.preOrderNo) { Write-Host ("  [!] 预下单失败: " + $pre.message); exit 1 }
Write-Host ("  预下单: " + $pre.data.preOrderNo)

W "$T\co.json" ('{"preOrderNo":"' + $pre.data.preOrderNo + '","shippingType":3,"addressId":13,"useIntegral":false}')
$co = (Post "$P/order/create" $ft "$T\co.json" | ConvertFrom-Json)
if (-not $co.data -or -not $co.data.orderNo) { Write-Host ("  [!] 建单失败: " + $co.message); exit 1 }
$orderNo = $co.data.orderNo
$oid = Sql "SELECT id FROM eb_store_order WHERE order_id='$orderNo'"
Write-Host ("  === 建单成功: $orderNo  (orderId=$oid, shippingType=3 同城即时配送) ===")

# 余额支付 -> 触发 paySuccess -> autoDispatchDelivery
W "$T\pay.json" ('{"orderNo":"' + $orderNo + '","payType":"yue","payChannel":"weixinh5"}')
$pay = Post "$P/pay/payment" $ft "$T\pay.json" | ConvertFrom-Json
Write-Host ("  支付: code=" + $pay.code + " msg=" + $pay.message)
Start-Sleep -Seconds 4

$paid = Sql "SELECT paid FROM eb_store_order WHERE order_id='$orderNo'"
$oid2 = Sql "SELECT id FROM eb_store_order WHERE order_id='$orderNo'"
Write-Host "  --- 第一轮：自动发单结果 ---"
Write-Host "  订单 paid = $paid"
Write-Host (Sql "SELECT CONCAT('    配送单: provider=',provider,' outer_no=',IFNULL(outer_no,'-'),' status=',status,' 骑手=',IFNULL(rider_name,'-'),' 收货人=',IFNULL(receiver_name,'-')) FROM eb_delivery_order WHERE order_id=$oid2")

# ---- 第二轮：对着同一订单再发一次支付（验证幂等，不会重复发单）----
Write-Host "`n  --- 第二轮：重复支付回调，验证幂等 ---"
$cnt1 = Sql "SELECT COUNT(*) FROM eb_delivery_order WHERE order_id=$oid2"
$pay2 = Post "$P/pay/payment" $ft "$T\pay.json" | ConvertFrom-Json
Write-Host ("  再次支付: code=" + $pay2.code + " msg=" + $pay2.message)
Start-Sleep -Seconds 3
$cnt2 = Sql "SELECT COUNT(*) FROM eb_delivery_order WHERE order_id=$oid2"
Write-Host "  该订单配送单数: 第一次=$cnt1  第二次=$cnt2"
if ($cnt1 -eq $cnt2 -and $cnt1 -eq "1") {
    Write-Host "  [OK] 幂等正常，没有重复发单"
} else {
    Write-Host "  [!!] 配送单数发生变化，幂等可能有问题"
}

Write-Host "`n  --- 日志验证 ---"
$s = "grep -o '同城配送已自动发单[^`"]*' /opt/storapp/front.log | tail -2; grep -o '已存在配送单[^`"]*' /opt/storapp/front.log | tail -2; grep -o '同城配送自动发单失败[^`"]*' /opt/storapp/front.log | tail -2"
$b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s))
ssh -o StrictHostKeyChecking=no root@82.156.226.192 "echo $b | base64 -d | bash" 2>&1

$after = Sql "SELECT COUNT(*) FROM eb_delivery_order"
Write-Host "`n  发单后配送单总数: $after （发单前 $before）"
