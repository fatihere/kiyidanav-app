"""1.14.0 — Yeni uygulama simgesi: olta ucunda sıçrayan levrek (düz/flat çizim, PIL ile).

Kullanım: python tool/levrek_simge.py <çıktı klasörü> [taslak]
  taslak verilmezse A, B ve C taslaklarını üretir. Her taslak için:
    levrek_<X>.png        1024×1024, saydamlık YOK (App Store ve tam simge)
    levrek_<X>_fg.png     1024×1024, saydam zemin (Android uyarlanabilir simge ön yüzü; güvenli alanda)
Çizim 4096 px'de yapılıp küçültülür (kenar yumuşatma).
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 4096
GECE = (14, 59, 67)
GECE_ACIK = (29, 89, 99)
TURUNCU = (244, 108, 34)
BEYAZ = (255, 255, 255)
SIRT = (52, 74, 92)
SIRT_KOYU = (33, 50, 64)
GUMUS = (214, 224, 230)
KARIN = (246, 249, 250)
YUZGEC = (86, 104, 118)


def bez(p0, p1, p2, p3, n=60):
    out = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t ** 2
        d = t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


class Balik:
    """Yerel koordinatta (x: burundan kuyruğa 0..1, y: sırt -, karın +) çizilen levreği
    bir yay boyunca büker ve döndürür."""

    def __init__(self, merkez, boy, aci, bukum):
        self.cx, self.cy = merkez
        self.L = boy
        self.aci = aci
        self.bukum = bukum

    def p(self, x, y):
        # gövde ekseni yay boyunca bükülür (sıçrama kavisi)
        u = (x - 0.5) * self.L
        egri = self.bukum * (u / self.L) ** 2 * self.L
        lx, ly = u, -(y * self.L + egri)  # ayna: sırt üst-sola, karın alt-sağa baksın
        ca, sa = math.cos(self.aci), math.sin(self.aci)
        return (self.cx + lx * ca - ly * sa, self.cy + lx * sa + ly * ca)

    def poligon(self, noktalar):
        return [self.p(x, y) for x, y in noktalar]


def kalinlik(x):
    # levrek: uzun, iğ biçimli; baş tarafı sivri, kuyruk sapı ince
    if x <= 0:
        return 0
    if x >= 0.86:
        return 0.035
    k = math.sin(math.pi * min(1, x / 0.86) ** 0.78) ** 0.85
    return 0.035 + 0.115 * k


def govde(b):
    ust = [(x / 100, -kalinlik(x / 100) * 0.95) for x in range(0, 87)]
    alt = [(x / 100, kalinlik(x / 100) * 1.0) for x in range(86, -1, -1)]
    return b.poligon(ust + alt)


def kuyruk(b):
    return b.poligon([(0.84, -0.03), (0.97, -0.16), (1.02, -0.15), (0.95, -0.02), (0.95, 0.02),
                      (1.02, 0.16), (0.97, 0.17), (0.84, 0.035)])


def sirt_yuzgeci_1(b):  # dikenli ön sırt yüzgeci
    pts = [(0.30, -kalinlik(0.30) * 0.92)]
    for i, x in enumerate([0.32, 0.36, 0.40, 0.44, 0.48, 0.51]):
        pts.append((x, -kalinlik(x) * 0.92 - (0.085 if i % 2 == 0 else 0.06) * (1 - (x - 0.32) * 1.1)))
    pts.append((0.53, -kalinlik(0.53) * 0.92))
    return b.poligon(pts)


def sirt_yuzgeci_2(b):
    return b.poligon([(0.56, -kalinlik(0.56) * 0.92), (0.60, -kalinlik(0.6) - 0.07), (0.70, -kalinlik(0.7) - 0.05),
                      (0.74, -kalinlik(0.74) * 0.92)])


def karin_yuzgeci(b):
    return b.poligon([(0.62, kalinlik(0.62) * 0.95), (0.70, kalinlik(0.7) + 0.06), (0.75, kalinlik(0.75) * 0.95)])


def gogus_yuzgeci(b):
    return b.poligon([(0.27, 0.01), (0.40, 0.07), (0.38, 0.03)])


def ciz(cizim, renk, pts):
    cizim.polygon(pts, fill=renk)


def levrek(img, b, olta_ucu=None, olta_renk=BEYAZ):
    d = ImageDraw.Draw(img)
    # misina (oltadan ağıza)
    agiz = b.p(0.012, 0.012)
    if olta_ucu:
        d.line([olta_ucu, agiz], fill=olta_renk, width=int(S * 0.009))
    ciz(d, YUZGEC, kuyruk(b))
    ciz(d, YUZGEC, sirt_yuzgeci_1(b))
    ciz(d, YUZGEC, sirt_yuzgeci_2(b))
    ciz(d, YUZGEC, karin_yuzgeci(b))
    ciz(d, KARIN, govde(b))
    # gümüş yan + koyu sırt bantları
    yan = [(x / 100, -kalinlik(x / 100) * 0.95) for x in range(2, 87)] + \
          [(x / 100, kalinlik(x / 100) * 0.25) for x in range(86, 1, -1)]
    ciz(d, GUMUS, b.poligon(yan))
    sirt = [(x / 100, -kalinlik(x / 100) * 0.95) for x in range(3, 87)] + \
           [(x / 100, -kalinlik(x / 100) * 0.35) for x in range(86, 2, -1)]
    ciz(d, SIRT, b.poligon(sirt))
    # yanal çizgi
    d.line(b.poligon([(x / 100, -kalinlik(x / 100) * 0.30) for x in range(22, 86, 2)]), fill=SIRT_KOYU, width=int(S * 0.004))
    # solungaç kapağı + levreğe özgü koyu leke
    d.line(b.poligon([(0.215 + 0.02 * math.sin(t / 10 * math.pi), -0.09 + t * 0.018) for t in range(11)]),
           fill=SIRT_KOYU, width=int(S * 0.006))
    lx, ly = b.p(0.225, -0.055)
    r = S * 0.012
    d.ellipse([lx - r, ly - r, lx + r, ly + r], fill=SIRT_KOYU)
    ciz(d, YUZGEC, gogus_yuzgeci(b))
    # ağız çizgisi ve göz
    d.line([b.p(0.0, 0.012), b.p(0.10, 0.03)], fill=SIRT_KOYU, width=int(S * 0.006))
    ex, ey = b.p(0.11, -0.035)
    r = S * 0.026
    d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=BEYAZ)
    r2 = S * 0.016
    d.ellipse([ex - r2, ey - r2, ex + r2, ey + r2], fill=(20, 26, 30))
    r3 = S * 0.005
    d.ellipse([ex - r2 * 0.3 - r3, ey - r2 * 0.4 - r3, ex - r2 * 0.3 + r3, ey - r2 * 0.4 + r3], fill=BEYAZ)
    # olta iğnesi (ağızdan çıkan)
    hx, hy = agiz
    w = int(S * 0.008)
    d.arc([hx - S * 0.03, hy - S * 0.005, hx + S * 0.018, hy + S * 0.05], 200, 520, fill=olta_renk, width=w)


def damlalar(img, merkez, renk, olcek=1.0):
    d = ImageDraw.Draw(img)
    cx, cy = merkez
    for dx, dy, r in [(-0.16, -0.05, 0.022), (-0.11, -0.11, 0.016), (0.14, -0.07, 0.02), (0.19, -0.02, 0.013),
                      (-0.21, 0.0, 0.012), (0.08, -0.13, 0.012)]:
        x, y, rr = cx + dx * S * olcek, cy + dy * S * olcek, r * S * olcek
        d.ellipse([x - rr, y - rr * 1.25, x + rr, y + rr * 1.25], fill=renk)


def dalga(img, y, renk, genlik=0.018, dalga_say=3.0):
    d = ImageDraw.Draw(img)
    pts = [(x, y + math.sin(x / S * dalga_say * 2 * math.pi) * genlik * S) for x in range(0, S + 16, 16)]
    d.polygon(pts + [(S, S), (0, S)], fill=renk)


def sicrama(img, cx, y, renk):
    """Suyun yüzeyinden yükselen köpük taçları (yuvarlak uçlu, dışa kıvrık)"""
    d = ImageDraw.Draw(img)
    for dx, h, egim in [(-0.11, 0.06, -0.5), (-0.055, 0.095, -0.25), (0.0, 0.07, 0.0), (0.055, 0.10, 0.25), (0.11, 0.055, 0.5)]:
        x0 = cx + dx * S
        tepe = (x0 + egim * h * S * 0.6, y - h * S)
        sol = bez((x0 - S * 0.016, y + S * 0.01), (x0 - S * 0.012, y - h * S * 0.5), (tepe[0] - S * 0.01, tepe[1] + S * 0.02), tepe, 20)
        sag = bez(tepe, (tepe[0] + S * 0.01, tepe[1] + S * 0.02), (x0 + S * 0.012, y - h * S * 0.5), (x0 + S * 0.016, y + S * 0.01), 20)
        d.polygon(sol + sag, fill=renk)
        r = S * 0.011
        d.ellipse([tepe[0] - r, tepe[1] - r * 1.6, tepe[0] + r, tepe[1] + r * 0.4], fill=renk)


def taslak(harf):
    zemin = Image.new('RGBA', (S, S), GECE + (255,))
    on = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    if harf == 'A':
        # Gece denizi: iki ton (mevcut simgeyle aynı aile), sıçrayan levrek, turuncu misina
        dalga(zemin, int(S * 0.70), GECE_ACIK + (255,))
        sicrama(on, S * 0.47, S * 0.71, BEYAZ + (255,))
        b = Balik((S * 0.47, S * 0.45), S * 0.68, math.radians(122), 0.22)
        levrek(on, b, olta_ucu=(S * 0.92, S * 0.0), olta_renk=TURUNCU + (255,))
        damlalar(on, (S * 0.5, S * 0.70), BEYAZ + (255,), 0.9)
    elif harf == 'B':
        # Gün batımı: turuncu güneş, levrek güneşin önünde kavis çiziyor
        d = ImageDraw.Draw(zemin)
        r = S * 0.30
        d.ellipse([S * 0.5 - r, S * 0.43 - r, S * 0.5 + r, S * 0.43 + r], fill=TURUNCU + (255,))
        dalga(zemin, int(S * 0.72), GECE_ACIK + (255,), genlik=0.014, dalga_say=2.5)
        sicrama(on, S * 0.50, S * 0.73, BEYAZ + (255,))
        b = Balik((S * 0.47, S * 0.46), S * 0.70, math.radians(140), 0.28)
        levrek(on, b, olta_ucu=(S * 1.0, S * 0.05), olta_renk=BEYAZ + (255,))
        damlalar(on, (S * 0.5, S * 0.72), BEYAZ + (255,), 0.8)
    else:
        # Sade rozet: beyaz daire içinde levrek, turuncu misina — küçük boyda en okunaklı
        d = ImageDraw.Draw(zemin)
        r = S * 0.40
        d.ellipse([S * 0.5 - r, S * 0.5 - r, S * 0.5 + r, S * 0.5 + r], fill=(236, 243, 244, 255))
        dalga(zemin, int(S * 0.74), GECE_ACIK + (255,), genlik=0.01, dalga_say=4)
        mask = Image.new('L', (S, S), 0)
        ImageDraw.Draw(mask).ellipse([S * 0.5 - r, S * 0.5 - r, S * 0.5 + r, S * 0.5 + r], fill=255)
        su = Image.new('RGBA', (S, S), GECE + (255,))
        zemin = Image.composite(zemin, su, mask)
        b = Balik((S * 0.49, S * 0.50), S * 0.60, math.radians(130), 0.24)
        levrek(on, b, olta_ucu=(S * 0.82, S * 0.10), olta_renk=TURUNCU + (255,))
        damlalar(on, (S * 0.5, S * 0.74), GECE_ACIK + (255,), 0.7)
    return zemin, on


def kaydet(zemin, on, hedef, harf):
    tam = Image.alpha_composite(zemin, on).convert('RGB')  # iOS: saydamlık yok
    tam.resize((1024, 1024), Image.LANCZOS).save(hedef / f'levrek_{harf}.png', optimize=True)
    # Android uyarlanabilir simge ön yüzü: balık güvenli alana (%66) sığdırılır, zemin ayrı (renk)
    k = on.resize((int(S * 0.70), int(S * 0.70)), Image.LANCZOS)
    fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    fg.alpha_composite(k, ((S - k.width) // 2, (S - k.height) // 2))
    fg.resize((1024, 1024), Image.LANCZOS).save(hedef / f'levrek_{harf}_fg.png', optimize=True)


if __name__ == '__main__':
    hedef = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/simge')
    hedef.mkdir(parents=True, exist_ok=True)
    for h in (sys.argv[2:] or ['A', 'B', 'C']):
        z, o = taslak(h)
        kaydet(z, o, hedef, h)
        print('taslak', h, hedef)
