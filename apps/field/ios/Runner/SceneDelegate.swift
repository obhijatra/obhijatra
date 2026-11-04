import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Covers the window while the app is not active, so the snapshot iOS
  /// keeps for the app switcher (and anyone glancing at the screen) never
  /// shows answers. Android keeps FLAG_SECURE for the same reason.
  private var privacyCover: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    showPrivacyCover()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    hidePrivacyCover()
  }

  private func showPrivacyCover() {
    guard privacyCover == nil, let window = window else { return }
    // A solid cover, not a blur: a blur can still show the shape of large
    // text.
    let cover = UIView(frame: window.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.backgroundColor = .systemBackground
    cover.isUserInteractionEnabled = false
    cover.accessibilityElementsHidden = true
    window.addSubview(cover)
    window.bringSubviewToFront(cover)
    privacyCover = cover
  }

  private func hidePrivacyCover() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
