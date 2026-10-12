import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'api.dart';
import 'format.dart';
import 'models.dart';

/// Instagram, WhatsApp, Facebook vb. — telefonun paylaşım menüsüyle
class Sharer {
  static Future<void> product(ProductCard p, {String? url}) async {
    final link = url ?? 'https://kiyidanav.com/index.php?route=product/product&product_id=${p.id}';
    await Share.share('${p.name}\n${tl(p.finalPrice)}\n$link\n\nKıyıdanAv uygulamasından paylaşıldı 🎣',
        subject: p.name);
  }

  static Future<void> app() async {
    await Share.share('${Api.config.shareText}\nhttps://kiyidanav.com', subject: 'KıyıdanAv');
  }

  /// Ekrandaki bir alanı (RepaintBoundary) görsel olarak paylaşır — Instagram hikâyesi için ideal.
  /// Görsel genişliği [targetWidth] (900) pikselle sınırlanır: önceki 3x çekime göre ~%35 daha az piksel; daha
  /// büyüğü yalnızca kodlamayı yavaşlatır). Paylaşım menüsü açılınca hemen döner: menünün
  /// kapanması BEKLENMEZ (önceden düğme, kullanıcı uygulamaya dönene kadar "Hazırlanıyor…" kalıyordu).
  static Future<void> widgetImage(GlobalKey key,
      {required String text, String name = 'kiyidanav-av-raporu.png', double targetWidth = 900}) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final ratio = imagePixelRatio(boundary.size.width, targetWidth);
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    unawaited(Share.shareXFiles(
      [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: name)],
      text: text,
    ).then((_) {}, onError: (_) {}));
  }

  /// Hazır PNG baytlarını paylaşır; paylaşım menüsünün kapanması beklenmez
  static void imageBytes(Uint8List bytes, {required String text, String name = 'kiyidanav-av-raporu.png'}) {
    unawaited(Share.shareXFiles([XFile.fromData(bytes, mimeType: 'image/png', name: name)], text: text)
        .then((_) {}, onError: (_) {}));
  }

  /// Yalnızca yazı
  static void textOnly(String text) => unawaited(Share.share(text).then((_) {}, onError: (_) {}));

  /// Görseli [targetWidth] piksel genişliğe getiren ölçek (1,5 – 3 arası)
  static double imagePixelRatio(double logicalWidth, double targetWidth) =>
      logicalWidth <= 0 ? 2.5 : (targetWidth / logicalWidth).clamp(1.5, 3.0).toDouble();
}
