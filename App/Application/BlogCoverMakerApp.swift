import SwiftUI

@main
struct BlogCoverMakerApp: App {
  init() {
    CoverTypography.registerBundledFonts()
    #if DEBUG
      EditorVerification.runIfRequested()
    #endif
  }
  var body: some Scene {
    DocumentGroup(newDocument: { CoverDocument() }) { configuration in
      EditorRoot(document: configuration.document)
    }
    #if os(macOS)
      .defaultSize(width: 1440, height: 900)
      .commands { EditorCommands() }
    #endif
  }
}
