import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'app_state.dart';
import 'sea_card.dart';
import 'screens/account_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.load();
  await loadSelectedSpot();
  // Yönetim panelindeki ayarlar (en fazla birkaç saniye beklenir)
  await Api.loadConfig().timeout(const Duration(seconds: 4), onTimeout: () => Api.config);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const KiyidanAvApp());
}

class KiyidanAvApp extends StatelessWidget {
  const KiyidanAvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KıyıdanAv',
      debugShowCheckedModeBanner: false,
      theme: Tide.theme(),
      home: const Shell(),
    );
  }
}

/// Seçili alt sekme (0: Keşfet, 1: Av Raporu, 2: Ara, 3: Sepet, 4: Hesabım)
final shellTab = ValueNotifier<int>(0);

class Shell extends StatelessWidget {
  const Shell({super.key});

  static const tabHome = 0, tabReport = 1, tabSearch = 2, tabCart = 3, tabAccount = 4;

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
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          ReportScreen(),
          SearchScreen(),
          CartScreen(),
          AccountScreen(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: appState,
        builder: (_, __) => NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => shellTab.value = i,
          backgroundColor: Colors.white,
          indicatorColor: Tide.somon,
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Keşfet'),
            const NavigationDestination(
                icon: Icon(Icons.set_meal_outlined), selectedIcon: Icon(Icons.set_meal), label: 'Av Raporu'),
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
    );
  }
}
