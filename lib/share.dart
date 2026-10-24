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
        subject: p.name, sharePositionOrigin: origin());
  }

  static Future<void> app() async {
    await Share.share('${Api.config.shareText}\nhttps://kiyidanav.com', subject: 'KıyıdanAv', sharePositionOrigin: origin());
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
      sharePositionOrigin: origin(ctx),
    ).then((_) {}, onError: (_) {}));
  }

  /// Paylaşım menüsünün çıkacağı yer. iPhone'da (iOS 17+/26) bu alan verilmezse menü hiç açılmıyordu
  /// ("Raporu paylaş" tepkisizdi); düğmenin kendi konumu, yoksa ekranın ortası kullanılır.
  static Rect origin([BuildContext? context]) {
    final box = context?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    final w = v.physicalSize.width / v.devicePixelRatio, h = v.physicalSize.height / v.devicePixelRatio;
    return Rect.fromCenter(center: Offset(w / 2, h / 2), width: 2, height: 2);
  }

  /// Hazır PNG baytlarını paylaşır. Görsel paylaşılamazsa yazıyla tekrar dener; paylaşım menüsünün kapanması beklenmez.
  static void imageBytes(Uint8List bytes,
      {required String text, String name = 'kiyidanav-av-raporu.png', BuildContext? context}) {
    final o = origin(context);
    unawaited(Share.shareXFiles([XFile.fromData(bytes, mimeType: 'image/png', name: name)],
            text: text, sharePositionOrigin: o)
        .then((_) {}, onError: (Object e) {
      debugPrint('görsel paylaşılamadı: $e');
      return Share.share(text, sharePositionOrigin: o).then((_) {}, onError: (_) {});
    }));
  }

  /// Yalnızca yazı
  static void textOnly(String text, {BuildContext? context}) =>
      unawaited(Share.share(text, sharePositionOrigin: origin(context)).then((_) {}, onError: (_) {}));

  /// Görseli [targetWidth] piksel genişliğe getiren ölçek (1,5 – 3 arası)
  static double imagePixelRatio(double logicalWidth, double targetWidth) =>
      logicalWidth <= 0 ? 2.5 : (targetWidth / logicalWidth).clamp(1.5, 3.0).toDouble();
}
