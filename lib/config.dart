/// Uygulama genel ayarları. Gizli anahtar YOKTUR ve olmamalıdır:
/// APK açılıp incelenebilir, bu yüzden tüm sırlar sunucuda tutulur.
class AppConfig {
  // Site, kiyidanav.com adresini www.kiyidanav.com'a yönlendirir. Yönlendirme POST isteklerinde
  // (av bildirimi) takip edilmediği için doğrudan www adresi kullanılır.
  static const siteUrl = 'https://www.kiyidanav.com/';
  static const siteHost = 'kiyidanav.com';
  static const apiUrl = 'https://www.kiyidanav.com/mobil-api.php';
  static const whatsapp = '905493013001';

  /// Sunucu API'si henüz yüklenmemişse örnek ürünlerle çalışır.
  /// Google Play'e göndermeden önce false yapın.
  static const demoFallback = false;

  // Kargo kuralı (bilgilendirme amaçlı; kesin tutarı site hesaplar)
  static const freeShippingLimit = 2500.0;
  static const shippingFee = 250.0;
}
