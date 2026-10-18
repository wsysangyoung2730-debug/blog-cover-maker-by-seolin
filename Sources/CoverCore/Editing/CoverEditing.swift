import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum CoverEditing {
  public static func units(_ elements: [CoverElement]) -> [[CoverElement]] {
    var result: [[CoverElement]] = []
    var groups: [String: Int] = [:]
    for e in elements {
      let key = e.group ?? e.id.uuidString
      if let i = groups[key] {
        result[i].append(e)
      } else {
        groups[key] = result.count
        result.append([e])
      }
    }
    return result
  }
  public static func bounds(_ elements: [CoverElement], project: CoverProject) -> CGRect {
    elements.reduce(CGRect.null) { $0.union(CoverTypography.visibleBounds($1, project: project)) }
  }
  public static func duplicate(_ ids: Set<UUID>, in p: inout CoverProject) -> Set<UUID> {
    let source = p.elements.filter { ids.contains($0.id) }
    guard !source.isEmpty else { return [] }
    var groups: [String: String] = [:]
    let copies = source.map { e -> CoverElement in
      var copy = e
      copy.id = UUID()
      copy.x += 30
      copy.y += 30
      if !e.string("bind").isEmpty {
        copy.set("text", p.text(for: e))
        copy.values.removeValue(forKey: "bind")
      }
      if let g = e.group {
        if groups[g] == nil { groups[g] = UUID().uuidString }
        copy.set("g", groups[g]!)
      }
      if let history = p.frameHistory[e.id.uuidString] {
        p.frameHistory[copy.id.uuidString] = history
      }
      return copy
    }
    let index = (p.elements.lastIndex { ids.contains($0.id) } ?? p.elements.count - 1) + 1
    p.elements.insert(contentsOf: copies, at: index)
    return Set(copies.map(\.id))
  }
  public static func group(_ ids: Set<UUID>, in p: inout CoverProject) {
    guard ids.count > 1 else { return }
    let group = UUID().uuidString
    for i in p.elements.indices where ids.contains(p.elements[i].id) {
      p.elements[i].set("g", group)
    }
  }
  public static func ungroup(_ ids: Set<UUID>, in p: inout CoverProject) {
    let groups = Set(p.elements.filter { ids.contains($0.id) }.compactMap(\.group))
    for i in p.elements.indices where groups.contains(p.elements[i].group ?? "") {
      p.elements[i].values.removeValue(forKey: "g")
    }
  }
  public static func move(_ ids: Set<UUID>, direction: String, in p: inout CoverProject) {
    let selected = p.elements.filter { ids.contains($0.id) }
    let rest = p.elements.filter { !ids.contains($0.id) }
    if direction == "front" {
      p.elements = rest + selected
    } else if direction == "back" {
      p.elements = selected + rest
    } else {
      let up = direction == "up"
      let indices = p.elements.indices.filter { ids.contains(p.elements[$0].id) }
      for i in up ? indices.reversed().map({ $0 }) : indices {
        let j = i + (up ? 1 : -1)
        if p.elements.indices.contains(j), !ids.contains(p.elements[j].id) {
          p.elements.swapAt(i, j)
        }
      }
    }
  }
  public static func reorder(_ ids: Set<UUID>, before targetID: UUID?, in p: inout CoverProject) {
    guard targetID.map({ !ids.contains($0) }) ?? true else { return }
    let display = p.elements.reversed().map { $0 }
    let moving = display.filter { ids.contains($0.id) }
    var rest = display.filter { !ids.contains($0.id) }
    let index = targetID.flatMap { target in rest.firstIndex { $0.id == target } } ?? rest.count
    rest.insert(contentsOf: moving, at: index)
    p.elements = rest.reversed()
  }
  @discardableResult public static func align(
    _ ids: Set<UUID>, how: String, in p: inout CoverProject
  ) -> Bool {
    let selected = p.elements.filter { ids.contains($0.id) }
    let units = units(selected)
    guard !units.isEmpty else { return false }
    let target =
      units.count == 1
      ? CGRect(x: 0, y: 0, width: 1080, height: 1080) : bounds(selected, project: p)
    var offsets: [UUID: CGPoint] = [:]
    if how == "dh" || how == "dv" {
      guard units.count >= 3 else { return false }
      let horizontal = how == "dh"
      let sorted = units.map { ($0, bounds($0, project: p)) }.sorted {
        horizontal ? $0.1.minX < $1.1.minX : $0.1.minY < $1.1.minY
      }
      let lengths = sorted.map { horizontal ? $0.1.width : $0.1.height }
      let first = horizontal ? sorted.first!.1.minX : sorted.first!.1.minY
      let last = horizontal ? sorted.last!.1.maxX : sorted.last!.1.maxY
      let gap = (last - first - lengths.reduce(0, +)) / Double(sorted.count - 1)
      var position = first
      for (index, item) in sorted.enumerated() {
        let delta = position - (horizontal ? item.1.minX : item.1.minY)
        for e in item.0 {
          offsets[e.id] = CGPoint(x: horizontal ? delta : 0, y: horizontal ? 0 : delta)
        }
        position += lengths[index] + gap
      }
    } else {
      for unit in units {
        let b = bounds(unit, project: p)
        var d = CGPoint.zero
        switch how {
        case "l": d.x = target.minX - b.minX
        case "c": d.x = target.midX - b.midX
        case "r": d.x = target.maxX - b.maxX
        case "t": d.y = target.minY - b.minY
        case "m": d.y = target.midY - b.midY
        case "b": d.y = target.maxY - b.maxY
        default: break
        }
        for e in unit { offsets[e.id] = d }
      }
    }
    for i in p.elements.indices {
      if let delta = offsets[p.elements[i].id] {
        p.elements[i].x = (p.elements[i].x + delta.x).rounded()
        p.elements[i].y = (p.elements[i].y + delta.y).rounded()
      }
    }
    return true
  }
  /// Align the image inside its crop, leaving the frame and zoom unchanged.
  /// Page-clipped photos share the first photo's transform with the renderer.
  @discardableResult public static func alignPhotoContent(
    _ id: UUID, how: String, in p: inout CoverProject
  ) -> Bool {
    guard let photo = p.elements.first(where: { $0.id == id && $0.type == "photo" }),
      let ref = photo.flag("page") ? p.elements.first(where: { $0.type == "photo" }) : photo,
      let index = p.elements.firstIndex(where: { $0.id == ref.id }),
      ["l", "c", "r", "t", "m", "b"].contains(how)
    else { return false }
    let box = photo.flag("page")
      ? CGRect(x: 0, y: 0, width: CoverConstants.canvasSize, height: CoverConstants.canvasSize)
      : photo.rect
    var offset = 0.0
    if !["c", "m"].contains(how) {
      guard let imageID = p.imageID(for: ref), let data = p.images[imageID],
        let image = ImageAssets.image(data) else { return false }
      let scale = max(box.width / Double(image.width), box.height / Double(image.height))
        * ref.number("zoom", 1)
      let horizontal = ["l", "r"].contains(how)
      let imageLength = Double(horizontal ? image.width : image.height) * scale
      let boxLength = horizontal ? box.width : box.height
      offset = (imageLength - boxLength) / 2 * (["l", "t"].contains(how) ? 1 : -1)
    }
    p.elements[index].set(["l", "c", "r"].contains(how) ? "ox" : "oy", offset)
    return true
  }
  public static func replacePhoto(_ data: Data, elementID: UUID?, in p: inout CoverProject) throws {
    let normalized = try ImageAssets.normalize(data)
    let id = UUID().uuidString
    p.images[id] = normalized
    if let eid = elementID, let i = p.elements.firstIndex(where: { $0.id == eid }),
      p.elements[i].values["src"]?.string != nil || p.frameHistory[eid.uuidString] != nil
    {
      var h = p.frameHistory[eid.uuidString] ?? PhotoHistory()
      if h.items.isEmpty { h.push(p.elements[i].values["src"]?.string) }
      h.push(id)
      p.frameHistory[eid.uuidString] = h
      p.elements[i].set("src", id)
      resetCrop(&p.elements[i])
    } else {
      p.mainPhoto.push(id)
      for i in p.elements.indices
      where p.elements[i].type == "photo" && p.elements[i].values["src"]?.string == nil {
        resetCrop(&p.elements[i])
      }
    }
  }
  @discardableResult public static func addPhoto(
    _ data: Data, at point: CGPoint? = nil, in p: inout CoverProject
  ) throws -> UUID {
    let data = try ImageAssets.normalize(data)
    guard let image = ImageAssets.image(data) else { throw ProjectError.invalidImage }
    let id = UUID().uuidString
    p.images[id] = data
    let scale = min(520.0 / Double(image.width), 520.0 / Double(image.height))
    let w = Double(image.width) * scale
    let h = Double(image.height) * scale
    let point = point ?? CGPoint(x: 540, y: 540)
    var e = CoverElement([
      "type": .string("photo"), "name": .string("추가 사진"), "src": .string(id),
      "shape": .string("rect"), "r": .number(12), "zoom": .number(1),
    ])
    e.x = point.x - w / 2
    e.y = point.y - h / 2
    e.w = w
    e.h = h
    e.values["o0"] = .object([
      "x": .number(e.x), "y": .number(e.y), "w": .number(w), "h": .number(h), "rot": .number(0),
    ])
    p.elements.insert(e, at: p.elements.firstIndex(where: \.isForeground) ?? p.elements.count)
    return e.id
  }
  public static func resetCrop(_ e: inout CoverElement) {
    e.set("ox", 0)
    e.set("oy", 0)
    e.set("zoom", 1)
  }
  public static func resetPhoto(_ e: inout CoverElement) {
    for (key, value) in e.values["o0"]?.object ?? [:] { e.values[key] = value }
    resetCrop(&e)
  }
  public static func stepPhoto(_ delta: Int, elementID: UUID?, in p: inout CoverProject) {
    if let id = elementID, let i = p.elements.firstIndex(where: { $0.id == id }),
      p.elements[i].values["src"]?.string != nil || p.frameHistory[id.uuidString] != nil
    {
      var h = p.frameHistory[id.uuidString] ?? PhotoHistory()
      if h.items.isEmpty { h.push(p.elements[i].values["src"]?.string) }
      guard h.step(delta) else { return }
      p.frameHistory[id.uuidString] = h
      p.elements[i].values["src"] = h.current.map(JSONValue.string)
      resetCrop(&p.elements[i])
    } else if p.mainPhoto.step(delta) {
      for i in p.elements.indices
      where p.elements[i].type == "photo" && p.elements[i].values["src"]?.string == nil {
        resetCrop(&p.elements[i])
      }
    }
  }
}
public enum ImageAssets {
  public static func image(_ data: Data) -> CGImage? {
    CGImageSourceCreateWithData(data as CFData, nil).flatMap {
      CGImageSourceCreateImageAtIndex($0, 0, nil)
    }
  }
  public static func normalize(_ data: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 2200,
        ] as CFDictionary)
    else { throw ProjectError.invalidImage }
    return try png(image)
  }
  public static func png(_ image: CGImage) throws -> Data {
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data, UTType.png.identifier as CFString, 1, nil)
    else { throw ProjectError.exportFailed }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw ProjectError.exportFailed }
    return data as Data
  }
}
