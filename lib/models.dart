double _d(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String? _s(dynamic v) => v == null ? null : '$v';

class Category {
  final int id;
  final String name;
  final String? image;
  final bool hasChildren;

  const Category(
      {required this.id,
      required this.name,
      this.image,
      this.hasChildren = false});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _i(j['id']),
        name: _s(j['name']) ?? '',
        image: _s(j['image']),
        hasChildren: j['has_children'] == true,
      );
}

class ProductCard {
  final int id;
  final String name;
  final String? brand;
  final String? image;
  final double price;
  final double? special;
  final bool inStock;

  const ProductCard({
    required this.id,
    required this.name,
    this.brand,
    this.image,
    required this.price,
    this.special,
    this.inStock = true,
  });

  double get finalPrice => special ?? price;

  factory ProductCard.fromJson(Map<String, dynamic> j) => ProductCard(
        id: _i(j['id']),
        name: _s(j['name']) ?? '',
        brand: _s(j['brand']),
        image: _s(j['image']),
        price: _d(j['price']),
        special: j['special'] == null ? null : _d(j['special']),
        inStock: j['in_stock'] != false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'image': image,
        'price': price,
        'special': special,
        'in_stock': inStock,
      };
}

class OptionValue {
  final int id;
  final String name;
  final double price; // KDV dahil fark (+/-)
  final bool inStock;

  const OptionValue(
      {required this.id,
      required this.name,
      this.price = 0,
      this.inStock = true});

  factory OptionValue.fromJson(Map<String, dynamic> j) => OptionValue(
        id: _i(j['id']),
        name: _s(j['name']) ?? '',
        price: _d(j['price']),
        inStock: j['in_stock'] != false,
      );
}

class ProductOption {
  final int id;
  final String name;
  final String type;
  final bool required;
  final List<OptionValue> values;

  const ProductOption(
      {required this.id,
      required this.name,
      required this.type,
      required this.required,
      required this.values});

