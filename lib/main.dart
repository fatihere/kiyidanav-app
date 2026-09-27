import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/cart_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.load();
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

/// Seçili alt sekme (0: Keşfet, 1: Ara, 2: Favoriler, 3: Sepet)
final shellTab = ValueNotifier<int>(0);

class Shell extends StatelessWidget {
  const Shell({super.key});

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
          SearchScreen(),
          FavoritesScreen(),
          CartScreen(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: appState,
        builder: (_, __) => NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => shellTab.value = i,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD6E6E2),
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Keşfet'),
            const NavigationDestination(
                icon: Icon(Icons.search), label: 'Ara'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: appState.favorites.isNotEmpty,
                    label: Text('${appState.favorites.length}'),
                    backgroundColor: Tide.derinAcik,
                    child: const Icon(Icons.favorite_border)),
                selectedIcon: const Icon(Icons.favorite),
                label: 'Favoriler'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: appState.cartCount > 0,
                    label: Text('${appState.cartCount}'),
                    backgroundColor: Tide.samandira,
                    child: const Icon(Icons.shopping_bag_outlined)),
                selectedIcon: const Icon(Icons.shopping_bag),
                label: 'Sepet'),
          ],
        ),
      ),
    );
  }
}
