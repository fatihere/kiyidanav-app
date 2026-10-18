"""App Store Connect API ile elle (Manual) imza hazırlığı — kayıtlı test cihazı gerektirmez.

1) Apple Distribution sertifikası: runner'da yeni anahtar + CSR üretilir, API ile sertifika alınır
   (sınır dolduysa en eski dağıtım sertifikası iptal edilip yeniden denenir; yayınlanmış uygulamalar etkilenmez).
2) App Store profili (IOS_APP_STORE) bu sertifikayla oluşturulur ve Xcode'a kurulur.
3) Sertifika + anahtar geçici bir anahtar zincirine (keychain) alınır.
4) Runner hedefi Manual imzaya ve bu profile çevrilir; ExportOptions.plist yazılır.

Ortam: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (gizli değişkenler), GITHUB_RUN_NUMBER.
Kullanım: python tool/asc_imza.py  (gereken paketler: pyjwt cryptography requests)
"""
import base64
import os
import plistlib
import re
import subprocess
import sys
import time
from pathlib import Path

import jwt
import requests

BUNDLE = 'com.kiyidanav.kiyidanav'
TEAM = 'X29M47RBN6'
API = 'https://api.appstoreconnect.apple.com/v1'
PROFIL_ON_EK = 'KiyidanAv CI AppStore'
IS = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'asc'
IS.mkdir(parents=True, exist_ok=True)


def fail(msg):
    print(f'::error::{msg}')
    sys.exit(1)


def token():
    return jwt.encode(
        {'iss': os.environ['ASC_ISSUER_ID'], 'iat': int(time.time()), 'exp': int(time.time()) + 15 * 60,
         'aud': 'appstoreconnect-v1'},
        os.environ['ASC_KEY_P8'], algorithm='ES256',
        headers={'kid': os.environ['ASC_KEY_ID'], 'typ': 'JWT'})


def api(method, yol, **kw):
    r = requests.request(method, API + yol, headers={'Authorization': f'Bearer {token()}'}, timeout=60, **kw)
    if r.status_code >= 400:
        return None, r
    return (r.json() if r.content else {}), r


def sh(*a, **kw):
    print('$', ' '.join(str(x) for x in a))
    subprocess.run([str(x) for x in a], check=True, **kw)


def bundle_id():
    j, r = api('GET', '/bundleIds', params={'filter[identifier]': BUNDLE, 'limit': 50})
    if j is None:
        fail(f'Bundle ID okunamadı: {r.status_code} {r.text[:400]}')
    for d in j['data']:
        if d['attributes']['identifier'] == BUNDLE:
            return d['id']
    fail(f'{BUNDLE} App ID bulunamadı (Apple Developer > Identifiers)')


def push_yetkisi(bid):
    j, r = api('POST', '/bundleIdCapabilities', json={'data': {
        'type': 'bundleIdCapabilities', 'attributes': {'capabilityType': 'PUSH_NOTIFICATIONS'},
        'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': bid}}}}})
    if j is None and r.status_code != 409:
        print(f'::warning::Push yetkisi eklenemedi ({r.status_code}); zaten açık olabilir: {r.text[:200]}')


def sertifika():
    anahtar, csr = IS / 'dagitim.key', IS / 'dagitim.csr'
    sh('openssl', 'req', '-new', '-newkey', 'rsa:2048', '-nodes', '-keyout', anahtar, '-out', csr,
       '-subj', f'/emailAddress=info@kiyidanav.com/CN=KiyidanAv CI/C=TR')
    csr_metin = csr.read_text()
    govde = {'data': {'type': 'certificates', 'attributes': {'certificateType': 'DISTRIBUTION', 'csrContent': csr_metin}}}
    for deneme in range(3):
        j, r = api('POST', '/certificates', json=govde)
        if j is not None:
            break
        print(f'Sertifika oluşturulamadı ({r.status_code}): {r.text[:300]}')
        if r.status_code != 409 or deneme == 2:
            fail('Apple Distribution sertifikası oluşturulamadı')
        # Sınır dolu: en eski dağıtım sertifikasını iptal et
        liste, _ = api('GET', '/certificates', params={'filter[certificateType]': 'DISTRIBUTION,IOS_DISTRIBUTION', 'limit': 200})
        sertler = sorted((liste or {}).get('data', []), key=lambda d: d['attributes'].get('expirationDate', ''))
        if not sertler:
            fail('Sertifika sınırı dolu ama iptal edilecek sertifika bulunamadı')
        eski = sertler[0]
        print(f"::notice::Sertifika sınırı dolu; en eski dağıtım sertifikası iptal ediliyor: {eski['attributes'].get('name')} {eski['attributes'].get('expirationDate')}")
        api('DELETE', f"/certificates/{eski['id']}")
    cer = IS / 'dagitim.cer'
    cer.write_bytes(base64.b64decode(j['data']['attributes']['certificateContent']))
    return j['data']['id'], anahtar, cer


