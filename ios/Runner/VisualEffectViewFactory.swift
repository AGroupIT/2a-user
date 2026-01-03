// Disabled duplicate implementation. Kept as a placeholder to avoid Xcode project warnings if the file is included.
#if false
import Foundation
import UIKit
import Flutter

class VisualEffectViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return VisualEffectPlatformView(frame: frame, viewId: viewId, args: args)
  }
}

private class VisualEffectPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, viewId: Int64, args: Any?) {
    self.container = UIView(frame: frame)
    super.init()

    container.backgroundColor = .clear
    container.isOpaque = false
    container.clipsToBounds = true

    var cornerRadius: CGFloat = 20
    var material: UIBlurEffect.Style = .systemMaterial

    if let dict = args as? [String: Any] {
      if let radius = dict["cornerRadius"] as? NSNumber {
        cornerRadius = CGFloat(truncating: radius)
      }
      if let styleStr = dict["style"] as? String {
        material = Self.parseStyle(styleStr)
      }
    }

    container.layer.cornerRadius = cornerRadius

    let blur = UIBlurEffect(style: material)
    let blurView = UIVisualEffectView(effect: blur)
    blurView.frame = container.bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blurView.backgroundColor = .clear
    blurView.isOpaque = false
    container.addSubview(blurView)
  }

  func view() -> UIView { container }

  private static func parseStyle(_ value: String) -> UIBlurEffect.Style {
    switch value {
    case "systemUltraThinMaterial": return .systemUltraThinMaterial
    case "systemThinMaterial": return .systemThinMaterial
    case "systemMaterial": return .systemMaterial
    case "systemThickMaterial": return .systemThickMaterial
    case "systemChromeMaterial": return .systemChromeMaterial
    case "regular": return .regular
    case "prominent": return .prominent
    default:
      if #available(iOS 13.0, *) { return .systemMaterial } else { return .regular }
    }
  }
}
#endif
