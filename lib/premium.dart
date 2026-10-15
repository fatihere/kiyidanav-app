import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catches.dart';
import 'config.dart';
import 'theme.dart';

/// Panel → Site ayarları → Ücretsiz / Premium (mobil-api.php config → premium).
///
/// Sistem kapalıyken (varsayılan) her şey ücretsizdir. Açıkken "premium" işaretli paneller bulanık görünür ve
/// "Yükselt" ile Google Play aboneliği alınır. Panelden ücretsiz premium verilen üyeler (VIP) de premium sayılır.
class PremiumAyar {
  final bool acik;
  final Map<String, String> paneller; // panel → ucretsiz | premium | kapali
  final List<bool> gunler; // 7 günlük tahmin: true = ücretsiz
  final String bilgi; // ölçüm açıklamaları: ucretsiz | premium | kapali
  final List<String> urunler; // Play abonelik kimlikleri
  final String baslik;
  final String aciklama;

  const PremiumAyar({
    this.acik = false,
    this.paneller = const {},
    this.gunler = const [true, true, true, true, true, true, true],
    this.bilgi = 'ucretsiz',
    this.urunler = const [],
    this.baslik = 'KıyıdanAv Premium',
    this.aciklama = '',
  });

  factory PremiumAyar.fromJson(Map<String, dynamic> j) {
    final p = <String, String>{};
    if (j['paneller'] is Map) {
      (j['paneller'] as Map).forEach((k, v) {
        final s = '$v';
        if (s == 'ucretsiz' || s == 'premium' || s == 'kapali') p['$k'] = s;
      });
    }
    final g = (j['gunler'] is List) ? (j['gunler'] as List).map((e) => e == true).toList() : <bool>[];
    while (g.length < 7) {
      g.add(true);
    }
    final b = '${j['bilgi'] ?? 'ucretsiz'}';
    return PremiumAyar(
      acik: j['acik'] == true,
      paneller: p,
      gunler: g.take(7).toList(),
      bilgi: (b == 'premium' || b == 'kapali') ? b : 'ucretsiz',
      urunler: ((j['urunler'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList(),
      baslik: '${j['baslik'] ?? ''}'.trim().isEmpty ? 'KıyıdanAv Premium' : '${j['baslik']}',
      aciklama: '${j['aciklama'] ?? ''}',
    );
  }
}

enum PanelDurum { acik, kilitli, gizli }

class Premium {
  static PremiumAyar ayar = const PremiumAyar();

  /// Kullanıcı premium mu (Play aboneliği ya da panelden verilen hak)
  static final ValueNotifier<bool> aktif = ValueNotifier<bool>(false);
  static bool _play = false;
  static bool _vip = false;

  static const _onbellek = 'premium_play_v1';

  static void yukle(Map<String, dynamic> config) {
    final p = config['premium'];
    ayar = p is Map ? PremiumAyar.fromJson(Map<String, dynamic>.from(p)) : const PremiumAyar();
  }

  /// Panelin bu kullanıcı için durumu
  static PanelDurum panel(String id) {
    final d = ayar.paneller[id] ?? 'ucretsiz';
    if (d == 'kapali') return ayar.acik ? PanelDurum.gizli : PanelDurum.acik;
    if (!ayar.acik || d == 'ucretsiz' || aktif.value) return PanelDurum.acik;
    return PanelDurum.kilitli;
  }

  /// 7 günlük tahminde [i]. gün açık mı (0 = bugün)
  static bool gunAcik(int i) => !ayar.acik || aktif.value || i < 0 || i >= ayar.gunler.length || ayar.gunler[i];

  static PanelDurum bilgi() {
    if (!ayar.acik) return PanelDurum.acik;
    if (ayar.bilgi == 'kapali') return PanelDurum.gizli;
    if (ayar.bilgi == 'ucretsiz' || aktif.value) return PanelDurum.acik;
    return PanelDurum.kilitli;
  }

  static void _guncelle() => aktif.value = _play || _vip;

  // ---------------------------------------------------------------- Başlangıç
  static StreamSubscription<List<PurchaseDetails>>? _abone;
  static bool _basladi = false;

  /// Uygulama açılışında: önbellekteki satın alma, panel hakkı (VIP) ve Play'deki etkin abonelikler
  static Future<void> baslat() async {
    if (_basladi) return;
    _basladi = true;
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getInt(_onbellek) ?? 0;
      // Son doğrulamadan 10 gün geçmediyse (çevrimdışı açılışta) abonelik geçerli sayılır
      _play = t > 0 && DateTime.now().millisecondsSinceEpoch - t < const Duration(days: 10).inMilliseconds;
    } catch (_) {}
    _guncelle();
    unawaited(vipYenile());
    if (!ayar.acik || ayar.urunler.isEmpty) return;
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return;
      _abone ??= iap.purchaseStream.listen(_satinAlimlar, onError: (_) {});
      var bulundu = false;
      final once = _play;
      _geriYuklendi = () => bulundu = true;
      await iap.restorePurchases();
      // Play etkin abonelik bildirmezse (iptal/süre doldu) yerel kayıt silinir
      Timer(const Duration(seconds: 12), () async {
        _geriYuklendi = null;
        if (!bulundu && once) {
          _play = false;
          _guncelle();
          try {
            (await SharedPreferences.getInstance()).remove(_onbellek);
          } catch (_) {}
        }
      });
    } catch (_) {}
  }

  static void Function()? _geriYuklendi;

  /// Panelden verilen ücretsiz premium hakkı (giriş yapan üye)
  static Future<void> vipYenile() async {
    try {
      final t = await CatchService.token();
      if (t == null) {
        _vip = false;
        _guncelle();
        return;
      }
      final r = await http
          .get(Uri.parse('${AppConfig.siteUrl}araclar.php?api=premium&app=1'), headers: {'X-Av-Anahtar': t})
          .timeout(const Duration(seconds: 10));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['ok'] == true) {
        _vip = j['premium'] == true;
        _guncelle();
      }
    } catch (_) {}
  }

