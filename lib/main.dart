import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'api.dart';
import 'app_state.dart';
import 'catches.dart';
import 'ekran_koruma.dart';
import 'ekran_turu.dart';
import 'fishkrok.dart';
import 'hata.dart';
import 'kurallar.dart';
import 'profil.dart';
import 'locate.dart';
import 'meralarim.dart';
import 'mera_widget.dart';
import 'notices.dart';
import 'overlays.dart';
import 'premium.dart';
import 'push.dart';
import 'sea_card.dart';
import 'screens/account_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';
import 'updates.dart';
import 'yonetici.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Hata.kur(); // açılamayan ekranlar boş kalmasın, nedeni yazsın
  await appState.load();
  await loadSelectedSpot();
  await Meralarim.yukle(); // 1.13.2: haritadan öğrenilen meralar
  await Locate.loadPref();
  await CampaignTicker.load();
  await AppUpdate.loadVersion();
  await CatchService.token(); // üye numarası (test modülleri için)
  // Yönetim panelindeki ayarlar (en fazla birkaç saniye beklenir)
  await Api.loadConfig().timeout(const Duration(seconds: 4), onTimeout: () => Api.config);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  Notices.enabled = !ekranTuru; // mağaza ekran görüntüsü derlemesinde izin pencereleri açılmasın
  Notices.kalamaSure = Api.config.kalamaSure; // panel → kalama sesi süresi
  await Kurallar.yukle();
  await Yonetici.yukle(); // 1.13.0: uygulamada yönetici girişi (ekran görüntüsü izni dahil)
  unawaited(EkranKoruma.uygula()); // panel → Ekran görüntüsü engeli
  runApp(const KiyidanAvApp());
  Premium.baslat(); // Play aboneliği + panelden verilen premium
  memberNotifier.addListener(Premium.vipYenile); // giriş / çıkışta panel hakkı yeniden sorulur
  if (!ekranTuru) Notices.start().whenComplete(Push.start);
  if (ekranTuru) unawaited(EkranTuru.baslat());
  // Android ana ekran kartı: panel ayarı ve üyeliğe göre hazırlanır
  MeraWidget.syncAccess(enabled: Api.config.features.homeWidget, member: appState.isMember);
  if (!ekranTuru && Api.config.features.location) Locate.silentUpdate(); // izin daha önce verildiyse en yakın merayı seç
}

class KiyidanAvApp extends StatefulWidget {
  const KiyidanAvApp({super.key});

  @override
  State<KiyidanAvApp> createState() => _KiyidanAvAppState();
}

class _KiyidanAvAppState extends State<KiyidanAvApp> with WidgetsBindingObserver {
  Timer? _poll;

  /// Uygulama ekrandayken bildirimler dakikada bir kontrol edilir
  void _startPoll() {
    _poll?.cancel();
    if (!Notices.enabled) return;
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => Notices.refresh());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPoll();
    memberNotifier.addListener(_onMember);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Notices.enabled) _listenHomeWidget();
      await Notices.refresh();
      if (Notices.enabled) {
        await Future<void>.delayed(const Duration(seconds: 2));
        await AppUpdate.checkOnLaunch(); // Google Play'de yeni sürüm varsa "Güncelle"
        final ctx = navKey.currentContext;
        if (ctx != null && ctx.mounted) await ProfilFormu.ilkAcilis(ctx); // 1.12.0: yaş, kamış türü, il, ilçe
        await WelcomePopup.maybeShow(); // ilk girişte bir kez: Mera Bilgisi tanıtımı
        await Notices.askOnLaunch();
      }
    });
  }

  /// Üye girişi yapılınca (ilk kez) Mera Bilgisi tanıtımı
  void _onMember() {
    if (!Notices.enabled) return;
    MeraWidget.syncAccess(enabled: Api.config.features.homeWidget, member: memberNotifier.value);
    if (memberNotifier.value) {
      Future<void>.delayed(const Duration(milliseconds: 800), WelcomePopup.maybeShow);
      Future<void>.delayed(const Duration(seconds: 3), ProfilFormu.uyeyeBagla); // ilk açılış formu üyeliğe bağlansın
    }
  }

  /// Ana ekran kartına dokunulunca Mera Bilgisi sekmesi açılır
  void _listenHomeWidget() {
    void go(Uri? u) {
      if (!MeraWidget.isWidgetLink(u)) return;
      navKey.currentState?.popUntil((r) => r.isFirst);
      shellTab.value = Shell.tabReport;
    }

    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(go, onError: (_) {});
      HomeWidget.widgetClicked.listen(go, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    memberNotifier.removeListener(_onMember);
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Notices.refresh();
      _startPoll();
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel(); // arka planda WorkManager devralır
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KıyıdanAv',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      scaffoldMessengerKey: Hata.mesajAnahtari,
      theme: Tide.theme(background: Api.config.ui.zemin, accent: Api.config.ui.vurgu),
      // iPhone'da ekran kaydı sürerken içerik gizlenir
      builder: (context, child) => EkranKorumaKatmani(child: child ?? const SizedBox.shrink()),
      home: const Shell(),
    );
  }
}

