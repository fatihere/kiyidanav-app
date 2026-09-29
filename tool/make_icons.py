"""kiyidanav.com logosundan tüm Android simgelerini ve Play Store görsellerini üretir.

Girdi : assets/brand/logo.png (siteden indirilen logo), assets/fonts/Armata-Regular.ttf
Çıktı : android/app/src/main/res/...  (uygulama simgesi, uyarlanabilir simge, bildirim simgesi)
        assets/brand/logo.png            (uygulama içi, 512 px'e küçültülmüş)
        build/store/                     (Play Store: 512 simge, 1024x500 tanıtım görseli)
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RES = Path('android/app/src/main/res')
STORE = Path('build/store')
DPI = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
ZEYTIN = (111, 107, 69)
ZEYTIN_KOYU = (74, 71, 48)
TURUNCU = (244, 108, 34)


def load_logo():
    p = Path('assets/brand/logo.png')
    if not p.exists():
        sys.exit('HATA: assets/brand/logo.png yok')
    img = Image.open(p).convert('RGBA')
    bbox = img.getbbox()  # şeffaf kenarları kırp
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    side = max(w, h)
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(img, ((side - w) // 2, (side - h) // 2))
    return sq


def centered(logo, size, ratio, bg=(0, 0, 0, 0)):
    canvas = Image.new('RGBA', (size, size), bg)
    inner = max(1, int(size * ratio))
    canvas.alpha_composite(logo.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
    return canvas


def fish(size):
    """Beyaz balık silüeti (Android bildirim simgesi tek renk olmalı)"""
    s = size * 4
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = (255, 255, 255, 255)
    d.ellipse((s * 0.10, s * 0.28, s * 0.72, s * 0.72), fill=w)                      # gövde
    d.polygon([(s * 0.64, s * 0.50), (s * 0.94, s * 0.24), (s * 0.94, s * 0.76)], fill=w)  # kuyruk
    d.ellipse((s * 0.22, s * 0.40, s * 0.30, s * 0.48), fill=(0, 0, 0, 0))            # göz
    return im.resize((size, size), Image.LANCZOS)


def main():
    logo = load_logo()

    for name, k in DPI.items():
        # Klasik simge (eski Android'ler)
        d = RES / f'mipmap-{name}'
        d.mkdir(parents=True, exist_ok=True)
        centered(logo, int(48 * k), 0.92).save(d / 'ic_launcher.png')
        # Uyarlanabilir simgenin ön katmanı (108dp tuval, logo güvenli alanda)
        d = RES / f'drawable-{name}'
        d.mkdir(parents=True, exist_ok=True)
        centered(logo, int(108 * k), 0.62).save(d / 'ic_launcher_foreground.png')
        fish(int(24 * k)).save(d / 'ic_stat_notify.png')

    any_dir = RES / 'mipmap-anydpi-v26'
    any_dir.mkdir(parents=True, exist_ok=True)
    (any_dir / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n')
    (RES / 'values').mkdir(parents=True, exist_ok=True)
    (RES / 'values' / 'ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#FFFFFF</color>\n'
        '    <color name="bildirim_rengi">#F46C22</color>\n</resources>\n')
    # Kod küçültme (R8) bildirim simgesini silmesin
    (RES / 'raw').mkdir(parents=True, exist_ok=True)
    (RES / 'raw' / 'keep.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources xmlns:tools="http://schemas.android.com/tools"\n'
        '    tools:keep="@drawable/ic_stat_notify,@drawable/ic_launcher_foreground,@mipmap/ic_launcher" />\n')

    # Uygulama içi logo (APK boyutu için 512 px)
    centered(logo, 512, 1.0).save('assets/brand/logo.png', optimize=True)

    # Play Store görselleri
    STORE.mkdir(parents=True, exist_ok=True)
    centered(logo, 512, 0.86, bg=(255, 255, 255, 255)).convert('RGB').save(STORE / 'play-simge-512.png')
    fg = Image.new('RGB', (1024, 500), ZEYTIN)
    d = ImageDraw.Draw(fg)
    d.rectangle((0, 430, 1024, 500), fill=ZEYTIN_KOYU)
    d.rectangle((0, 424, 1024, 430), fill=TURUNCU)
    circle = Image.new('RGBA', (330, 330), (0, 0, 0, 0))
    ImageDraw.Draw(circle).ellipse((0, 0, 329, 329), fill=(255, 255, 255, 255))
    circle.alpha_composite(logo.resize((300, 300), Image.LANCZOS), (15, 15))
    fg.paste(circle, (60, 50), circle)
    try:
        big = ImageFont.truetype('assets/fonts/Armata-Regular.ttf', 74)
        small = ImageFont.truetype('assets/fonts/Armata-Regular.ttf', 30)
    except OSError:
        big = small = ImageFont.load_default()
    d.text((430, 120), 'KıyıdanAv', font=big, fill=(255, 255, 255))
    d.text((432, 225), 'Kıyı balıkçılığı mağazası', font=small, fill=(249, 199, 177))
    d.text((432, 270), 'Günlük av raporu · Deniz durumu', font=small, fill=(255, 255, 255))
    d.text((432, 445), 'kiyidanav.com', font=small, fill=(255, 255, 255))
    fg.save(STORE / 'play-tanitim-1024x500.png')
    print('Simgeler ve mağaza görselleri üretildi')


if __name__ == '__main__':
    main()
