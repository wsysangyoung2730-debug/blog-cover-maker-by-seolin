import SwiftUI

@MainActor final class CanvasInteraction {
  unowned var store: EditorStore
  var start = CGPoint.zero
  var mode = "none"
  var before: CoverProject?
  var originalSelection: Set<UUID> = []
  var originalBounds = CGRect.zero
  var target: UUID?
  var moved = false
  var scale = 1.0
  init(_ store: EditorStore) { self.store = store }
  func contains(_ e: CoverElement, _ p: CGPoint) -> Bool {
    let e = CoverTypography.measured(e, project: store.project)
    var p = p
    if e.number("rot") != 0 {
      let angle = -e.number("rot") * .pi / 180
      let dx = p.x - e.rect.midX
      let dy = p.y - e.rect.midY
      p = CGPoint(
        x: e.rect.midX + dx * cos(angle) - dy * sin(angle),
        y: e.rect.midY + dx * sin(angle) + dy * cos(angle))
    }
    if !e.rect.insetBy(dx: e.type == "text" ? -6 : 0, dy: e.type == "text" ? -6 : 0).contains(p) {
      return false
    }
    if e.type == "rect" && e.values["fill"]?.string == nil && e.values["grad"] == nil
      && e.values["stroke"] != nil
      || e.type == "icon" && ["gapframe", "corners", "archline"].contains(e.string("icon"))
    {
      return !e.rect.insetBy(dx: 18, dy: 18).contains(p)
    }
    return true
  }
  func hit(_ p: CGPoint) -> CoverElement? {
    store.project.elements.reversed().first {
      !$0.flag("hidden") && !$0.flag("pass")
        && !($0.type == "text" && store.project.text(for: $0).isEmpty) && contains($0, p)
    }
  }
  func down(_ p: CGPoint, add: Bool = false, individual: Bool = false, double: Bool = false) {
    store.finishText()
    store.showQuick = false
    start = p
    moved = false
    before = store.project
    originalSelection = store.selection
    target = hit(p)?.id
    if double, let e = hit(p) {
      if e.type == "text" {
        store.startText(e.id)
      } else if e.type == "photo" {
        store.select(e.id, individual: true)
        store.panMode.toggle()
      }
      mode = "none"
      return
    }
    if store.selected.count == 1, let e = store.primary, !store.panMode {
      let e = CoverTypography.measured(e, project: store.project)
      let corners = [
        ("nw", CGPoint(x: e.x, y: e.y)), ("ne", CGPoint(x: e.x + e.w, y: e.y)),
        ("sw", CGPoint(x: e.x, y: e.y + e.h)), ("se", CGPoint(x: e.x + e.w, y: e.y + e.h)),
      ]
      for (name, point) in corners {
        let angle = e.number("rot") * .pi / 180
        let dx = point.x - e.rect.midX
        let dy = point.y - e.rect.midY
        let rotated = CGPoint(
          x: e.rect.midX + dx * cos(angle) - dy * sin(angle),
          y: e.rect.midY + dx * sin(angle) + dy * cos(angle))
        if hypot(p.x - rotated.x, p.y - rotated.y) < 11 / scale {
          mode = name
          target = e.id
          store.begin()
          return
        }
      }
    }
    if store.panMode, let e = store.primary, e.type == "photo", contains(e, p) {
      mode = "pan"
      target = e.id
      store.begin()
      return
    }
    if let e = hit(p) {
      if add || store.multipleSelection {
        store.select(e.id, additive: true, individual: individual)
        mode = "none"
        return
      }
      if e.isBackdrop && !store.selection.contains(e.id) {
        mode = "maybe"
        return
      }
      if !store.selection.contains(e.id) { store.select(e.id, individual: individual) }
      mode = "move"
      originalBounds = CoverEditing.bounds(store.selected, project: store.project)
      store.begin()
    } else {
      mode = "marquee"
      if !add {
        store.select(nil)
        originalSelection = []
      }
    }
  }
  func drag(_ p: CGPoint, lockRatio: Bool = false) {
    guard let before else { return }
    let dx = p.x - start.x
    let dy = p.y - start.y
    if !moved && hypot(dx, dy) < 4 { return }
    moved = true
    if mode == "maybe" {
      mode = "marquee"
      originalSelection = []
      store.select(nil)
    }
    if mode == "marquee" {
      let rect = CGRect(x: min(start.x, p.x), y: min(start.y, p.y), width: abs(dx), height: abs(dy))
      store.marquee = rect
      var ids = originalSelection
      for e in store.project.elements
      where e.isPickable && !(e.type == "text" && store.project.text(for: e).isEmpty) {
        if CoverTypography.visibleBounds(e, project: store.project).intersects(rect) {
          ids.insert(e.id)
          if let g = e.group {
            ids.formUnion(store.project.elements.filter { $0.group == g }.map(\.id))
          }
        }
      }
      store.selection = ids
      return
    }
    if mode == "move" {
      var xx = dx
      var yy = dy
      store.guideX = abs(originalBounds.midX + dx - 540) < 10
      store.guideY = abs(originalBounds.midY + dy - 540) < 10
      if store.guideX { xx = 540 - originalBounds.midX }
      if store.guideY { yy = 540 - originalBounds.midY }
      var next = before
      for i in next.elements.indices where store.selection.contains(next.elements[i].id) {
        next.elements[i].x = (next.elements[i].x + xx).rounded()
        next.elements[i].y = (next.elements[i].y + yy).rounded()
      }
      store.project = next
      return
    }
    guard let id = target, let index = before.elements.firstIndex(where: { $0.id == id }) else {
      return
    }
    var next = before
    let original = CoverTypography.measured(before.elements[index], project: before)
    if mode == "pan" {
      next.elements[index].set("ox", original.number("ox") + dx)
      next.elements[index].set("oy", original.number("oy") + dy)
    } else if ["nw", "ne", "sw", "se"].contains(mode) {
      if original.type == "text" {
        let width = max(40, original.w + (mode.contains("e") ? dx : -dx))
        next.elements[index].w = width
        if mode.contains("w") { next.elements[index].x = original.x + original.w - width }
        let size = min(400, max(8, original.number("size") * width / max(1, original.w)))
        next.elements[index].set("size", size)
        next.elements[index].set("baseSize", size)
        next.elements[index].set("manualSize", true)
      } else {
        var x0 = original.x
        var y0 = original.y
        var x1 = original.x + original.w
        var y1 = original.y + original.h
        if mode.contains("w") { x0 += dx } else { x1 += dx }
        if mode.contains("n") { y0 += dy } else { y1 += dy }
        if lockRatio || original.string("icon") == "bookmark" {
          let k = max((x1 - x0) / max(1, original.w), (y1 - y0) / max(1, original.h))
          if mode.contains("w") { x0 = x1 - original.w * k } else { x1 = x0 + original.w * k }
          if mode.contains("n") { y0 = y1 - original.h * k } else { y1 = y0 + original.h * k }
        }
        next.elements[index].x = min(x0, x1 - 20)
        next.elements[index].y = min(y0, y1 - 20)
        next.elements[index].w = max(20, x1 - x0)
        next.elements[index].h = max(20, y1 - y0)
      }
    }
    store.project = next
  }
  func up(_ p: CGPoint) {
    if mode == "maybe", !moved { store.select(target) }
    store.end()
    store.marquee = nil
    store.guideX = false
    store.guideY = false
    if !moved && mode == "move", let target, originalSelection.count > 1 { store.select(target) }
    if mode != "none", !store.selected.isEmpty,
      store.selected.count > 1 || store.primary?.type != "photo"
    {
      store.showQuick = true
    }
    mode = "none"
    before = nil
  }
  func cancel() {
    store.cancelInteraction()
    mode = "none"
    before = nil
    target = nil
  }
  func wheel(_ p: CGPoint, delta: Double) {
    guard delta != 0 else { return }
    guard
      let e = store.project.elements.reversed().first(where: {
        $0.type == "photo" && !$0.flag("hidden") && contains($0, p)
      })
    else { return }
    store.select(e.id, individual: true)
    store.setNumber("zoom", min(3, max(0.2, e.number("zoom", 1) * (delta > 0 ? 1.06 : 1 / 1.06))))
  }
  func drawOverlay(in c: CGContext) {
    let selected = store.selected
    let blue = CGColor(red: 0.12, green: 0.44, blue: 1, alpha: 1)
    c.saveGState()
    defer { c.restoreGState() }
    c.setStrokeColor(blue)
    c.setLineWidth(1.5 / scale)
    for e in selected {
      let e = CoverTypography.measured(e, project: store.project)
      c.saveGState()
      c.translateBy(x: e.rect.midX, y: e.rect.midY)
      c.rotate(by: e.number("rot") * .pi / 180)
      c.translateBy(x: -e.rect.midX, y: -e.rect.midY)
      if store.panMode { c.setLineDash(phase: 0, lengths: [5 / scale, 4 / scale]) }
      c.stroke(e.rect)
      if selected.count == 1 && !store.panMode {
        for point in [
          CGPoint(x: e.x, y: e.y), CGPoint(x: e.x + e.w, y: e.y), CGPoint(x: e.x, y: e.y + e.h),
          CGPoint(x: e.x + e.w, y: e.y + e.h),
        ] {
          let rect = CGRect(
            x: point.x - 5 / scale, y: point.y - 5 / scale, width: 10 / scale, height: 10 / scale)
          c.setFillColor(CGColor(gray: 1, alpha: 1))
          c.fillEllipse(in: rect)
          c.strokeEllipse(in: rect)
        }
      }
      c.restoreGState()
    }
    if selected.count > 1 {
      c.setLineDash(phase: 0, lengths: [5 / scale, 3 / scale])
      c.stroke(CoverEditing.bounds(selected, project: store.project))
      c.setLineDash(phase: 0, lengths: [])
    }
    if let rect = store.marquee {
      c.setFillColor(blue.copy(alpha: 0.1)!)
      c.fill(rect)
      c.setLineDash(phase: 0, lengths: [5 / scale, 3 / scale])
      c.stroke(rect)
    }
    c.setStrokeColor(CGColor(red: 1, green: 0.2, blue: 0.5, alpha: 1))
    c.setLineDash(phase: 0, lengths: [])
    if store.guideX {
      c.move(to: CGPoint(x: 540, y: 0))
      c.addLine(to: CGPoint(x: 540, y: 1080))
      c.strokePath()
    }
    if store.guideY {
      c.move(to: CGPoint(x: 0, y: 540))
      c.addLine(to: CGPoint(x: 1080, y: 540))
      c.strokePath()
    }
  }
}