/// Seçili alt sekme (0: Keşfet, 1: Mera Bilgisi, 2: Fishkrok — panelde kapalıysa Ara, 3: Sepet, 4: Hesabım)
final shellTab = ValueNotifier<int>(0);

/// Ana sayfayı en üste kaydırıp yenilemek için sinyal
final homeReset = ValueNotifier<int>(0);

/// Açık tüm sayfaları kapatıp uygulamanın ana ekranına döner
void goHome() {
  navKey.currentState?.popUntil((r) => r.isFirst);
  shellTab.value = Shell.tabHome;
  homeReset.value++;
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  static const tabHome = 0, tabReport = 1, tabFishkrok = 2, tabCart = 3, tabAccount = 4;
  /// Fishkrok kapalıysa 2. sekme eskisi gibi "Ara"
  static const tabSearch = 2;

  /// Ürün araması: Fishkrok açıksa ayrı sayfa olarak, değilse "Ara" sekmesi
  static void openSearch(BuildContext context) {
    if (Api.config.features.fishkrok) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(appBar: AppBar(title: const Text('Ürün ara')), body: const SearchScreen())));
    } else {
      shellTab.value = tabSearch;
    }
  }

  /// Başka ekranlardan sekme değiştirmek için (kapanan ekranlardan da güvenli)
  static void goTo(BuildContext context, int index) => shellTab.value = index;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, index, _) => _scaffold(index),
    );
  }

  Widget _scaffold(int index) {
    return Scaffold(
      // Yeni kampanya: üstte kayan bant (X ile kapatılır)
      body: TickerHost(
        child: IndexedStack(
          index: index,
          children: [
            const HomeScreen(),
            const ReportScreen(),
            Api.config.features.fishkrok ? const FishkrokEkrani() : const SearchScreen(),
            const CartScreen(),
            const AccountScreen(),
          ],
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: appState,
        // Telefonun büyük yazı ayarında etiketler iki satıra bölünüp simgeden kaymasın
        builder: (context, __) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(maxScaleFactor: 1.0)),
          child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 11.5,
                letterSpacing: -0.1,
                fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
          ),
          child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            if (i == Shell.tabHome) {
              goHome(); // her basışta ana ekran (en üst) gelir
            } else {
              shellTab.value = i;
            }
          },
          backgroundColor: Colors.white,
          indicatorColor: Tide.somon,
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Keşfet'),
            const NavigationDestination(
                icon: Icon(Icons.set_meal_outlined), selectedIcon: Icon(Icons.set_meal), label: 'Mera Bilgisi'),
            if (Api.config.features.fishkrok)
              const NavigationDestination(icon: _FishkrokSekmeIkonu(secili: false), selectedIcon: _FishkrokSekmeIkonu(secili: true), label: 'Paylaş')
            else
              const NavigationDestination(icon: Icon(Icons.search), label: 'Ara'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: appState.cartCount > 0,
                    label: Text('${appState.cartCount}'),
                    backgroundColor: Tide.turuncu,
                    child: const Icon(Icons.shopping_bag_outlined)),
                selectedIcon: const Icon(Icons.shopping_bag),
                label: 'Sepet'),
            const NavigationDestination(
                icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Hesabım'),
          ],
        ),
        ),
        ),
      ),
    );
  }
}


class _FishkrokSekmeIkonu extends StatelessWidget {
  final bool secili;
  const _FishkrokSekmeIkonu({required this.secili});
  @override
  Widget build(BuildContext context) => FishkrokLogo(boy: 24, kanca: secili ? fishkrokKoyu : const Color(0xFF5B5F55));
}
