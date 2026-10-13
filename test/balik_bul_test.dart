import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/balik_bul.dart';
import 'package:kiyidanav/moduller.dart';
import 'package:kiyidanav/olcum_yorum.dart';

void main() {
  group('Bugün balık kaç metrede', () {
    test('düşen basınç + kapalı hava → yakın', () {
      final h = mesafeHukmu([
        MesafeGirdi(Yorum.basinc(1012, -2.5), 4),
        MesafeGirdi(Yorum.bulut(100), 3),
      ])!;
      expect(h.bant.min, lessThan(20));
      expect(h.bant.max, lessThanOrEqualTo(50));
      expect(h.etiket, anyOf('Yakın', 'Yakın–orta'));
      expect(h.neden, isNotEmpty);
    });
    test('yüksek sabit basınç + açık hava → uzak', () {
      final h = mesafeHukmu([
        MesafeGirdi(Yorum.basinc(1024, 0.2), 4),
        MesafeGirdi(Yorum.bulut(5), 3),
      ])!;
      expect(h.bant.orta, greaterThan(80));
    });
    test('ağırlık sıfırsa hesaba girmez, girdi yoksa null', () {
      expect(mesafeHukmu([MesafeGirdi(Yorum.basinc(1012, -2.5), 0)]), isNull);
      expect(mesafeHukmu(const []), isNull);
    });
  });

  group('Kıyı yönü', () {
    test('açı farkı', () {
      expect(aciFarki(350, 10), 20);
      expect(aciFarki(90, 270), 180);
    });
    test('güneybatıya bakan kıyıya lodos vurur, poyraz kıyıdan eser', () {
      expect(kiyiyaVuruyor(200, 225), isTrue);
      expect(kiyidanEsiyor(200, 30), isTrue);
      expect(kiyiyaVuruyor(200, 30), isFalse);
    });
    test('Türkçe yön ekleri', () {
      expect(yonE('kuzey'), 'kuzeye');
      expect(yonE('güneybatı'), 'güneybatıya');
      expect(yonDen('doğu'), 'doğudan');
      expect(yonDe('güney'), 'güneyde');
      expect(yonAdi(225), 'güneybatı');
    });
  });

  group('Kesit ve şev', () {
    test('ani derinleşme bulunur', () {
      final s = sevBul(const [MapEntry(20, 2), MapEntry(50, 4), MapEntry(100, 12), MapEntry(200, 16)], esik: 5)!;
      expect(s.bas, 50);
      expect(s.son, 100);
    });
    test('yavaş eğimde şev yok', () {
      expect(sevBul(const [MapEntry(20, 1), MapEntry(100, 4), MapEntry(200, 7)], esik: 5), isNull);
    });
  });

  group('Berraklık', () {
    test('sınıflar', () {
      expect(berraklikSinifi(0.05), 0);
      expect(berraklikSinifi(0.15), 1);
      expect(berraklikSinifi(0.4), 2);
      expect(gorusMetre(0.17), closeTo(10, 0.1));
    });
  });

  group('Solunar', () {
    test('Kartal 13 Ekim 2026: ay tepede ~14:53, doğuş ~10:13 (±25 dk)', () {
      final p = solunar(DateTime(2026, 10, 13), 40.885, 29.185);
      final tepe = p.firstWhere((e) => e.ad == 'Ay tepede').orta;
      final dogus = p.firstWhere((e) => e.ad == 'Ay doğuşu').orta;
      // Test makinesi UTC'de çalışabilir: yerel saat yerine gün içindeki dakikayı UTC+3'e göre karşılaştır
      int dk(DateTime t) {
        final u = t.toUtc().add(const Duration(hours: 3));
        return u.hour * 60 + u.minute;
      }
      final tz = DateTime(2026, 10, 13).timeZoneOffset.inHours;
      if (tz == 3) {
        expect((dk(tepe) - (14 * 60 + 53)).abs(), lessThan(25));
        expect((dk(dogus) - (10 * 60 + 13)).abs(), lessThan(25));
      }
      expect(p.where((e) => e.buyuk).length, inInclusiveRange(1, 2));
      expect(p.length, inInclusiveRange(2, 4));
    });
    test('gece aydınlığı', () {
      expect(geceAydinligiAd(geceAydinligi(1, 0)), 'Çok aydınlık');
      expect(geceAydinligiAd(geceAydinligi(0.05, 100)), 'Karanlık');
    });
  });

  group('Deniz seviyesi', () {
    test('en büyük yükselme', () {
      final t0 = DateTime(2026, 10, 13, 10);
      final z = List.generate(8, (i) => t0.add(Duration(hours: i)));
      final d = seviyeDegisim(z, [0.0, 0.05, 0.12, 0.20, 0.18, 0.1, 0.02, 0.0], t0)!;
      expect(d.cm, closeTo(20, 0.01));
      expect(d.bas, t0);
    });
  });

  group('Modül ayarları', () {
    test('test özeti sunucuyla aynı', () {
      expect(Moduller.testOzet(1), '13fb3690f724');
    });
    test('yayında / test / üye / yer kuralları', () {
      Moduller.yukle({
        'moduller': {
          'mesafe_karti': {'test': false, 'app': true, 'web': true, 'uye': true, 'ayar': {'agirlikBasinc': 4}},
          'goc': {'test': true, 'app': true, 'uye': false},
          'video': {'test': false, 'app': false, 'web': true},
        },
        'test_uyeler': [Moduller.testOzet(7)],
        'modul_tema': {'vurgu': '#123456', 'kose': 10, 'sablon': 'acik'},
      });
      expect(Moduller.app('mesafe_karti', uye: true)?.n('agirlikBasinc', 0), 4);
      expect(Moduller.app('mesafe_karti', uye: false), isNull);
      expect(Moduller.app('video', uye: true), isNull);
      Moduller.uyeNo = 0;
      expect(Moduller.app('goc', uye: true), isNull);
      Moduller.uyeNo = 7;
      expect(Moduller.app('goc', uye: false), isNotNull);
      expect(Moduller.tema.vurgu, 0xFF123456);
      expect(Moduller.tema.sablon, 'acik');
      expect(Moduller.app('olcum_yorum', uye: true), isNull); // panelde tanımlı değil ama ayar geldi
      Moduller.uyeNo = 0;
    });
    test('ayar hiç gelmezse mevcut modüller açık', () {
      Moduller.yukle({});
      expect(Moduller.app('olcum_yorum', uye: true), isNotNull);
      expect(Moduller.app('mesafe_karti', uye: true), isNull);
    });
    test('panelde düzenlenen basınç kuralları', () {
      Yorum.panelden([
        {'kosul': 'Eğilim ≤ −2', 'durum': 'Hızlı düşüş', 'mesafe': 'Yakın 2–40 m', 'ton': 'iyi'},
        {'kosul': 'Eğilim ≥ +0,8', 'durum': 'Yükseliyor', 'mesafe': 'Uzak 80–200 m', 'ton': 'zayıf'},
        {'kosul': 'Basınç > 1018', 'durum': 'Yüksek', 'mesafe': 'Uzak 80–200 m', 'ton': 'zayıf'},
        {'kosul': 'anlamsız', 'durum': 'x'},
      ], 'Benim notum');
      expect(Yorum.ozelBasinc.length, 3);
      final a = Yorum.basinc(1010, -2.4);
      expect(a.durum, 'Hızlı düşüş');
      expect(a.mesafe, Mesafe.yakin);
      expect(a.aktif, 0);
      expect(a.not, 'Benim notum');
      expect(Yorum.basinc(1010, 1.0).ton, Ton.zayif);
      expect(Yorum.basinc(1020, 0).durum, 'Yüksek');
      expect(Yorum.basinc(1010, 0).aktif, -1);
      Yorum.panelden(const [], '');
      expect(Yorum.basinc(1010, -2.4).aktif, 0);
    });
    test('av anahtarından üye numarası', () {
      // {"c":42,"n":"Ali K.","e":9999999999}
      const govde = 'eyJjIjo0MiwibiI6IkFsaSBLLiIsImUiOjk5OTk5OTk5OTl9';
      expect(Moduller.anahtardanUye('$govde.imza'), 42);
      expect(Moduller.anahtardanUye('bozuk'), 0);
    });
  });
}