  factory ProductOption.fromJson(Map<String, dynamic> j) => ProductOption(
        id: _i(j['id']),
        name: _s(j['name']) ?? '',
        type: _s(j['type']) ?? 'select',
        required: j['required'] == true,
        values: ((j['values'] as List?) ?? [])
            .map((e) => OptionValue.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProductDetail {
  final int id;
  final String name;
  final String? brand;
  final String? model;
  final List<String> images;
  final double price;
  final double? special;
  final bool inStock;
  final int minimum;
  final String description;
  final List<ProductOption> options;

  const ProductDetail({
    required this.id,
    required this.name,
    this.brand,
    this.model,
    required this.images,
    required this.price,
    this.special,
    required this.inStock,
    this.minimum = 1,
    required this.description,
    required this.options,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
        id: _i(j['id']),
        name: _s(j['name']) ?? '',
        brand: _s(j['brand']),
        model: _s(j['model']),
        images: ((j['images'] as List?) ?? []).map((e) => '$e').toList(),
        price: _d(j['price']),
        special: j['special'] == null ? null : _d(j['special']),
        inStock: j['in_stock'] != false,
        minimum: _i(j['minimum']) < 1 ? 1 : _i(j['minimum']),
        description: _s(j['description']) ?? '',
        options: ((j['options'] as List?) ?? [])
            .map((e) => ProductOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  ProductCard toCard() => ProductCard(
        id: id,
        name: name,
        brand: brand,
        image: images.isNotEmpty ? images.first : null,
        price: price,
        special: special,
        inStock: inStock,
      );
}

class PageResult {
  final int page;
  final int pages;
  final int total;
  final List<ProductCard> items;

  const PageResult(
      {required this.page,
      required this.pages,
      required this.total,
      required this.items});

  bool get hasMore => page < pages;

  factory PageResult.fromJson(Map<String, dynamic> j) => PageResult(
        page: _i(j['page']),
        pages: _i(j['pages']),
        total: _i(j['total']),
        items: ((j['items'] as List?) ?? [])
            .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class HomeSection {
  final int id;
  final String title;
  final List<ProductCard> items;
  const HomeSection({required this.id, required this.title, required this.items});

  factory HomeSection.fromJson(Map<String, dynamic> j) => HomeSection(
        id: _i(j['id']),
        title: _s(j['title']) ?? '',
        items: ((j['items'] as List?) ?? [])
            .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class HomeData {
  final List<Category> categories;
  final List<HomeSection> sections;
  final List<ProductCard> newArrivals;

  const HomeData(
      {required this.categories, this.sections = const [], required this.newArrivals});

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        categories: ((j['categories'] as List?) ?? [])
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList(),
        sections: ((j['sections'] as List?) ?? [])
            .map((e) => HomeSection.fromJson(e as Map<String, dynamic>))
            .toList(),
        newArrivals: ((j['new'] as List?) ?? [])
            .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Aylık balık/yem önerisi satırı (yönetim panelinden)
class BaitRow {
  final String fish;
  final String live;
  final String lure;
  final String search;
  const BaitRow({required this.fish, required this.live, required this.lure, required this.search});

  factory BaitRow.fromJson(Map<String, dynamic> j) => BaitRow(
        fish: _s(j['balik']) ?? '',
        live: _s(j['canli']) ?? '',
        lure: _s(j['sahte']) ?? '',
        search: _s(j['ara']) ?? '',
      );
}

/// Yönetim panelinden gelen uygulama ayarları
class RemoteConfig {
  final String announcement;
  final double waveThreshold;
  final String shareText;
  final String phone;
  final int month;
  final List<BaitRow> bait;

  const RemoteConfig({
    this.announcement = '',
    this.waveThreshold = 1.0,
    this.shareText = 'Kıyı balıkçılığı için her şey KıyıdanAv\'da: kiyidanav.com',
    this.phone = '+90 549 301 30 01',
    this.month = 0,
    this.bait = const [],
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> j) => RemoteConfig(
        announcement: _s(j['duyuru']) ?? '',
        waveThreshold: _d(j['dalga_esik']) <= 0 ? 1.0 : _d(j['dalga_esik']),
        shareText: (_s(j['paylas_metin']) ?? '').isEmpty
            ? 'Kıyı balıkçılığı için her şey KıyıdanAv\'da: kiyidanav.com'
            : _s(j['paylas_metin'])!,
        phone: _s(j['telefon']) ?? '',
        month: _i(j['ay']),
        bait: ((j['yem'] as List?) ?? [])
            .map((e) => BaitRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Sepette seçili bir seçenek (ör. Boy: 2.40 m)
class SelectedOption {
  final int optionId;
  final int valueId;
  final String type;
  final String label; // "Boy: 2.40 m"

  const SelectedOption(
      {required this.optionId,
      required this.valueId,
      required this.type,
      required this.label});

  factory SelectedOption.fromJson(Map<String, dynamic> j) => SelectedOption(
        optionId: _i(j['o']),
        valueId: _i(j['v']),
        type: _s(j['t']) ?? 'select',
        label: _s(j['l']) ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'o': optionId, 'v': valueId, 't': type, 'l': label};
}

class CartItem {
  final ProductCard product;
  final List<SelectedOption> options;
  final double unitPrice;
  int qty;

  CartItem(
      {required this.product,
      required this.options,
      required this.unitPrice,
      required this.qty});

  String get key {
    final o = options.map((e) => '${e.optionId}:${e.valueId}').toList()
      ..sort();
    return '${product.id}|${o.join(',')}';
  }

  double get total => unitPrice * qty;

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        product: ProductCard.fromJson(j['p'] as Map<String, dynamic>),
        options: ((j['o'] as List?) ?? [])
            .map((e) => SelectedOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        unitPrice: _d(j['u']),
        qty: _i(j['q']) < 1 ? 1 : _i(j['q']),
      );

  Map<String, dynamic> toJson() => {
        'p': product.toJson(),
        'o': options.map((e) => e.toJson()).toList(),
        'u': unitPrice,
        'q': qty,
      };
}
