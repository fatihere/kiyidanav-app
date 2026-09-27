import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../widgets.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final items = appState.favorites.values.toList().reversed.toList();
          if (items.isEmpty) {
            return MessageView(
              icon: Icons.favorite_border,
              title: 'Henüz favorin yok',
              body: 'Ürünlerdeki kalbe dokunarak sonra bakmak istediklerini burada topla.',
              actionLabel: 'Ürünlere göz at',
              onAction: () => Shell.goTo(context, 0),
            );
          }
          return CustomScrollView(slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            ProductGrid(items),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]);
        },
      ),
    );
  }
}