  static Future<void> _satinAlimlar(List<PurchaseDetails> l) async {
    for (final p in l) {
      if (!ayar.urunler.contains(p.productID)) {
        if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
        continue;
      }
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        _play = true;
        _geriYuklendi?.call();
        _guncelle();
        try {
          (await SharedPreferences.getInstance()).setInt(_onbellek, DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}
        if (p.status == PurchaseStatus.purchased) unawaited(_sunucuyaBildir(p));
        _bitir(null);
      } else if (p.status == PurchaseStatus.error) {
        _bitir(p.error?.message ?? 'Satın alma tamamlanamadı.');
      } else if (p.status == PurchaseStatus.canceled) {
        _bitir('Satın alma iptal edildi.');
      }
      if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
    }
  }

  static Future<void> _sunucuyaBildir(PurchaseDetails p) async {
    try {
      final t = await CatchService.token();
      if (t == null) return;
      await http
          .post(Uri.parse('${AppConfig.siteUrl}araclar.php?api=premium&app=1'),
              headers: {'X-Av-Anahtar': t, 'Content-Type': 'application/json'},
              body: jsonEncode({
                'urun': p.productID,
                'siparis': p.purchaseID ?? '',
                'jeton': p.verificationData.serverVerificationData,
                'durum': p.status.name,
              }))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Completer<String?>? _sonuc;
  static void _bitir(String? m) {
    final c = _sonuc;
    if (c != null && !c.isCompleted) c.complete(m);
  }

  /// Mağazadaki abonelik seçenekleri (Play Console'da tanımlı değilse boş)
  static Future<List<ProductDetails>> urunler() async {
    if (ayar.urunler.isEmpty) return const [];
    final iap = InAppPurchase.instance;
    if (!await iap.isAvailable()) return const [];
    _abone ??= iap.purchaseStream.listen(_satinAlimlar, onError: (_) {});
    final r = await iap.queryProductDetails(ayar.urunler.toSet());
    final l = r.productDetails.toList()..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return l;
  }

  /// Satın alma; hata/iptal metni ya da başarıda null
  static Future<String?> satinAl(ProductDetails d) async {
    _sonuc = Completer<String?>();
    try {
      final ok = await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: d));
      if (!ok) return 'Satın alma başlatılamadı.';
    } catch (e) {
      return 'Satın alma başlatılamadı.';
    }
    return _sonuc!.future.timeout(const Duration(minutes: 5), onTimeout: () => null);
  }

  static Future<void> geriYukle() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }
}

/// Premium kilidi: panel açıksa içeriği, kilitliyse bulanık önizleme + "Yükselt", gizliyse hiçbir şey göstermez
class PremiumKilit extends StatelessWidget {
  final String panel;
  final String ad;
  final Widget child;
  final double yukseklik;
  const PremiumKilit({super.key, required this.panel, required this.ad, required this.child, this.yukseklik = 170});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Premium.aktif,
      builder: (context, _, __) {
        return switch (Premium.panel(panel)) {
          PanelDurum.acik => child,
          PanelDurum.gizli => const SizedBox.shrink(),
          PanelDurum.kilitli => KilitOrtusu(ad: ad, yukseklik: yukseklik, child: child),
        };
      },
    );
  }
}

