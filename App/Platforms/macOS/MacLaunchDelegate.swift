#if os(macOS)
  import AppKit

  /// Let AppKit create a native untitled document instead of a startup open panel.
  final class MacLaunchDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
    func applicationDidFinishLaunching(_ notification: Notification) {
      DispatchQueue.main.async {
        let controller = NSDocumentController.shared
        guard controller.documents.isEmpty else { return }
        // SwiftUI can have already presented its automatic startup panel.
        // Dismiss only that launch panel; later File > Open remains native.
        for panel in NSApp.windows.compactMap({ $0 as? NSOpenPanel }) { panel.cancel(nil) }
        controller.newDocument(nil)
      }
    }
  }
#endif
