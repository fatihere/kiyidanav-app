import 'api.dart';
import 'models.dart';

/// Sunucu API'si yüklenmeden uygulamayı denemek için örnek katalog.
/// Fiyatlar örnektir, gerçek değildir.
class DemoData {
  static const _cats = [
    Category(id: 1, name: 'Olta Kamışları', hasChildren: true),
    Category(id: 2, name: 'Olta Makineleri'),
    Category(id: 3, name: 'Suni Yemler', hasChildren: true),
    Category(id: 4, name: 'Misinalar'),
    Category(id: 5, name: 'Kamp Malzemeleri'),
    Category(id: 6, name: 'Aksesuar'),
  ];

  static const _sub = {
    1: [
      Category(id: 11, name: 'LRF Kamışları'),
      Category(id: 12, name: 'Spin Kamışları'),
      Category(id: 13, name: 'Surf Kamışları'),
    ],
    3: [
      Category(id: 31, name: 'Jigler'),
      Category(id: 32, name: 'Silikon Yemler'),
    ],
  };

  // (id, ad, marka, fiyat, indirimli, stok, kategoriler)
  static final _products = <(ProductCard, List<int>)>[
    (const ProductCard(id: 101, name: 'LRF Kamışı 2.10 m 1-7 g', brand: 'Oslo', price: 1850, special: 1590), [1, 11]),
    (const ProductCard(id: 102, name: 'Spin Kamışı 2.70 m 10-40 g', brand: 'Albastar', price: 2450), [1, 12]),
    (const ProductCard(id: 103, name: 'Surf Kamışı 4.20 m 100-250 g', brand: 'Captain', price: 3890), [1, 13]),
    (const ProductCard(id: 201, name: 'Spin Makine 2500 Boy', brand: 'Shimano', price: 4250, special: 3990), [2]),
    (const ProductCard(id: 202, name: 'Surf Makine 5000 Boy', brand: 'Okuma', price: 3150, inStock: false), [2]),
    (const ProductCard(id: 301, name: 'Shore Jig 30 g Sardalya', brand: 'Savage Gear', price: 240), [3, 31]),
    (const ProductCard(id: 302, name: 'Baby Jig 7 g Pembe', brand: 'Remixon', price: 95), [3, 31]),
    (const ProductCard(id: 303, name: 'Silikon Yem 5 cm 8\'li', brand: 'Fujin', price: 130), [3, 32]),
    (const ProductCard(id: 401, name: 'PE Örgü Misina 150 m 0.10 mm', brand: 'Ryuji', price: 590), [4]),
    (const ProductCard(id: 501, name: 'Katlanır Balıkçı Taburesi', brand: 'Wily', price: 690), [5]),
    (const ProductCard(id: 601, name: 'Kafa Lambası Şarjlı', brand: 'Captain', price: 420), [6]),
  ];

  static HomeData home() => HomeData(
        categories: _cats,
        newArrivals: _products.map((e) => e.$1).where((p) => p.inStock).toList(),
      );

  static List<Category> categories(int parent) =>
      parent == 0 ? _cats : (_sub[parent] ?? const []);

  static PageResult _page(List<ProductCard> items, String sort) {
    final l = [...items];
    switch (sort) {
      case 'price_asc':
        l.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
        break;
      case 'price_desc':
        l.sort((a, b) => b.finalPrice.compareTo(a.finalPrice));
        break;
      case 'name':
        l.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    l.sort((a, b) => (b.inStock ? 1 : 0) - (a.inStock ? 1 : 0));
    return PageResult(page: 1, pages: 1, total: l.length, items: l);
  }

  static PageResult products({required int category, String sort = 'new'}) =>
      _page(
          _products
              .where((e) => e.$2.contains(category))
              .map((e) => e.$1)
              .toList(),
          sort);

  static PageResult search(String q) {
    final words = q.toLowerCase().split(RegExp(r'\s+'));
    return _page(
        _products.map((e) => e.$1).where((p) {
          final hay = '${p.name} ${p.brand ?? ''}'.toLowerCase();
          return words.every(hay.contains);
        }).toList(),
        'new');
  }

  static ProductDetail product(int id) {
    final match = _products.where((e) => e.$1.id == id);
    if (match.isEmpty) throw const ApiException('Ürün bulunamadı.');
    final p = match.first.$1;
    final isRod = match.first.$2.contains(1);
    return ProductDetail(
      id: p.id,
      name: p.name,
      brand: p.brand,
      model: 'DEMO-${p.id}',
      images: const [],
      price: p.price,
      special: p.special,
      inStock: p.inStock,
      description:
          'Bu bir örnek üründür. Sunucuya mobil-api.php yüklendiğinde burada '
          'kiyidanav.com\'daki gerçek ürün açıklaması görünecek.\n\n'
          '• Gerçek fiyatlar ve stok durumu\n• Ürün fotoğrafları\n• Renk ve numara seçenekleri',
      options: isRod
          ? const [
              ProductOption(
                  id: 1,
                  name: 'Boy',
                  type: 'select',
                  required: true,
                  values: [
                    OptionValue(id: 11, name: '2.10 m'),
                    OptionValue(id: 12, name: '2.40 m', price: 150),
                    OptionValue(id: 13, name: '2.70 m', price: 300, inStock: false),
                  ]),
            ]
          : const [],
    );
  }
}
