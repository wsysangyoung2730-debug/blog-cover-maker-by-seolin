import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
  import AppKit
  struct CanvasSurface: NSViewRepresentable {
    @ObservedObject var store: EditorStore
    func makeNSView(context: Context) -> MacCanvas { MacCanvas(store: store) }
    func updateNSView(_ view: MacCanvas, context: Context) { view.needsDisplay = true }
  }
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
#else
  import UIKit
  struct CanvasSurface: UIViewRepresentable {
    @ObservedObject var store: EditorStore
    func makeUIView(context: Context) -> PadCanvas { PadCanvas(store: store) }
    func updateUIView(_ view: PadCanvas, context: Context) { view.setNeedsDisplay() }
  }
  final class PadCanvas: UIView, UIDropInteractionDelegate {
    let store: EditorStore
    let interaction: CanvasInteraction
    private var pinchStart = 1.0
    init(store: EditorStore) {
      self.store = store
      interaction = CanvasInteraction(store)
      super.init(frame: .zero)
      backgroundColor = .clear
      isMultipleTouchEnabled = true
      isAccessibilityElement = true
      accessibilityLabel = "표지 편집 화면"
      addInteraction(UIDropInteraction(delegate: self))
      addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
      guard let c = UIGraphicsGetCurrentContext() else { return }
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
    private func point(_ touch: UITouch) -> CGPoint {
      let p = touch.location(in: self)
      return CGPoint(x: p.x * 1080 / bounds.width, y: p.y * 1080 / bounds.height)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let t = touches.first, event?.allTouches?.count == 1 else { return }
      interaction.down(point(t), double: t.tapCount == 2)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let t = touches.first, event?.allTouches?.count == 1 else { return }
      interaction.drag(point(t))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      if let t = touches.first { interaction.up(point(t)) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      store.cancelInteraction()
    }
    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
      guard let e = store.photo else { return }
      if gesture.state == .began {
        store.cancelInteraction()
        store.select(e.id, individual: true)
        pinchStart = e.number("zoom", 1)
        store.begin()
      }
      store.setNumber("zoom", max(0.2, min(3, pinchStart * gesture.scale)))
      if gesture.state == .ended { store.end("사진 확대") }
      if gesture.state == .cancelled { store.cancelInteraction() }
    }
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool
    { session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier]) }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession)
      -> UIDropProposal
    { UIDropProposal(operation: .copy) }
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
      let location = session.location(in: self)
      let point = CGPoint(x: location.x * 1080 / bounds.width, y: location.y * 1080 / bounds.height)
      let target = self.interaction.hit(point)
      for item in session.items {
        item.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
          [weak self] data, _ in
          guard let data else { return }
          Task { @MainActor in
            guard let self else { return }
            do {
              let before = self.store.project
              if target?.type == "photo" {
                self.store.change("사진 교체") { p in
                  do { try CoverEditing.replacePhoto(data, elementID: target?.id, in: &p) } catch {
                    self.store.error = error.localizedDescription
                  }
                }
              } else {
                var next = before
                let id = try CoverEditing.addPhoto(data, at: point, in: &next)
                self.store.change("사진 추가") { $0 = next }
                self.store.select(id)
              }
            } catch { self.store.error = error.localizedDescription }
          }
        }
      }
    }
  }
#endif
