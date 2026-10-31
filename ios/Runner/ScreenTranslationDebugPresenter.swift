#if DEBUG || SCREEN_TRANSLATION_STAGE0
import SwiftUI
import UIKit

/// Diagnostic entry point in the existing app. No effect without launch argument.
enum ScreenTranslationDebugPresenter {
  private static var observer: NSObjectProtocol?
  private static var presented = false

  static func install() {
    guard ProcessInfo.processInfo.arguments.contains("--screen-translation-stage0") else { return }
    guard #available(iOS 27.0, *) else { return }
    observer = NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { notification in
      guard let scene = notification.object as? UIWindowScene else { return }
      DispatchQueue.main.async {
        guard !presented, let window = scene.windows.first(where: { $0.isKeyWindow }),
              var presenter = window.rootViewController else { return }
        while let next = presenter.presentedViewController { presenter = next }
        let host = UIHostingController(rootView: ScreenTranslationProbeView())
        host.modalPresentationStyle = .fullScreen
        presented = true
        presenter.present(host, animated: false)
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
      }
    }
  }
}
#endif
