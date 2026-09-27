/// Uygulama genel ayarları. Gizli anahtar YOKTUR ve olmamalıdır:
/// APK açılıp incelenebilir, bu yüzden tüm sırlar sunucuda tutulur.
class AppConfig {
  static const siteUrl = 'https://kiyidanav.com/';
  static const siteHost = 'kiyidanav.com';
  static const apiUrl = 'https://kiyidanav.com/mobil-api.php';

  /// Sunucu API'si henüz yüklenmemişse örnek ürünlerle çalışır.
  /// Google Play'e göndermeden önce false yapın.
  static const demoFallback = true;

  // Kargo kuralı (bilgilendirme amaçlı; kesin tutarı site hesaplar)
  static const freeShippingLimit = 2500.0;
  static const shippingFee = 250.0;
}