/// Bulanık içerik + kilit + Yükselt düğmesi
class KilitOrtusu extends StatelessWidget {
  final String ad;
  final Widget child;
  final double yukseklik;
  final bool kucuk;
  const KilitOrtusu({super.key, required this.ad, required this.child, this.yukseklik = 170, this.kucuk = false});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: yukseklik),
        child: ClipRect(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: child),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x8CFFFFFF),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: kucuk
              ? IconButton(
                  onPressed: () => premiumSayfasi(context),
                  icon: const Icon(Icons.lock_outline, color: Tide.zeytinKoyu),
                  tooltip: 'Yükselt',
                )
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline, color: Tide.zeytinKoyu),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('$ad premium\'da',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.kaya)),
                  ),
                  const SizedBox(height: 8),
                  YukseltDugmesi(),
                ]),
        ),
      ),
    ]);
  }
}

class YukseltDugmesi extends StatelessWidget {
  final String yazi;
  YukseltDugmesi({super.key, this.yazi = 'Yükselt'});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
          backgroundColor: Tide.turuncu, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: () => premiumSayfasi(context),
      icon: const Icon(Icons.workspace_premium_outlined, size: 18),
      label: Text(yazi, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// Premium satın alma sayfası (alttan açılır)
Future<void> premiumSayfasi(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PremiumSayfa(),
    );

class _PremiumSayfa extends StatefulWidget {
  const _PremiumSayfa();

  @override
  State<_PremiumSayfa> createState() => _PremiumSayfaState();
}

class _PremiumSayfaState extends State<_PremiumSayfa> {
  late final Future<List<ProductDetails>> _urunler = Premium.urunler().catchError((_) => <ProductDetails>[]);
  bool _mesgul = false;
  String? _mesaj;

  Future<void> _al(ProductDetails d) async {
    setState(() {
      _mesgul = true;
      _mesaj = null;
    });
    final h = await Premium.satinAl(d);
    if (!mounted) return;
    setState(() {
      _mesgul = false;
      _mesaj = h;
    });
    if (h == null && Premium.aktif.value) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final a = Premium.ayar;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.workspace_premium, color: Tide.turuncu, size: 30),
            const SizedBox(width: 8),
            Expanded(child: Text(a.baslik, style: const TextStyle(fontFamily: Tide.font, fontSize: 20))),
          ]),
          if (a.aciklama.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(a.aciklama, style: const TextStyle(color: Color(0xFF5F5E50))),
            ),
          const SizedBox(height: 14),
          ValueListenableBuilder<bool>(
            valueListenable: Premium.aktif,
            builder: (context, aktif, _) => aktif
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFEAF6EF), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Premium üyesisin — tüm bölümler açık. Teşekkürler! 🎣',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F6B40))),
                  )
                : FutureBuilder<List<ProductDetails>>(
                    future: _urunler,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                            padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Tide.turuncu)));
                      }
                      final l = snap.data ?? const <ProductDetails>[];
                      if (l.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFFFF6E5), borderRadius: BorderRadius.circular(12)),
                          child: const Text(
                              'Abonelik henüz hazır değil. Çok yakında buradan Premium\'a geçebileceksin.',
                              style: TextStyle(color: Color(0xFF6B4E00))),
                        );
                      }
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final d in l)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                side: const BorderSide(color: Tide.turuncu, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _mesgul ? null : () => _al(d),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(_temizBaslik(d.title),
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.kaya)),
                                    if (d.description.isNotEmpty)
                                      Text(d.description, style: const TextStyle(fontSize: 12, color: Color(0xFF77766A))),
                                  ]),
                                ),
                                Text(d.price,
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.turuncu, fontSize: 16)),
                              ]),
                            ),
                          ),
                        const Text('Abonelik Google Play üzerinden yenilenir; istediğin zaman Play Store → Abonelikler\'den iptal edebilirsin.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF77766A))),
                      ]);
                    },
                  ),
          ),
          if (_mesaj != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_mesaj!, style: const TextStyle(color: Tide.mercan, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _mesgul
                ? null
                : () async {
                    await Premium.geriYukle();
                    await Premium.vipYenile();
                  },
            child: const Text('Satın almalarımı geri yükle'),
          ),
        ]),
      ),
    );
  }

  /// Play başlığındaki "(KıyıdanAv)" ekini kaldırır
  static String _temizBaslik(String t) => t.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '');
}
