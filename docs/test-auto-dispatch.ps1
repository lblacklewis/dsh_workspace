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
# MySQL 密码不写死：优先环境变量，没设则交互输入
$MYSQL_PASS = if ($env:MYSQL_PASS) { $env:MYSQL_PASS } else { Read-Host '请输入 MySQL 密码(java_dev)' }

function Sql($q) {
    $s = "mysql -ujava_dev -p$MYSQL_PASS -N java_dev -e `"$q`" 2>/dev/null"
    $b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s))
    return (ssh -o StrictHostKeyChecking=no root@82.156.226.192 "echo $b | base64 -d | bash" 2>&1 | Out-String).Trim()
}

W "$T\p1.json" '{"account":"13800138000","password":"123456","type":"h5"}'
W "$T\p2.json" '{"account":"admin","pwd":"123456"}'
$ft = (Post "$P/login" $null "$T\p1.json" | ConvertFrom-Json).data.token
$at = (Post "$A/login" $null "$T\p2.json" | ConvertFrom-Json).data.token
Write-Host ("  tokens: front=" + $ft.Substring(0,8) + " admin=" + $at.Substring(0,8))

# 清空购物车 + 确保没有历史配送单
Sql "DELETE FROM eb_store_cart WHERE uid=55" | Out-Null
Sql "DELETE FROM eb_delivery_order" | Out-Null
Sql "DELETE FROM eb_delivery_callback_log" | Out-Null

# 加购（商品 170 非处方药）
W "$T\c.json" '{"productId":170,"productAttrUnique":"3401","cartNum":1}'
$save = Post "$P/cart/save" $ft "$T\c.json" | ConvertFrom-Json
Write-Host ("  加购: code=" + $save.code)
$cart = (curl.exe -s "$P/cart/list?isValid=true" -H "Authori-zation: $ft" | ConvertFrom-Json).data.list
if (-not $cart -or $cart.Count -eq 0) { Write-Host "  [!] 购物车为空，终止"; exit 1 }
$cid = $cart[0].id

# 预下单
W "$T\po.json" ('{"preOrderType":"shoppingCart","orderDetails":[{"shoppingCartId":' + $cid + ',"productNum":1}]}')
$pre = (Post "$P/order/pre/order" $ft "$T\po.json" | ConvertFrom-Json)
if (-not $pre.data -or -not $pre.data.preOrderNo) { Write-Host ("  [!] 预下单失败: " + $pre.message); exit 1 }
Write-Host ("  预下单: " + $pre.data.preOrderNo)

# 建单：shippingType=3 同城即时配送
W "$T\co.json" ('{"preOrderNo":"' + $pre.data.preOrderNo + '","shippingType":3,"addressId":13,"useIntegral":false}')
$co = (Post "$P/order/create" $ft "$T\co.json" | ConvertFrom-Json)
if (-not $co.data -or -not $co.data.orderNo) { Write-Host ("  [!] 建单失败: " + $co.message); exit 1 }
$orderNo = $co.data.orderNo
Write-Host ("  建单成功: " + $orderNo + "   (shippingType=3 同城即时配送)")

$oid = Sql "SELECT id FROM eb_store_order WHERE order_id='$orderNo'"
Write-Host ("  订单 id = " + $oid)
Write-Host ("  支付前配送单数 = " + (Sql "SELECT COUNT(*) FROM eb_delivery_order"))

# 余额支付 —— 这一步会触发 paySuccess，里面应该自动发单
W "$T\pay.json" ('{"orderNo":"' + $orderNo + '","payType":"yue","payChannel":"weixinh5"}')
$pay = Post "$P/pay/payment" $ft "$T\pay.json" | ConvertFrom-Json
Write-Host ("`n  支付: code=" + $pay.code + " message=" + $pay.message + " data=" + ($pay.data | ConvertTo-Json -Compress))

Start-Sleep -Seconds 4
$paid = Sql "SELECT paid FROM eb_store_order WHERE order_id='$orderNo'"
Write-Host ("  订单 paid = " + $paid)
Write-Host ("  支付后配送单数 = " + (Sql "SELECT COUNT(*) FROM eb_delivery_order"))
Write-Host ""
Write-Host "  === 自动生成的配送单 ==="
Write-Host (Sql "SELECT CONCAT('    order_id=',order_id,' provider=',provider,' outer_no=',IFNULL(outer_no,'-'),' status=',status,' 收货人=',IFNULL(receiver_name,'-')) FROM eb_delivery_order WHERE order_id=$oid")

Write-Host "`n  === 日志里的自动发单记录 ==="
$s = "grep -o '同城配送已自动发单[^`"]*' /opt/storapp/front.log | tail -3"
$b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s))
ssh -o StrictHostKeyChecking=no root@82.156.226.192 "echo $b | base64 -d | bash" 2>&1
$s2 = "grep -o '同城配送自动发单失败[^`"]*' /opt/storapp/front.log | tail -3"
$b2 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s2))
ssh -o StrictHostKeyChecking=no root@82.156.226.192 "echo $b2 | base64 -d | bash" 2>&1
