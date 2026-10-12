#if os(iOS)
  import SwiftUI
  import UIKit
  import UniformTypeIdentifiers
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
