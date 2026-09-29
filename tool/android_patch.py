"""Flutter'ın oluşturduğu Android iskeletini KıyıdanAv için ayarlar.

- Google Play: targetSdk/compileSdk 36 (31 Ağustos 2026 zorunluluğu)
- Bildirim paketi için Java kütüphane desugaring
- Kalıcı anahtarla imza (KS_FILE / KS_PASS ortam değişkenleri varsa)
- Manifest: izinler, uygulama adı, yedekleme kapalı, şifresiz trafik yasak
Beklenen bir yer bulunamazsa hata verir (sessizce yanlış derleme olmasın).
"""
import re
import sys
from pathlib import Path

APP = Path('android/app')


def fail(msg):
    print('HATA:', msg)
    sys.exit(1)


def patch_gradle():
    kts = APP / 'build.gradle.kts'
    if not kts.exists():
        fail('android/app/build.gradle.kts bulunamadı')
    s = kts.read_text()

    s, n = re.subn(r'compileSdk\s*=\s*[^\n]+', 'compileSdk = 36', s, count=1)
    if n != 1:
        fail('compileSdk satırı yok')
    s, n = re.subn(r'targetSdk\s*=\s*[^\n]+', 'targetSdk = 36', s, count=1)
    if n != 1:
        fail('targetSdk satırı yok')

    if 'isCoreLibraryDesugaringEnabled' not in s:
        s, n = re.subn(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', s, count=1)
        if n != 1:
            fail('compileOptions bloğu yok')

    # Kalıcı imza: anahtar varsa release, yoksa debug
    if 'signingConfigs {' not in s:
        block = '''    signingConfigs {
        create("release") {
            val ks = System.getenv("KS_FILE")
            if (ks != null && ks.isNotEmpty()) {
                storeFile = file(ks)
                storePassword = System.getenv("KS_PASS")
                keyAlias = "kiyidanav"
                keyPassword = System.getenv("KS_PASS")
            }
        }
    }

    buildTypes {'''
        s, n = re.subn(r'    buildTypes\s*\{', block, s, count=1)
        if n != 1:
            fail('buildTypes bloğu yok')
    n = 1 if 'signingConfigs.getByName("release") else' in s else 0
    if n == 0:
      s, n = re.subn(
        r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = if ((System.getenv("KS_FILE") ?: "").isNotEmpty()) '
        'signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
        s, count=1)
    if n != 1:
        fail('release signingConfig satırı yok')

    # Firebase: google-services eklentisi (uygulama modülü)
    if 'com.google.gms.google-services' not in s:
        s, n = re.subn(r'(id\("com\.android\.application"\)[^\n]*\n)', r'\1    id("com.google.gms.google-services")\n', s, count=1)
        if n != 1:
            fail('app plugins bloğunda com.android.application yok')

    if 'desugar_jdk_libs' not in s:
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(s)
    print(s)


def patch_settings():
    st = Path('android/settings.gradle.kts')
    if not st.exists():
        fail('android/settings.gradle.kts bulunamadı')
    s = st.read_text()
    if 'com.google.gms.google-services' not in s:
        s, n = re.subn(r'(id\("dev\.flutter\.flutter-plugin-loader"\)[^\n]*\n)',
                       r'\1    id("com.google.gms.google-services") version "4.4.2" apply false\n', s, count=1)
        if n != 1:
            fail('settings.gradle.kts plugins bloğu bulunamadı')
    st.write_text(s)
    print(s)
    if not (APP / 'google-services.json').exists():
        fail('android/app/google-services.json yok (Firebase ayarı)')


def patch_manifest():
    m = APP / 'src/main/AndroidManifest.xml'
    s = m.read_text()
    perms = ['android.permission.INTERNET', 'android.permission.POST_NOTIFICATIONS']
    for p in perms:
        if p not in s:
            s = s.replace('<application', f'<uses-permission android:name="{p}"/>\n    <application', 1)
    # Kullanılmayan ön plan hizmeti izinleri (WorkManager ekliyor) kaldırılsın:
    # Play Console bunlar varsa ayrıca beyan formu ister.
    if 'xmlns:tools' not in s:
        s = s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
    for p in ['android.permission.FOREGROUND_SERVICE', 'android.permission.FOREGROUND_SERVICE_SHORT_SERVICE']:
        tag = f'<uses-permission android:name="{p}" tools:node="remove"/>'
        if tag not in s:
            s = s.replace('<application', tag + '\n    <application', 1)
    # Firebase bildirimleri: KıyıdanAv simgesi, rengi ve kanalı
    if 'default_notification_icon' not in s:
        meta = ('        <meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_stat_notify"/>\n'
                '        <meta-data android:name="com.google.firebase.messaging.default_notification_color" android:resource="@color/bildirim_rengi"/>\n'
                '        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="kiyidanav_duyuru"/>\n'
                '    </application>')
        s = s.replace('    </application>', meta, 1) if '    </application>' in s else s.replace('</application>', meta, 1)
    s, n = re.subn(r'android:label="[^"]*"',
                   'android:label="KıyıdanAv" android:allowBackup="false" android:usesCleartextTraffic="false"',
                   s, count=1)
    if n != 1:
        fail('manifest android:label yok')
    m.write_text(s)
    print(s)


if __name__ == '__main__':
    patch_gradle()
    patch_settings()
    patch_manifest()
