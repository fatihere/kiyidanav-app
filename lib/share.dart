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

  /// Ekrandaki bir alanı (RepaintBoundary) görsel olarak paylaşır — Instagram hikâyesi için ideal
  static Future<void> widgetImage(GlobalKey key, {required String text, String name = 'kiyidanav-av-raporu.png'}) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    await Share.shareXFiles(
      [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: name)],
      text: text,
    );
  }
}
