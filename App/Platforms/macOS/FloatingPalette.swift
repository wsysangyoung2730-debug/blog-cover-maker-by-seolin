import SwiftUI

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
