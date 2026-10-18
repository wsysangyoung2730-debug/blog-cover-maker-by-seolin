import SwiftUI

#if !DEBUG || !STORE_SCREENSHOTS || !os(iOS)
@main
#endif
struct BlogCoverMakerApp: App {
  #if os(macOS)
    @NSApplicationDelegateAdaptor(MacLaunchDelegate.self) private var appDelegate
  #endif
  init() {
    CoverTypography.registerBundledFonts()
    #if DEBUG
      EditorVerification.runIfRequested()
    #endif
  }
  var body: some Scene {
    #if os(iOS)
      WindowGroup { PadEditorScene() }
    #else
    DocumentGroup(newDocument: { CoverDocument() }) { configuration in
      EditorRoot(document: configuration.document)
    }
    #if os(macOS)
      .defaultSize(width: 1440, height: 900)
      .commands { EditorCommands() }
    #endif
    #endif
  }
}
