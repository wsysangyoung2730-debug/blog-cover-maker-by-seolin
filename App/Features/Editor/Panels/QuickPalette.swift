import SwiftUI

struct QuickPalette: View {
  @ObservedObject var store: EditorStore
  @State private var collapsed = false
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(
          store.selected.count == 1 ? store.primary?.name ?? "빠른 편집" : "\(store.selected.count)개 선택"
        ).font(.headline)
        Spacer()
        Button {
          collapsed.toggle()
        } label: {
          Image(systemName: collapsed ? "chevron.down" : "chevron.up")
        }
        Button {
          store.showQuick = false
        } label: {
          Image(systemName: "xmark")
        }
      }.buttonStyle(.plain)
      if !collapsed {
        let ids = Set(store.selected.filter { $0.type == "text" }.map(\.id))
        if !ids.isEmpty {
          TextStyleControls(store: store, ids: ids)
          FontPicker(store: store, ids: ids)
        }
        if let e = store.selected.first(where: { $0.colorKey != nil }) {
          SwatchPicker(store: store, token: e.string(e.colorKey!, "#fff")) { store.setColor($0) }
        }
        HStack {
          Button("그룹 묶기") { store.group() }.disabled(store.selected.count < 2)
          Button("그룹 풀기") { store.ungroup() }.disabled(!store.selected.contains { $0.group != nil })
        }
      }
    }.padding(14).frame(minWidth: 240, idealWidth: 280, maxWidth: 420).fixedSize(
      horizontal: false, vertical: true)
  }
}
#if os(macOS)
  import AppKit
  @MainActor final class FloatingPalette: NSObject, NSWindowDelegate {
    let panel: NSPanel
    weak var store: EditorStore?
    init(store: EditorStore) {
      self.store = store
      panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 340),
        styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
        backing: .buffered, defer: false)
      super.init()
      panel.title = "빠른 편집"
      panel.isFloatingPanel = true
      panel.hidesOnDeactivate = true
      panel.isReleasedWhenClosed = false
      panel.minSize = NSSize(width: 260, height: 150)
      panel.maxSize = NSSize(width: 440, height: 600)
      panel.contentView = NSHostingView(rootView: QuickPalette(store: store))
      panel.delegate = self
      panel.setFrameAutosaveName("SeolinQuickPalette")
      if !panel.setFrameUsingName("SeolinQuickPalette") {
        let p = NSEvent.mouseLocation
        panel.setFrameTopLeftPoint(NSPoint(x: p.x + 15, y: p.y))
      }
    }
    func show() { panel.orderFront(nil) }
    func hide() { panel.orderOut(nil) }
    func windowWillClose(_ notification: Notification) { store?.showQuick = false }
  }
#endif
