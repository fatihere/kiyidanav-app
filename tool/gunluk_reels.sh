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

ffmpeg -loglevel error -y -framerate 30 -i "$CIKTI/kare_%04d.png" \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -shortest \
  -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 20 -preset medium -r 30 \
  -c:a aac -b:a 128k -movflags +faststart "$CIKTI/gunluk_reels.mp4"
rm -f "$CIKTI"/kare_*.png
ls -la "$CIKTI"
