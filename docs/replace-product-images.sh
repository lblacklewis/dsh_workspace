#!/usr/bin/env bash
# 商品图片替换（demo 用）
#
# 为什么要有这个脚本：图片是从网上取的实拍图，处理完直接放到服务器上了，
# 只留在服务器上就不可复现、也没法解释来源。这里把来源和处理方式固定下来。
#
# 图片来源：Pexels（https://www.pexels.com/license/）
#   免费商用、无需署名。直链形如
#   https://images.pexels.com/photos/<id>/pexels-photo-<id>.jpeg
#
# 注意：沙箱内本机 shell 不能出网，但服务器可以，所以下载在服务器上做。
#
# 处理方式：统一居中裁成 800x800，保证网格里高矮一致 —— 混用不同比例的
# 实拍图会让商品列表看起来参差不齐，这是最容易露怯的地方。
#
# 用法：在服务器上执行  bash replace-product-images.sh

set -e
DIR=/opt/storapp/crmeb/crmebimage/brand/products
TMP=/tmp/pics
mkdir -p "$DIR" "$TMP"
cd "$TMP"

# 商品id:pexels图片id:说明
MAP="
101:3923166:感冒灵颗粒（手持药板，白底干净）
167:9407935:健胃消食片（黄色椭圆药片）
170:28751316:维生素C咀嚼片（药瓶倒出药片+橙子）
159:140123:布洛芬缓释胶囊（铝箔板）
168:3683074:蒙脱石散（分装药盒）
100:12203710:电子血压计
"

for row in $MAP; do
  id=$(echo "$row" | cut -d: -f1)
  pid=$(echo "$row" | cut -d: -f2)
  src="$TMP/src_$pid.jpeg"
  if [ ! -s "$src" ]; then
    curl -s -o "$src" --max-time 30 -A "Mozilla/5.0" \
      "https://images.pexels.com/photos/$pid/pexels-photo-$pid.jpeg?auto=compress&cs=tinysrgb&w=1200"
  fi
  convert "$src" -auto-orient -resize 800x800^ -gravity center -extent 800x800 \
    -strip -quality 86 "$DIR/p$id.jpg"
  echo "  p$id.jpg  <- pexels/$pid  $(stat -c%s "$DIR/p$id.jpg")B"
done

# 云南白药创可贴：没有找到可免费商用的实拍图（搜到的都是 Envato/Alamy 付费图源），
# 用 ImageMagick 画一个。风格和主题的清爽医疗风一致（薄荷底 + 米色敷贴）。
convert -size 800x800 xc:'#F0FDFA' \
  -fill '#F5D9A8' -stroke '#E0BC7A' -strokewidth 3 \
  -draw "roundrectangle 130,330 670,470 70,70" \
  -fill '#FFF7EC' -stroke '#E8D3AE' -strokewidth 2 \
  -draw "roundrectangle 330,355 470,445 26,26" \
  -fill '#E8D3AE' -stroke none \
  -draw "circle 200,400 200,388" -draw "circle 240,400 240,388" -draw "circle 280,400 280,388" \
  -draw "circle 520,400 520,388" -draw "circle 560,400 560,388" -draw "circle 600,400 600,388" \
  -strip -quality 90 "$DIR/p102.jpg"
echo "  p102.jpg  <- ImageMagick 绘制（无合适免费实拍图）"

echo ""
echo "接着更新数据库（image 与 slider_image 都要改，否则详情页还是旧图）："
cat <<'SQL'
UPDATE eb_store_product SET image='crmebimage/brand/products/p100.jpg', slider_image='["crmebimage/brand/products/p100.jpg"]' WHERE id=100;
UPDATE eb_store_product SET image='crmebimage/brand/products/p101.jpg', slider_image='["crmebimage/brand/products/p101.jpg"]' WHERE id=101;
UPDATE eb_store_product SET image='crmebimage/brand/products/p102.jpg', slider_image='["crmebimage/brand/products/p102.jpg"]' WHERE id=102;
UPDATE eb_store_product SET image='crmebimage/brand/products/p159.jpg', slider_image='["crmebimage/brand/products/p159.jpg"]' WHERE id=159;
UPDATE eb_store_product SET image='crmebimage/brand/products/p167.jpg', slider_image='["crmebimage/brand/products/p167.jpg"]' WHERE id=167;
UPDATE eb_store_product SET image='crmebimage/brand/products/p168.jpg', slider_image='["crmebimage/brand/products/p168.jpg"]' WHERE id=168;
UPDATE eb_store_product SET image='crmebimage/brand/products/p170.jpg', slider_image='["crmebimage/brand/products/p170.jpg"]' WHERE id=170;
SQL