def profil(bid, sert_id):
    no = os.environ.get('GITHUB_RUN_NUMBER', '0')
    ad = f'{PROFIL_ON_EK} {no}'
    # Önceki CI profillerini temizle
    liste, _ = api('GET', '/profiles', params={'filter[profileType]': 'IOS_APP_STORE', 'limit': 200})
    for p in (liste or {}).get('data', []):
        if p['attributes']['name'].startswith(PROFIL_ON_EK):
            api('DELETE', f"/profiles/{p['id']}")
    j, r = api('POST', '/profiles', json={'data': {
        'type': 'profiles', 'attributes': {'name': ad, 'profileType': 'IOS_APP_STORE'},
        'relationships': {
            'bundleId': {'data': {'type': 'bundleIds', 'id': bid}},
            'certificates': {'data': [{'type': 'certificates', 'id': sert_id}]}}}})
    if j is None:
        fail(f'App Store profili oluşturulamadı: {r.status_code} {r.text[:400]}')
    icerik = base64.b64decode(j['data']['attributes']['profileContent'])
    uuid = j['data']['attributes']['uuid']
    for klasor in [Path.home() / 'Library/MobileDevice/Provisioning Profiles',
                   Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles']:
        klasor.mkdir(parents=True, exist_ok=True)
        (klasor / f'{uuid}.mobileprovision').write_bytes(icerik)
    print(f'Profil kuruldu: {ad} ({uuid})')
    return ad


def anahtar_zinciri(anahtar, cer):
    pem, p12 = IS / 'dagitim.pem', IS / 'dagitim.p12'
    sh('openssl', 'x509', '-inform', 'DER', '-in', cer, '-out', pem)
    sifre = 'ci' + os.urandom(6).hex()
    try:
        sh('openssl', 'pkcs12', '-export', '-legacy', '-inkey', anahtar, '-in', pem, '-out', p12, '-passout', f'pass:{sifre}')
    except subprocess.CalledProcessError:
        sh('openssl', 'pkcs12', '-export', '-inkey', anahtar, '-in', pem, '-out', p12, '-passout', f'pass:{sifre}')
    kc = IS / 'imza.keychain-db'
    kc_sifre = 'kc' + os.urandom(6).hex()
    sh('security', 'create-keychain', '-p', kc_sifre, kc)
    sh('security', 'set-keychain-settings', '-lut', '21600', kc)
    sh('security', 'unlock-keychain', '-p', kc_sifre, kc)
    sh('security', 'import', p12, '-k', kc, '-P', sifre, '-T', '/usr/bin/codesign', '-T', '/usr/bin/security')
    sh('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', kc_sifre, kc,
       stdout=subprocess.DEVNULL)
    mevcut = subprocess.run(['security', 'list-keychains', '-d', 'user'], capture_output=True, text=True).stdout
    zincirler = [z.strip().strip('"') for z in mevcut.split() if z.strip()]
    sh('security', 'list-keychains', '-d', 'user', '-s', kc, *zincirler)
    sh('security', 'find-identity', '-v', '-p', 'codesigning', kc)


def projeyi_elle_imzaya_cevir(profil_adi):
    yol = Path('ios/Runner.xcodeproj/project.pbxproj')
    s = yol.read_text()

    def blok(m):
        b = m.group(0)
        if f'PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE};' not in b:
            return b
        b = re.sub(r'\n\t+CODE_SIGN_STYLE = [^;]*;', '', b)
        b = re.sub(r'\n\t+PROVISIONING_PROFILE_SPECIFIER = [^;]*;', '', b)
        b = re.sub(r'\n\t+"?CODE_SIGN_IDENTITY(\[sdk=iphoneos\*\])?"? = [^;]*;', '', b)
        b = b.replace(f'PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE};',
                      f'PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE};'
                      '\n\t\t\t\tCODE_SIGN_STYLE = Manual;'
                      '\n\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";'
                      f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profil_adi}";'
                      f'\n\t\t\t\tDEVELOPMENT_TEAM = {TEAM};', 1)
        return b

    s2, n = re.subn(r'buildSettings = \{[\s\S]*?\n\t\t\t\};', blok, s)
    if s2.count('CODE_SIGN_STYLE = Manual;') == 0:
        fail('Runner imza ayarı Manual yapılamadı')
    yol.write_text(s2)
    print(f"Runner: Manual imza, profil '{profil_adi}' ({s2.count('CODE_SIGN_STYLE = Manual;')} yapılandırma)")


def export_ayarlari(profil_adi):
    Path('build').mkdir(exist_ok=True)
    Path('build/ExportOptions.plist').write_bytes(plistlib.dumps({
        'method': 'app-store-connect',
        'destination': 'upload',
        'teamID': TEAM,
        'signingStyle': 'manual',
        'signingCertificate': 'Apple Distribution',
        'provisioningProfiles': {BUNDLE: profil_adi},
        'uploadSymbols': True,
        'manageAppVersionAndBuildNumber': False,
    }))


def main():
    for k in ('ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_P8'):
        if not os.environ.get(k):
            fail(f'{k} tanımlı değil')
    bid = bundle_id()
    push_yetkisi(bid)
    sert_id, anahtar, cer = sertifika()
    ad = profil(bid, sert_id)
    anahtar_zinciri(anahtar, cer)
    projeyi_elle_imzaya_cevir(ad)
    export_ayarlari(ad)


if __name__ == '__main__':
    main()
