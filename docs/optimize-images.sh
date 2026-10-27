#!/bin/bash
# StorApp 图片批量优化：等比缩放到最大 800px 宽 + 有损压缩，文件名不变
set -u
cd /opt/storapp/crmeb/crmebimage || exit 1
LOG=/tmp/imgopt.log
: > "$LOG"

LIMITS="-limit memory 256MiB -limit map 512MiB -limit disk 2GiB"
BEFORE=$(du -sb . | cut -f1)
echo "start before=$BEFORE bytes" >> "$LOG"

n=0
find . -type f -name "*.png" -size +60k -print0 | while IFS= read -r -d '' f; do
  orig=$(stat -c%s "$f")
  convert $LIMITS "$f" -resize '800x>' -strip /tmp/_w.png 2>/dev/null || { echo "PNG FAIL $f" >> "$LOG"; continue; }
  pngquant --quality=65-85 --speed 1 --force --ext .png /tmp/_w.png 2>/dev/null || true
  new=$(stat -c%s /tmp/_w.png 2>/dev/null || echo 0)
  if [ "$new" -gt 0 ] && [ "$new" -lt "$orig" ]; then
    mv /tmp/_w.png "$f"
    echo "PNG $orig -> $new  $f" >> "$LOG"
  else
    rm -f /tmp/_w.png
    echo "PNG SKIP $orig  $f" >> "$LOG"
  fi
done

find . -type f \( -name "*.jpg" -o -name "*.jpeg" \) -size +60k -print0 | while IFS= read -r -d '' f; do
  orig=$(stat -c%s "$f")
  convert $LIMITS "$f" -resize '800x>' -strip -quality 82 /tmp/_w.jpg 2>/dev/null || { echo "JPG FAIL $f" >> "$LOG"; continue; }
  new=$(stat -c%s /tmp/_w.jpg 2>/dev/null || echo 0)
  if [ "$new" -gt 0 ] && [ "$new" -lt "$orig" ]; then
    mv /tmp/_w.jpg "$f"
    echo "JPG $orig -> $new  $f" >> "$LOG"
  else
    rm -f /tmp/_w.jpg
    echo "JPG SKIP $orig  $f" >> "$LOG"
  fi
done

AFTER=$(du -sb . | cut -f1)
DONE=$(grep -cE "^(PNG|JPG) [0-9]+ -> " "$LOG")
echo "DONE optimized=$DONE before=$BEFORE after=$AFTER" >> "$LOG"
echo "FINISHED" >> "$LOG"
