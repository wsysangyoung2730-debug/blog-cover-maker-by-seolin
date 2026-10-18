#if os(iOS)
  import SwiftUI
  import UIKit
  import UniformTypeIdentifiers
  final class PadCanvas: UIView, UIDropInteractionDelegate {
    let store: EditorStore
    let interaction: CanvasInteraction
    private var pinchStart = 1.0
    private var activeTouch: UITouch?
    private var pendingDoubleTap = false
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
    override var canBecomeFirstResponder: Bool { true }
    override var undoManager: UndoManager? { store.undoManager }
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
      guard activeTouch == nil, let t = touches.first, event?.allTouches?.count == 1 else {
        return
      }
      activeTouch = t
      becomeFirstResponder()
      pendingDoubleTap = t.tapCount == 2
      // Begin as a drag candidate even on a quick second touch. Opening a text
      // editor here would consume the rest of a tap-then-drag gesture.
      interaction.down(point(t), deferSelectionToggle: true)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let t = activeTouch, touches.contains(t), event?.allTouches?.count == 1 else {
        return
      }
      interaction.drag(point(t))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let t = activeTouch, touches.contains(t) else { return }
      let location = point(t)
      interaction.drag(location)
      if pendingDoubleTap && !interaction.moved {
        interaction.cancel()
        interaction.down(location, double: true)
      }
      // iPad popovers consume outside touches. Keep the quick editor available
      // through the View menu instead of opening it after every selection.
      interaction.up(location, showsQuickPalette: false)
      activeTouch = nil
      pendingDoubleTap = false
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let t = activeTouch, touches.contains(t) else { return }
      cancelTouch()
    }
    private func cancelTouch() {
      activeTouch = nil
      pendingDoubleTap = false
      interaction.cancel()
    }
    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
      guard let e = store.photo else { return }
      if gesture.state == .began {
        cancelTouch()
        store.select(e.id, individual: true)
        pinchStart = e.number("zoom", 1)
        store.begin()
      }
      store.setNumber("zoom", max(0.2, min(3, pinchStart * gesture.scale)))
      if gesture.state == .ended { store.end("사진 확대") }
      if gesture.state == .cancelled { interaction.cancel() }
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
      // Collect in the drop order, then commit the entire drop as one undoable operation.
      let items = target?.type == "photo" ? Array(session.items.prefix(1)) : session.items
      Task { @MainActor [weak self] in
        guard let self else { return }
        do {
          var payloads: [Data] = []
          for item in items {
            let data: Data = try await withCheckedThrowingContinuation { continuation in
              item.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
                data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? ProjectError.invalidImage) }
              }
            }
            payloads.append(data)
          }
          self.store.finishText()
          var next = self.store.project
          var added: UUID?
          if target?.type == "photo" {
            guard next.elements.contains(where: { $0.id == target?.id }) else {
              self.store.error = "사진 프레임이 변경되었어요. 다시 놓아 주세요."
              return
            }
            if let data = payloads.first {
              try CoverEditing.replacePhoto(data, elementID: target?.id, in: &next)
            }
          } else {
            for data in payloads { added = try CoverEditing.addPhoto(data, at: point, in: &next) }
          }
          self.store.change(target?.type == "photo" ? "사진 교체" : "사진 추가") { $0 = next }
          if let added { self.store.select(added) }
        } catch { self.store.error = error.localizedDescription }
      }
    }
  }
#endif
