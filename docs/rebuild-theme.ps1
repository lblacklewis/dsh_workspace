# 重建 StorApp 医药版首页装修数据
$ErrorActionPreference = "Stop"
$f = "$env:TEMP\home_data.json"
$j = (Get-Content $f -Raw -Encoding UTF8) | ConvertFrom-Json

$IMG = "http://82.156.226.192/crmebimage/medical/"

# ---------- 1. 轮播搜索 ----------
$c0 = $j.value.'1772508227561000'
$c0.inputConfig.value = "搜索药品、症状、品牌"
$tabs = @(
  @{n="热销药品"; id=0;    cid="";    name=""},
  @{n="感冒用药"; id=900;  cid="900";  name="感冒用药"},
  @{n="肠胃用药"; id=1000; cid="1000"; name="肠胃用药"},
  @{n="医疗器械"; id=1500; cid="1500"; name="医疗器械"}
)
$list = @()
foreach ($t in $tabs) {
  $list += [pscustomobject]@{
    microPage = [pscustomobject]@{ name=""; id=0 }
    dataType   = [pscustomobject]@{ tabList=@([pscustomobject]@{name="微页面"},[pscustomobject]@{name="商品分类"}); tabVal=1; title="数据类型" }
    text       = [pscustomobject]@{ val=$t.n; pla="请输入分类名称"; max=4; title="显示文字" }
    classPage  = [pscustomobject]@{ name=$t.name; id=$t.id }
  }
}
$c0.tabListConfig.list = $list

# ---------- 2. 导航组（金刚区） ----------
$navItems = @(
  @{n="感冒用药"; i="respiratory.svg";      l="/pages/goods/goods_list/index?cid=900&title=感冒用药"},
  @{n="肠胃用药"; i="nutrition.svg";        l="/pages/goods/goods_list/index?cid=1000&title=肠胃用药"},
  @{n="皮肤用药"; i="dermatology.svg";      l="/pages/goods/goods_list/index?cid=1100&title=皮肤用药"},
  @{n="慢病用药"; i="cardiology.svg";       l="/pages/goods/goods_list/index?cid=1200&title=慢病用药"},
  @{n="医疗器械"; i="laboratory.svg";       l="/pages/goods/goods_list/index?cid=1500&title=医疗器械"},
  @{n="药品分类"; i="pharmacy.svg";         l="/pages/goods_cate/goods_cate"},
  @{n="健康资讯"; i="health-education.svg"; l="/pages/news/news_list/index"},
  @{n="健康积分"; i="health-services.svg";  l="/pages/users/user_integral/index"},
  @{n="我的订单"; i="medical-records.svg";  l="/pages/users/order_list/index"},
  @{n="领优惠券"; i="first-aid.svg";        l="/pages/users/user_get_coupon/index"}
)
$c1 = $j.value.'1772508227561001'
$mlist = @()
foreach ($it in $navItems) {
  $mlist += [pscustomobject]@{
    img  = $IMG + $it.i
    show = $true
    icon = ""
    type = 0
    info = @(
      [pscustomobject]@{ max=4;   title="标题"; value=$it.n; tips="选填，不超过4个字" }
      [pscustomobject]@{ max=100; title="链接"; value=$it.l; tips="请输入链接" }
    )
  }
}
$c1.menuConfig.list    = $mlist
$c1.menuConfig.title   = "最多可添加1张图片，建议宽度90 * 90px"
$c1.rowsNum.tabVal     = 1     # 2行
$c1.number.tabVal      = 2     # 5个/行
$c1.navDisplayStyle.tabVal = 0 # 图文展示
$c1.menuStyleConfig.tabVal = 1 # 宫格展示
$c1.gridStyle.tabVal   = 1     # 4个/行

# ---------- 3. 商品选项卡 ----------
$c7 = $j.value.'1772508227561007'
$names = @("热销药品","感冒用药","肠胃用药","医疗器械")
$i = 0
foreach ($t in $c7.tabConfig.list) {
  if ($i -lt $names.Count) { $t.chiild[0].val = $names[$i] }
  $i++
}

# ---------- 4. 底部导航 ----------
$c8 = $j.value.'1782177517295000'
$bnNames = @("首页","药品分类","购药车","我的")
$k = 0
foreach ($m in $c8.menuList) {
  if ($k -lt $bnNames.Count) { $m.name = $bnNames[$k] }
  $k++
}

# ---------- 5. 隐藏砍价/拼团 ----------
$j.value.'1772508227561004'.isHide = $true   # 拼团
$j.value.'1772508227561006'.isHide = $true   # 砍价

# ---------- 6. 序列化 + 配色替换 ----------
$out = $j | ConvertTo-Json -Depth 100 -Compress
$out = $out.Replace('#E93323', '#0D9488')
$out = $out.Replace('#e93323', '#0D9488')
$out = $out.Replace('#FF448F', '#0D9488')
$out = $out.Replace('#ff448f', '#0D9488')

# 校验可解析
$null = $out | ConvertFrom-Json
Write-Host "新 JSON 长度: $($out.Length) 字符"

$bytes = [System.Text.Encoding]::UTF8.GetBytes($out)
$b64 = [Convert]::ToBase64String($bytes)
$sql = "UPDATE eb_theme SET home_data = CONVERT(FROM_BASE64('$b64') USING utf8mb4) WHERE id = 1;"
[System.IO.File]::WriteAllText("$env:TEMP\theme_update.sql", $sql, [System.Text.UTF8Encoding]::new($false))
Write-Host "SQL 已生成, base64 长度: $($b64.Length)"
Write-Host "剩余红色引用: $(([regex]::Matches($out,'#E93323')).Count)"
Write-Host "teal 引用: $(([regex]::Matches($out,'#0D9488')).Count)"
