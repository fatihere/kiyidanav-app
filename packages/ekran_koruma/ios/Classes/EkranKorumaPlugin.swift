import Flutter
import UIKit

/// Ekran kaydı / yansıtma algılama: kayıt başlayınca Flutter'a "kayit" bildirilir, içerik gizlenir.
/// (Apple ekran görüntüsünü engellemeye izin vermez.)
public class EkranKorumaPlugin: NSObject, FlutterPlugin {
  private var kanal: FlutterMethodChannel?
  private var izliyor = false

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
}
