#if DEBUG && STORE_SCREENSHOTS && os(iOS)
import SwiftUI

@main struct StoreScreenshotApp: App {
  init() { CoverTypography.registerBundledFonts() }
  var body: some Scene {
    WindowGroup {
      NavigationStack { EditorRoot(document: StoreScreenshotFixture.document!) }
    }
  }
}

/// Reproducible Simulator captures use the production editor and a local sample document.
/// This entry point and its launch arguments are absent from distribution builds.
@MainActor enum StoreScreenshotFixture {
  static func argument(_ name: String) -> String? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
      return nil
    }
    return arguments[index + 1]
  }

  static let document: CoverDocument? = {
    guard let path = argument("--screenshot-fixture") else { return nil }
    do {
      let project = try CoverProject.decode(Data(contentsOf: URL(fileURLWithPath: path)))
      project.fonts.forEach(CoverTypography.register)
      return CoverDocument(project: project)
    } catch {
      preconditionFailure("Cannot load screenshot fixture: \(error)")
    }
  }()
}
#endif
