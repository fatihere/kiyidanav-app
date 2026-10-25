import Flutter
import UIKit

/// iPhone ekran koruması (1.13.1)
///  - Ekran görüntüsü: uygulama penceresi "güvenli metin alanı" katmanının içine alınır. iOS, parola alanlarında
///    olduğu gibi bu katmanı ekran görüntüsüne ve ekran kaydına koymaz; görüntü siyah / boş çıkar.
///  - Ekran kaydı / yansıtma: kayıt başlayınca Flutter'a "kayit" bildirilir, içerik ayrıca perdeyle gizlenir.
/// Koruma kapatılınca (panel veya yönetici girişi) güvenli alan devre dışı bırakılır; pencere düzeni değişmez.
public class EkranKorumaPlugin: NSObject, FlutterPlugin {
  private var kanal: FlutterMethodChannel?
  private var izliyor = false
  private var guvenliAlan: UITextField?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let k = FlutterMethodChannel(name: "kiyidanav/ekran_koruma", binaryMessenger: registrar.messenger())
    let o = EkranKorumaPlugin()
    o.kanal = k
    registrar.addMethodCallDelegate(o, channel: k)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "koru":
      let acik = (call.arguments as? Bool) ?? false
      if acik && !izliyor {
        NotificationCenter.default.addObserver(self, selector: #selector(degisti),
                                               name: UIScreen.capturedDidChangeNotification, object: nil)
        izliyor = true
      } else if !acik && izliyor {
        NotificationCenter.default.removeObserver(self, name: UIScreen.capturedDidChangeNotification, object: nil)
        izliyor = false
      }
      kalkan(acik)
      result(true)
    case "kayitVar":
      result(UIScreen.main.isCaptured)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func degisti() {
    kanal?.invokeMethod("kayit", arguments: UIScreen.main.isCaptured)
  }

  private func anaPencere() -> UIWindow? {
    if #available(iOS 15.0, *) {
      let sahneler = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      if let w = sahneler.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) { return w }
      if let w = sahneler.first?.windows.first { return w }
    }
    if let w = UIApplication.shared.delegate?.window, let pencere = w { return pencere }
    return UIApplication.shared.windows.first
  }

  /// Ekran görüntüsü engeli: pencere katmanı bir kez güvenli alanın içine taşınır, sonra yalnızca aç / kapa yapılır
  private func kalkan(_ acik: Bool, deneme: Int = 0) {
    DispatchQueue.main.async {
      if self.guvenliAlan == nil {
        if !acik { return }
        guard let pencere = self.anaPencere() else {
          // Pencere henüz hazır değil (açılışın ilk anı): kısa süre sonra tekrar dene
          if deneme < 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.kalkan(acik, deneme: deneme + 1) }
          }
          return
        }
        // 1.13.1 (23): güvenli alan pencereyle aynı boyutta ve (0,0) noktasında olmalı; aksi halde
        // görüntü ekranın ortasından başlayıp kayık çizilir (22. derlemedeki hata)
        let alan = UITextField(frame: pencere.bounds)
        alan.isUserInteractionEnabled = false
        alan.isSecureTextEntry = true
        alan.backgroundColor = .clear
        alan.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pencere.addSubview(alan)
        pencere.sendSubviewToBack(alan)
        pencere.layer.superlayer?.addSublayer(alan.layer)
        let kap: CALayer?
        if #available(iOS 17.0, *) {
          kap = alan.layer.sublayers?.last
        } else {
          kap = alan.layer.sublayers?.first
        }
        guard let kapsayici = kap else { return }
        kapsayici.frame = CGRect(origin: .zero, size: pencere.bounds.size)
        kapsayici.addSublayer(pencere.layer)
        pencere.layer.frame = CGRect(origin: .zero, size: pencere.bounds.size)
        self.guvenliAlan = alan
      }
      self.guvenliAlan?.isSecureTextEntry = acik
    }
  }
}
