#!/usr/bin/env bash
# "Bugün balık kaç metrede?" günlük Reels: kareleri üretir ve Instagram'a uygun MP4'e çevirir.
#   tool/gunluk_reels.sh [çıktı klasörü]
# Gerekenler: flutter, ffmpeg, Barlow yazı tipleri (GUNLUK_REELS_FONT klasöründe; yoksa indirilir).
# Çıktı: <klasör>/gunluk_reels.mp4 (1080x1920, H.264 + sessiz AAC, 30 fps), aciklama.txt, veri.json, secilen.json
set -euo pipefail
CIKTI="${1:-build/gunluk_reels}"
FONT="${GUNLUK_REELS_FONT:-build/gunluk_reels_font}"
mkdir -p "$FONT"
for f in barlowcondensed/BarlowCondensed-ExtraBold barlowcondensed/BarlowCondensed-Bold barlow/Barlow-SemiBold barlow/Barlow-Medium; do
  [ -f "$FONT/$(basename $f).ttf" ] || curl -fsSL -o "$FONT/$(basename $f).ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/$f.ttf"
done
[ -f "$FONT/NotoColorEmoji.ttf" ] || curl -fsSL -o "$FONT/NotoColorEmoji.ttf" "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/NotoColorEmoji.ttf" || true

rm -rf "$CIKTI" && mkdir -p "$CIKTI"
export FLUTTER_ROOT="${FLUTTER_ROOT:-$(dirname "$(dirname "$(command -v flutter)")")}"
GUNLUK_REELS=1 GUNLUK_REELS_CIKTI="$CIKTI" GUNLUK_REELS_FONT="$FONT" flutter test test/gunluk_reels_test.dart

# Müzik (tool/muzik/*.mp3, telifsiz): parçalar sırayla döner (art arda iki gün aynı parça çalmaz),
# parçanın başlangıç saniyesi tarihe göre değişir; başta 0,5 sn açılış, sonda 1,5 sn kısılma.
SURE=$(cat "$CIKTI/sure.txt")
mapfile -t MUZIKLER < <(ls tool/muzik/*.mp3 2>/dev/null | sort)
if [ "${#MUZIKLER[@]}" -gt 0 ]; then
  GUN=$((10#$(date +%j)))
  MUZIK="${MUZIKLER[$((GUN % ${#MUZIKLER[@]}))]}"
  MSURE=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$MUZIK" | cut -d. -f1)
  ARALIK=$(( MSURE - ${SURE%.*} - 15 )); [ "$ARALIK" -lt 1 ] && ARALIK=1
  BAS=$(( 5 + ($(date +%Y%m%d) % ARALIK) ))
  KIS=$(awk -v s="$SURE" 'BEGIN{printf "%.2f", s-1.5}')
  echo "müzik: $MUZIK, başlangıç ${BAS}. sn"
  basename "$MUZIK" > "$CIKTI/muzik.txt"
  ffmpeg -loglevel error -y -framerate 30 -i "$CIKTI/kare_%04d.png" -ss "$BAS" -i "$MUZIK" \
    -filter_complex "[1:a]atrim=0:${SURE},asetpts=PTS-STARTPTS,afade=t=in:d=0.5,afade=t=out:st=${KIS}:d=1.5,volume=0.8[a]" \
    -map 0:v -map "[a]" -shortest \
    -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 20 -preset medium -r 30 \
    -c:a aac -b:a 160k -ar 44100 -movflags +faststart "$CIKTI/gunluk_reels.mp4"
else
  ffmpeg -loglevel error -y -framerate 30 -i "$CIKTI/kare_%04d.png" \
    -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -shortest \
    -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 20 -preset medium -r 30 \
    -c:a aac -b:a 128k -movflags +faststart "$CIKTI/gunluk_reels.mp4"
fi
rm -f "$CIKTI"/kare_*.png
ls -la "$CIKTI"
