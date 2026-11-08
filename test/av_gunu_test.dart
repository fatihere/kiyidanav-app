import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/av_gunu.dart';
import 'package:kiyidanav/sea.dart';

void main() {
  final kartal = spots.firstWhere((s) => s.name == 'Kartal');
  final gun = DateTime(2026, 11, 4);
  final kayit = AvGunu.gunden(kartal, GunHava(gun, ruzgar: 14, hamle: 18, yon: 30, dalga: 0.5, su: 17));

  test('kaydedilen gün: etkin rüzgâr, ay, json', () {
    expect(kayit.ruzgar, 14);
    expect(kayit.spotAd, 'Kartal');
    final j = AvGunu.fromJson(kayit.toJson());
    expect(j.yon, 30);
    expect(j.dalga, 0.5);
    expect(j.tarih, gun);
  });

  test('benzer koşullar', () {
    // aynı ay evresine yakın bir gün (aynı gün) — rüzgâr, yön, dalga yakın
    expect(kayit.benzer(GunHava(gun, ruzgar: 17, yon: 50, dalga: 0.6)), isTrue);
    // rüzgâr çok farklı
    expect(kayit.benzer(GunHava(gun, ruzgar: 30, yon: 30, dalga: 0.5)), isFalse);
    // yön ters (Poyraz → Lodos)
    expect(kayit.benzer(GunHava(gun, ruzgar: 14, yon: 220, dalga: 0.5)), isFalse);
    // dalga çok farklı
    expect(kayit.benzer(GunHava(gun, ruzgar: 14, yon: 30, dalga: 1.2)), isFalse);
    // 359° ile 10° arası 11° fark sayılır
    final kuzey = AvGunu.gunden(kartal, GunHava(gun, ruzgar: 10, yon: 359));
    expect(kuzey.benzer(GunHava(gun, ruzgar: 10, yon: 10)), isTrue);
    // ay evresi çok farklı (yaklaşık yarım ay sonrası)
    expect(kayit.benzer(GunHava(gun.add(const Duration(days: 14)), ruzgar: 14, yon: 30, dalga: 0.5)), isFalse);
  });

  test('yön adı ve skor', () {
    expect(GunHava(DateTime(2026), yon: 225).yonAdi, 'Lodos');
    expect(GunHava(gun, ruzgar: 8, dalga: 0.4).skor, greaterThan(0));
  });
}
