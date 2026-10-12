import SwiftUI

@main
struct BlogCoverMakerApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 48))
                Text("BLOG COVER MAKER").font(.largeTitle.bold())
                Text("by SEOLIN").foregroundStyle(.secondary)
            }
            .frame(minWidth: 640, minHeight: 480)
        }
    }
}
