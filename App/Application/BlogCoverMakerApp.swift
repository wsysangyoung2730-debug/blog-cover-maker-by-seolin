import SwiftUI

#if !DEBUG || !STORE_SCREENSHOTS || !os(iOS)
@main
#endif
struct BlogCoverMakerApp: App {
  init() {
    CoverTypography.registerBundledFonts()
    #if DEBUG
      EditorVerification.runIfRequested()
    #endif
  }
  var body: some Scene {
    #if os(iOS)
      if #available(iOS 18.0, *) {
        PadLaunchScene()
      }
    #endif
    DocumentGroup(newDocument: { CoverDocument() }) { configuration in
      EditorRoot(document: configuration.document)
    }
    #if os(macOS)
      .defaultSize(width: 1440, height: 900)
      .commands { EditorCommands() }
    #endif
  }
}
