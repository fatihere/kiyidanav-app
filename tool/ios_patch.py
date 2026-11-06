"""iOS iskeletine KıyıdanAv ayarlarını uygular (flutter create --platforms ios sonrası, macOS'ta çalışır).

- Info.plist: uygulama adı, izin metinleri (konum, kamera, fotoğraf), bildirim arka plan modu, şifreleme beyanı
- En düşük iOS sürümü 15.0, yalnızca iPhone (iPad ekran görüntüsü gerekmesin)
- Bildirim sesi (kalama.caf), gizlilik bildirimi (PrivacyInfo.xcprivacy) ve varsa GoogleService-Info.plist uygulamaya eklenir
- Uygulama simgesi: logo, koyu ahşap zemin üzerinde (iOS simgesi saydamlık içeremez)

Gereken: pip install pillow
"""
import json
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

IOS = Path('ios')
RUNNER = IOS / 'Runner'
MIN_IOS = '15.0'


def fail(msg):
    sys.exit('HATA: ' + msg)


def patch_info():
    p = RUNNER / 'Info.plist'
    if not p.exists():
        fail('ios/Runner/Info.plist yok (önce flutter create --platforms ios .)')
    d = plistlib.loads(p.read_bytes())
    d['CFBundleDisplayName'] = 'KıyıdanAv'
    d['CFBundleName'] = 'KıyıdanAv'
    d['NSLocationWhenInUseUsageDescription'] = (
        'Sana en yakın merayı seçmek için yaklaşık konumun kullanılır. Konum telefonda kalır, sunucuya gönderilmez.')
    d['NSCameraUsageDescription'] = 'Av bildirimine fotoğraf eklemek için kamera kullanılır.'
    d['NSPhotoLibraryUsageDescription'] = 'Av bildirimine fotoğraf eklemek için fotoğraf arşivine erişilir.'
    modes = set(d.get('UIBackgroundModes', []))
    modes.update(['remote-notification'])
    d['UIBackgroundModes'] = sorted(modes)
    d['ITSAppUsesNonExemptEncryption'] = False          # yalnızca standart HTTPS
    d['FirebaseAppDelegateProxyEnabled'] = True
    # Instagram / WhatsApp / YouTube bağlantıları kendi uygulamalarında açılsın
    d['LSApplicationQueriesSchemes'] = sorted(set(d.get('LSApplicationQueriesSchemes', [])) |
                                              {'instagram', 'whatsapp', 'youtube', 'https'})
    # Yalnızca dikey (uygulama dikey tasarlandı)
    d['UISupportedInterfaceOrientations'] = ['UIInterfaceOrientationPortrait']
    p.write_bytes(plistlib.dumps(d))


def patch_podfile():
    p = IOS / 'Podfile'
    if not p.exists():
        return  # pod install sırasında flutter oluşturur; ikinci çalıştırmada düzeltilir
    s = p.read_text()
    s, n = re.subn(r"^#?\s*platform :ios, '[\d.]+'", f"platform :ios, '{MIN_IOS}'", s, flags=re.M)
    if n == 0:
        s = f"platform :ios, '{MIN_IOS}'\n" + s
    p.write_text(s)


def privacy_manifest():
    """Apple'ın 'gerekçe isteyen arayüzler' beyanı (UserDefaults = shared_preferences, dosya tarihi = önbellek)"""
    d = {
        'NSPrivacyTracking': False,
        'NSPrivacyTrackingDomains': [],
        'NSPrivacyCollectedDataTypes': [],
        'NSPrivacyAccessedAPITypes': [
            {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
             'NSPrivacyAccessedAPITypeReasons': ['CA92.1']},
            {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryFileTimestamp',
             'NSPrivacyAccessedAPITypeReasons': ['C617.1']},
        ],
    }
    out = RUNNER / 'PrivacyInfo.xcprivacy'
    out.write_bytes(plistlib.dumps(d))
    return out


