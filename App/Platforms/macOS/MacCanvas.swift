#if os(macOS)
  import SwiftUI
  import AppKit
  import UniformTypeIdentifiers
  final class MacCanvas: NSView {
    let store: EditorStore
    let interaction: CanvasInteraction
    private var wheelTimer: Timer?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(store: EditorStore) {
      self.store = store
      interaction = CanvasInteraction(store)
      super.init(frame: .zero)
      registerForDraggedTypes([.fileURL])
      setAccessibilityElement(true)
      setAccessibilityLabel("표지 편집 화면")
      setAccessibilityRole(.group)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
      guard let c = NSGraphicsContext.current?.cgContext else { return }
      let scale = bounds.width / 1080
      interaction.scale = scale
      c.saveGState()
      c.scaleBy(x: scale, y: scale)
      var preview = store.project
      preview.elements.removeAll { $0.id == store.editingID }
      store.renderer.draw(in: c, project: preview)
      interaction.drawOverlay(in: c)
      c.restoreGState()
    }
    func point(_ event: NSEvent) -> CGPoint {
      let p = convert(event.locationInWindow, from: nil)
      return CGPoint(x: p.x * 1080 / bounds.width, y: p.y * 1080 / bounds.height)
    }
    override func mouseDown(with event: NSEvent) {
      window?.makeFirstResponder(self)
      interaction.down(
        point(event), add: !event.modifierFlags.intersection([.shift, .command, .control]).isEmpty,
        individual: event.modifierFlags.contains(.option), double: event.clickCount == 2)
    }
    override func mouseDragged(with event: NSEvent) {
      interaction.drag(point(event), lockRatio: event.modifierFlags.contains(.shift))
    }
    override func mouseUp(with event: NSEvent) { interaction.up(point(event)) }
    override func scrollWheel(with event: NSEvent) {
      store.begin()
      interaction.wheel(point(event), delta: event.scrollingDeltaY)
      wheelTimer?.invalidate()
      wheelTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
        MainActor.assumeIsolated { self?.store.end("사진 확대") }
      }
    }
    override func keyDown(with event: NSEvent) {
      let shift = event.modifierFlags.contains(.shift)
      let command = event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)
      if command {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "a":
          store.selectAll()
          return
        case "d":
          store.duplicate()
          return
        case "g":
          shift ? store.ungroup() : store.group()
          return
        case "z":
          shift ? store.undoManager?.redo() : store.undoManager?.undo()
          return
        default: break
        }
      }
      let d = shift ? 10.0 : 1.0
      switch event.keyCode {
      case 51, 117: store.delete()
      case 53: store.select(nil)
      case 123: store.nudge(dx: -d, dy: 0)
      case 124: store.nudge(dx: d, dy: 0)
      case 125: store.nudge(dx: 0, dy: d)
      case 126: store.nudge(dx: 0, dy: -d)
      default: super.keyDown(with: event)
      }
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
      let urls =
        sender.draggingPasteboard.readObjects(
          forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
      guard !urls.isEmpty else { return false }
      let p = convert(sender.draggingLocation, from: nil)
      let point = CGPoint(x: p.x * 1080 / bounds.width, y: p.y * 1080 / bounds.height)
      let target = interaction.hit(point)
      store.importFiles(
        target?.type == "photo" ? Array(urls.prefix(1)) : urls,
        kind: target?.type == "photo" ? .replace : .add, at: point, target: target?.id)
      return true
    }
    override func menu(for event: NSEvent) -> NSMenu? {
      if let e = interaction.hit(point(event)), !store.selection.contains(e.id) {
        store.select(e.id)
      }
      let menu = NSMenu()
      for (title, selector) in [
        ("빠른 편집", #selector(quick)), ("복제", #selector(duplicate)),
        ("삭제", #selector(deleteSelection)), ("그룹 묶기", #selector(group)),
        ("그룹 풀기", #selector(ungroup)), ("같은 종류 선택", #selector(same)),
      ] {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
      }
      return menu
    }
    @objc func quick() { store.showQuick = true }
    @objc func duplicate() { store.duplicate() }
    @objc func deleteSelection() { store.delete() }
    @objc func group() { store.group() }
    @objc func ungroup() { store.ungroup() }
    @objc func same() { store.selectSame() }
  }
#endif