def app_icon():
    logo_p = Path('assets/brand/logo.png')
    if not logo_p.exists():
        fail('assets/brand/logo.png yok')
    logo = Image.open(logo_p).convert('RGBA')
    bbox = logo.getbbox()
    if bbox:
        logo = logo.crop(bbox)
    w, h = logo.size
    side = max(w, h)
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(logo, ((side - w) // 2, (side - h) // 2))
    size, inner = 1024, int(1024 * 0.96)
    canvas = Image.new('RGBA', (size, size), (0x3A, 0x24, 0x16, 255))   # Android simgesiyle aynı ahşap zemin
    canvas.alpha_composite(sq.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
    d = RUNNER / 'Assets.xcassets' / 'AppIcon.appiconset'
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    canvas.convert('RGB').save(d / 'icon-1024.png')     # saydamlık yok
    (d / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': 'icon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
        'info': {'author': 'xcode', 'version': 1},
    }, indent=2))


def _id(seed):
    import hashlib
    return hashlib.md5(('kiyidanav-' + seed).encode()).hexdigest()[:24].upper()


def patch_project(extra_files):
    """project.pbxproj'u metin olarak düzenler (Flutter'ın Swift Package girdileriyle uyumlu)"""
    path = IOS / 'Runner.xcodeproj' / 'project.pbxproj'
    s = path.read_text()
    s, n = re.subn(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;', f'IPHONEOS_DEPLOYMENT_TARGET = {MIN_IOS};', s)
    if n == 0:
        fail('IPHONEOS_DEPLOYMENT_TARGET bulunamadı')
    s = re.sub(r'TARGETED_DEVICE_FAMILY = "?[\d,]+"?;', 'TARGETED_DEVICE_FAMILY = 1;', s)
    # Runner hedefinin ayar bloklarında aile tanımı yoksa ekle (yalnızca iPhone)
    s = re.sub(r'(PRODUCT_BUNDLE_IDENTIFIER = com\.kiyidanav\.kiyidanav;)(?![\s\S]{0,400}TARGETED_DEVICE_FAMILY)',
               r'\1\n\t\t\t\tTARGETED_DEVICE_FAMILY = 1;', s)
    # Runner hedefinin kendi Resources aşaması (RunnerTests'inki değil)
    m_tgt = re.search(r'/\* Runner \*/ = \{\s*isa = PBXNativeTarget;[\s\S]*?buildPhases = \(([\s\S]*?)\);', s)
    m_id = m_tgt and re.search(r'([0-9A-F]{24}) /\* Resources \*/', m_tgt.group(1))
    if not m_id:
        fail('Runner hedefinin Resources aşaması bulunamadı')
    res_pat = re.escape(m_id.group(1)) + r' /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;\s*buildActionMask = \d+;\s*files = \('
    m_group = re.search(r'(/\* Runner \*/ = \{\s*isa = PBXGroup;\s*children = \()', s)
    m_res = re.search(res_pat, s)
    if not m_group or not m_res:
        fail('Runner grubu veya Resources aşaması bulunamadı')
    for f in extra_files:
        name = f.name
        if f'path = {name};' in s or f'path = "{name}";' in s:
            continue
        ref, bld = _id('ref-' + name), _id('bld-' + name)
        ftype = {'.plist': 'text.plist.xml', '.xcprivacy': 'text.xml', '.caf': 'file'}.get(f.suffix, 'file')
        s = s.replace('/* Begin PBXFileReference section */',
                      '/* Begin PBXFileReference section */\n\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; path = "%s"; sourceTree = "<group>"; };'
                      % (ref, name, ftype, name), 1)
        s = s.replace('/* Begin PBXBuildFile section */',
                      '/* Begin PBXBuildFile section */\n\t\t%s /* %s in Resources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };'
                      % (bld, name, ref, name), 1)
        m_group = re.search(r'(/\* Runner \*/ = \{\s*isa = PBXGroup;\s*children = \()', s)
        s = s[:m_group.end()] + '\n\t\t\t\t%s /* %s */,' % (ref, name) + s[m_group.end():]
        m_res = re.search(res_pat, s)
        s = s[:m_res.end()] + '\n\t\t\t\t%s /* %s in Resources */,' % (bld, name) + s[m_res.end():]
    path.write_text(s)


TEAM_ID = 'X29M47RBN6'


def patch_signing():
    """Otomatik imzalama (App Store Connect API anahtarıyla) ve anlık bildirim yetkisi.
    Dağıtım (Apple Distribution) kimliği: mağaza profili kayıtlı test cihazı gerektirmez."""
    ent = RUNNER / 'Runner.entitlements'
    ent.write_bytes(plistlib.dumps({'aps-environment': 'production'}))
    path = IOS / 'Runner.xcodeproj' / 'project.pbxproj'
    s = path.read_text()
    ekle = ('\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
            '\n\t\t\t\tCODE_SIGN_STYLE = Automatic;'
            '\n\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";'
            '\n\t\t\t\tDEVELOPMENT_TEAM = %s;' % TEAM_ID)
    # Proje düzeyindeki "iPhone Developer" kimliği de dağıtıma çevrilir
    s = re.sub(r'"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "[^"]*";',
               '"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";', s)
    if 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' not in s:
        s, n = re.subn(r'(PRODUCT_BUNDLE_IDENTIFIER = com\.kiyidanav\.kiyidanav;)', lambda m: m.group(1) + ekle, s)
        if n == 0:
            fail('Runner imza ayarları için PRODUCT_BUNDLE_IDENTIFIER bulunamadı')

    # Aynı ayar bloğunda yinelenen imza kimliği satırı kalmasın
    def tekle(m):
        gorulen, satirlar = set(), []
        for satir in m.group(0).split('\n'):
            anahtar = satir.strip().split(' = ')[0] if 'CODE_SIGN_' in satir or 'DEVELOPMENT_TEAM' in satir else None
            if anahtar and anahtar in gorulen:
                continue
            if anahtar:
                gorulen.add(anahtar)
            satirlar.append(satir)
        return '\n'.join(satirlar)
    s = re.sub(r'buildSettings = \{[\s\S]*?\n\t\t\t\};', tekle, s)
    path.write_text(s)


def main():
    patch_info()
    patch_podfile()
    files = []
    snd = Path('tool/ios/kalama.caf')
    if not snd.exists():
        fail('tool/ios/kalama.caf yok')
    shutil.copy(snd, RUNNER / 'kalama.caf')
    files.append(RUNNER / 'kalama.caf')
    # 1.13.0: panelden seçilen süre (1–10 sn) için kısaltılmış sesler
    for n in range(1, 11):
        hedef = RUNNER / f'kalama_{n}.caf'
        if not hedef.exists():
            d = min(0.35, n * 0.3)
            r = subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(snd), '-t', str(n),
                                '-af', f'afade=t=out:st={round(n - d, 2)}:d={d}',
                                '-c:a', 'adpcm_ima_qt', '-ar', '22050', '-ac', '1', '-f', 'caf', str(hedef)])
            if r.returncode != 0 or not hedef.exists():
                fail(f'kalama_{n}.caf üretilemedi (ffmpeg)')
        files.append(hedef)
    files.append(privacy_manifest())
    gs = Path('GoogleService-Info.plist')
    if gs.exists():
        shutil.copy(gs, RUNNER / 'GoogleService-Info.plist')
        files.append(RUNNER / 'GoogleService-Info.plist')
    else:
        print('UYARI: GoogleService-Info.plist yok — iPhone bildirimleri Firebase iOS uygulaması eklenince çalışır')
    app_icon()
    patch_project(files)
    patch_signing()
    print('iOS ayarları uygulandı:', ', '.join(f.name for f in files))


if __name__ == '__main__':
    main()
