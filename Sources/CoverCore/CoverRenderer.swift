import CoreGraphics
import CoreImage
import CoreText
import Foundation

public enum ExportMode: String, CaseIterable, Identifiable {
  case all, background, foreground
  public var id: String { rawValue }
  public var label: String {
    switch self {
    case .all: return "표지 전체"
    case .background: return "배경만"
    case .foreground: return "글씨·장식만"
    }
  }
}

public final class CoverRenderer {
  private let ci = CIContext(options: [.cacheIntermediates: false])
  private var cache: [String: CGImage] = [:]
  public init() {}
  public static func color(_ token: String?, project: CoverProject) -> CGColor {
    guard let token, !token.isEmpty else { return CGColor(red: 0, green: 0, blue: 0, alpha: 0) }
    let parts = token.split(separator: "@", omittingEmptySubsequences: false)
    var hex = String(parts[0])
    if hex.hasPrefix("$") { hex = project.theme.color(String(hex.dropFirst())) }
    hex = hex.replacingOccurrences(of: "#", with: "")
    if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
    let n = UInt32(hex, radix: 16) ?? 0
    let alpha = parts.count > 1 ? Double(parts[1]) ?? 1 : 1
    return CGColor(
      red: Double((n >> 16) & 255) / 255, green: Double((n >> 8) & 255) / 255,
      blue: Double(n & 255) / 255, alpha: alpha)
  }
  public func image(project: CoverProject, size: Int = 1080, mode: ExportMode = .all) -> CGImage? {
    guard size > 0, size <= 8192,
      let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.translateBy(x: 0, y: Double(size))
    context.scaleBy(x: Double(size) / 1080, y: -Double(size) / 1080)
    draw(in: context, project: project, mode: mode)
    return context.makeImage()
  }
  public func png(project: CoverProject, mode: ExportMode) throws -> Data {
    guard let image = image(project: project, mode: mode) else { throw ProjectError.exportFailed }
    return try ImageAssets.png(image)
  }
  public func draw(in c: CGContext, project p: CoverProject, mode: ExportMode = .all) {
    for raw in p.elements where !raw.flag("hidden") {
      if mode == .background && raw.isForeground || mode == .foreground && !raw.isForeground {
        continue
      }
      let e = CoverTypography.measured(raw, project: p)
      if e.number("blur") > 0,
        let surface = CGContext(
          data: nil, width: 1080, height: 1080, bitsPerComponent: 8, bytesPerRow: 0,
          space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      {
        surface.translateBy(x: 0, y: 1080)
        surface.scaleBy(x: 1, y: -1)
        drawElement(e, in: surface, project: p)
        if let rawImage = surface.makeImage() {
          let input = CIImage(cgImage: rawImage)
          let filtered = input.applyingFilter(
            "CIGaussianBlur", parameters: [kCIInputRadiusKey: e.number("blur")])
          if let image = ci.createCGImage(filtered, from: input.extent) {
            drawImage(image, in: c, rect: CGRect(x: 0, y: 0, width: 1080, height: 1080))
          }
        }
      } else {
        drawElement(e, in: c, project: p)
      }
    }
    // Avoid retaining abandoned projects' images indefinitely.
    if cache.count > p.images.count + 30 { cache.removeAll() }
  }
  private func drawElement(_ e: CoverElement, in c: CGContext, project p: CoverProject) {
    c.saveGState()
    defer { c.restoreGState() }
    c.setAlpha(max(0, min(1, p.opacity(for: e))))
    if e.number("rot") != 0 {
      c.translateBy(x: e.rect.midX, y: e.rect.midY)
      c.rotate(by: e.number("rot") * .pi / 180)
      c.translateBy(x: -e.rect.midX, y: -e.rect.midY)
    }
    if e.values["shadow"] != nil && e.values["shadow"] != .number(0)
      && e.values["shadow"] != .bool(false)
    {
      let s = e.values["shadow"]?.object ?? [:]
      c.setShadow(
        offset: CGSize(width: 0, height: s["y"]?.number ?? 2), blur: s["blur"]?.number ?? 16,
        color: CGColor(gray: 0, alpha: s["a"]?.number ?? 0.35))
    }
    switch e.type {
    case "photo": drawPhoto(e, in: c, project: p)
    case "text": drawText(e, in: c, project: p)
    case "rect":
      let path = roundedRect(e.rect, radii: e.values["r"])
      if let gradient = e.values["grad"]?.object {
        c.saveGState()
        c.addPath(path)
        c.clip()
        let stops = gradient["stops"]?.array ?? []
        let colors = stops.map {
          Self.color($0.array.count > 1 ? $0.array[1].string : nil, project: p)
        }
        let locations = stops.map { CGFloat($0.array.first?.number ?? 0) }
        if let g = CGGradient(
          colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray,
          locations: locations)
        {
          let horizontal = gradient["dir"]?.string == "h"
          c.drawLinearGradient(
            g, start: CGPoint(x: e.x, y: e.y),
            end: CGPoint(x: horizontal ? e.x + e.w : e.x, y: horizontal ? e.y : e.y + e.h),
            options: [])
        }
        c.restoreGState()
      } else if let fill = e.values["fill"]?.string {
        c.setFillColor(Self.color(fill, project: p))
        c.addPath(path)
        c.fillPath()
      }
      stroke(path, e: e, in: c, project: p)
    case "ellipse":
      let path = CGPath(ellipseIn: e.rect, transform: nil)
      if let radial = e.values["radial"]?.array {
        c.saveGState()
        c.addPath(path)
        c.clip()
        if let g = CGGradient(
          colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
          colors: radial.map { Self.color($0.string, project: p) } as CFArray, locations: nil)
        {
          c.drawRadialGradient(
            g, startCenter: CGPoint(x: e.x + e.w * 0.38, y: e.y + e.h * 0.35),
            startRadius: e.w * 0.06, endCenter: CGPoint(x: e.rect.midX, y: e.rect.midY),
            endRadius: e.w / 2, options: [])
        }
        c.restoreGState()
      } else if let fill = e.values["fill"]?.string {
        c.setFillColor(Self.color(fill, project: p))
        c.addPath(path)
        c.fillPath()
      }
      stroke(path, e: e, in: c, project: p, defaultWidth: 4)
    case "arc":
      let path = CGMutablePath()
      let transform = CGAffineTransform(translationX: e.rect.midX, y: e.rect.midY).scaledBy(
        x: e.w / 2, y: e.h / 2)
      path.addArc(
        center: .zero, radius: 1, startAngle: e.number("a0") * .pi / 180,
        endAngle: e.number("a1") * .pi / 180, clockwise: false, transform: transform)
      stroke(path, e: e, in: c, project: p, defaultWidth: 6)
    case "path":
      let path = CGMutablePath()
      for (index, point) in (e.values["pts"]?.array ?? []).enumerated() {
        let pair = point.array
        guard pair.count == 2 else { continue }
        let pt = CGPoint(x: e.x + (pair[0].number ?? 0) * e.w, y: e.y + (pair[1].number ?? 0) * e.h)
        if index == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
      }
      if e.flag("closed") {
        path.closeSubpath()
        if let fill = e.values["fill"]?.string {
          c.setFillColor(Self.color(fill, project: p))
          c.addPath(path)
          c.fillPath()
        }
      }
      stroke(path, e: e, in: c, project: p, defaultWidth: 4)
    case "icon": drawIcon(e, in: c, project: p)
    default: break
    }
  }
  private func stroke(
    _ path: CGPath, e: CoverElement, in c: CGContext, project p: CoverProject,
    defaultWidth: Double = 3
  ) {
    guard let color = e.values["stroke"]?.string else { return }
    c.setShadow(offset: .zero, blur: 0, color: nil)
    c.setStrokeColor(Self.color(color, project: p))
    c.setLineWidth(e.number("sw", defaultWidth))
    c.setLineJoin(.round)
    c.setLineCap(.round)
    c.addPath(path)
    c.strokePath()
  }
  public func roundedRect(_ r: CGRect, radii: JSONValue?) -> CGPath {
    var a = radii?.array.compactMap(\.number) ?? []
    if a.count != 4 { a = Array(repeating: radii?.number ?? 0, count: 4) }
    a = a.map { max(0, min($0, min(r.width, r.height) / 2)) }
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX + a[0], y: r.minY))
    p.addLine(to: CGPoint(x: r.maxX - a[1], y: r.minY))
    p.addArc(
      tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY + a[1]),
      radius: a[1])
    p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - a[2]))
    p.addArc(
      tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - a[2], y: r.maxY),
      radius: a[2])
    p.addLine(to: CGPoint(x: r.minX + a[3], y: r.maxY))
    p.addArc(
      tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - a[3]),
      radius: a[3])
    p.addLine(to: CGPoint(x: r.minX, y: r.minY + a[0]))
    p.addArc(
      tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + a[0], y: r.minY),
      radius: a[0])
    p.closeSubpath()
    return p
  }
  private func photoPath(_ e: CoverElement) -> CGPath {
    if e.string("shape") == "ellipse" { return CGPath(ellipseIn: e.rect, transform: nil) }
    let p = CGMutablePath()
    if e.string("shape") == "arch" {
      p.move(to: CGPoint(x: e.x, y: e.y + e.h))
      p.addLine(to: CGPoint(x: e.x, y: e.y + e.w / 2))
      p.addArc(
        center: CGPoint(x: e.x + e.w / 2, y: e.y + e.w / 2), radius: e.w / 2, startAngle: .pi,
        endAngle: 0, clockwise: false)
      p.addLine(to: CGPoint(x: e.x + e.w, y: e.y + e.h))
      p.closeSubpath()
      return p
    }
    if e.string("shape") == "slant" {
      p.addLines(between: [
        CGPoint(x: e.x + e.w * 0.35, y: e.y), CGPoint(x: e.x + e.w, y: e.y),
        CGPoint(x: e.x + e.w, y: e.y + e.h), CGPoint(x: e.x, y: e.y + e.h),
      ])
      p.closeSubpath()
      return p
    }
    return roundedRect(e.rect, radii: e.values["r"])
  }
  private func drawPhoto(_ e: CoverElement, in c: CGContext, project p: CoverProject) {
    c.saveGState()
    defer { c.restoreGState() }
    c.addPath(photoPath(e))
    c.clip()
    let ref = e.flag("page") ? p.elements.first(where: { $0.type == "photo" }) ?? e : e
    let box = e.flag("page") ? CGRect(x: 0, y: 0, width: 1080, height: 1080) : e.rect
    if let id = p.imageID(for: ref), let data = p.images[id] {
      let image = cache[id] ?? ImageAssets.image(data)
      if let image {
        cache[id] = image
        let scale =
          max(box.width / Double(image.width), box.height / Double(image.height))
          * ref.number("zoom", 1)
        var draw = image
        if e.number("blurPhoto") > 0 || e.values["duo"]?.string != nil {
          var input = CIImage(cgImage: image)
          if e.values["duo"]?.string != nil {
            input = input.applyingFilter(
              "CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.1])
          }
          if e.number("blurPhoto") > 0 {
            input = input.clampedToExtent().applyingFilter(
              "CIGaussianBlur",
              parameters: [kCIInputRadiusKey: e.number("blurPhoto") / max(0.01, scale)])
          }
          draw =
            ci.createCGImage(
              input, from: CGRect(x: 0, y: 0, width: image.width, height: image.height)) ?? image
        }
        let w = Double(image.width) * scale
        let h = Double(image.height) * scale
        drawImage(
          draw, in: c,
          rect: CGRect(
            x: box.midX - w / 2 + ref.number("ox"), y: box.midY - h / 2 + ref.number("oy"),
            width: w, height: h))
      }
    } else {
      if let g = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [Self.color("#A9BCDB", project: p), Self.color("#56719F", project: p)] as CFArray,
        locations: [0, 1])
      {
        c.drawLinearGradient(
          g, start: e.rect.origin, end: CGPoint(x: e.rect.maxX, y: e.rect.maxY), options: [])
      }
      c.setStrokeColor(CGColor(gray: 1, alpha: 0.1))
      c.setLineWidth(2)
      for offset in stride(from: -e.h, to: e.w, by: 36) {
        c.move(to: CGPoint(x: e.x + offset, y: e.y + e.h))
        c.addLine(to: CGPoint(x: e.x + offset + e.h, y: e.y))
        c.strokePath()
      }
    }
    if let duo = e.values["duo"]?.string {
      c.setBlendMode(.multiply)
      c.setFillColor(Self.color(duo, project: p))
      c.fill(e.rect)
    }
  }
  private func drawImage(_ image: CGImage, in c: CGContext, rect: CGRect) {
    c.saveGState()
    c.translateBy(x: rect.minX, y: rect.maxY)
    c.scaleBy(x: 1, y: -1)
    c.draw(image, in: CGRect(origin: .zero, size: rect.size))
    c.restoreGState()
  }
  private func drawText(_ e: CoverElement, in c: CGContext, project p: CoverProject) {
    let layout = CoverTypography.layout(e, project: p)
    let size = layout.size
    let px = e.number("padX")
    let py = e.number("padY")
    let full = p.text(for: e) as NSString
    let highlight = p.words["hl", default: ""]
    let range =
      highlight.isEmpty || e.values["hl"]?.string == nil
      ? NSRange(location: NSNotFound, length: 0) : full.range(of: highlight)
    for (index, line) in layout.lines.enumerated() {
      let w = CoverTypography.width(line.text, e: e, project: p, size: size)
      let y = e.y + Double(index) * layout.step
      let x =
        e.string("align") == "center"
        ? e.x + e.w / 2 - w / 2 : e.string("align") == "right" ? e.x + e.w - w - px : e.x + px
      var ty = y
      if let bg = e.values["bg"]?.string, !line.text.isEmpty {
        c.saveGState()
        c.setShadow(offset: .zero, blur: 0, color: nil)
        c.setFillColor(Self.color(bg, project: p))
        let path = roundedRect(
          CGRect(x: x - px, y: y, width: w + 2 * px, height: size * 1.22 + 2 * py),
          radii: e.string("bgR") == "pill" ? .number(999) : e.values["bgR"])
        c.addPath(path)
        c.fillPath()
        if let stroke = e.values["bgStroke"]?.string {
          c.setStrokeColor(Self.color(stroke, project: p))
          c.setLineWidth(3)
          c.addPath(path)
          c.strokePath()
        }
        c.restoreGState()
        ty = y + py + size * 0.07
      }
      let local = NSIntersectionRange(
        range, NSRange(location: line.offset, length: line.text.utf16.count))
      if let marker = e.values["marker"]?.string, local.length > 0 {
        let str = line.text as NSString
        let before = str.substring(to: local.location - line.offset)
        let mark = str.substring(
          with: NSRange(location: local.location - line.offset, length: local.length))
        let left = CoverTypography.width(before, e: e, project: p, size: size)
        let width = CoverTypography.width(mark, e: e, project: p, size: size)
        c.saveGState()
        c.setShadow(offset: .zero, blur: 0, color: nil)
        c.setFillColor(Self.color(marker, project: p))
        c.fill(CGRect(x: x + left - 6, y: ty + size * 0.52, width: width + 12, height: size * 0.5))
        c.restoreGState()
      }
      var attributes = CoverTypography.attributes(e, project: p, size: size)
      attributes[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = Self.color(
        e.string("color", "#fff"), project: p)
      let attributed = NSMutableAttributedString(string: line.text, attributes: attributes)
      if local.length > 0 {
        attributed.addAttribute(
          NSAttributedString.Key(kCTForegroundColorAttributeName as String),
          value: Self.color(e.values["hl"]?.string, project: p),
          range: NSRange(location: local.location - line.offset, length: local.length))
      }
      let font = CoverTypography.font(e, project: p, size: size)
      func text(_ string: NSAttributedString, stroke: Bool) {
        c.saveGState()
        c.textMatrix = CGAffineTransform(a: 1, b: 0, c: e.flag("it") ? 0.2 : 0, d: -1, tx: 0, ty: 0)
        c.textPosition = CGPoint(x: x, y: ty + CTFontGetAscent(font))
        if stroke {
          c.setShadow(offset: .zero, blur: 0, color: nil)
          c.setTextDrawingMode(.stroke)
          c.setStrokeColor(Self.color(e.values["stroke"]?.string, project: p))
          c.setLineWidth(e.number("sw", 6))
          c.setLineJoin(.round)
        }
        CTLineDraw(CTLineCreateWithAttributedString(string), c)
        c.restoreGState()
      }
      if e.values["stroke"]?.string != nil { text(attributed, stroke: true) }
      if !e.flag("outline") { text(attributed, stroke: false) }
      c.saveGState()
      c.setShadow(offset: .zero, blur: 0, color: nil)
      c.setFillColor(Self.color(e.string("color", "#fff"), project: p))
      if e.flag("ul") {
        c.fill(CGRect(x: x, y: ty + size * 1.08, width: w, height: max(2, size * 0.06)))
      }
      if e.flag("st") {
        c.fill(CGRect(x: x, y: ty + size * 0.55, width: w, height: max(2, size * 0.06)))
      }
      c.restoreGState()
    }
  }
  private func drawIcon(_ e: CoverElement, in c: CGContext, project: CoverProject) {
    let x = e.x
    let y = e.y
    let w = e.w
    let h = e.h
    let path = CGMutablePath()
    c.setStrokeColor(Self.color(e.values["color"]?.string, project: project))
    c.setFillColor(Self.color(e.values["color"]?.string, project: project))
    c.setLineCap(.round)
    c.setLineJoin(.round)
    c.setLineWidth(e.number("sw", 5))
    func move(_ xx: Double, _ yy: Double) { path.move(to: CGPoint(x: xx, y: yy)) }
    func line(_ xx: Double, _ yy: Double) { path.addLine(to: CGPoint(x: xx, y: yy)) }
    var seed = 3.0
    func random() -> Double {
      seed = (seed * 16807).truncatingRemainder(dividingBy: 2_147_483_647)
      return (seed - 1) / 2_147_483_646
    }
    switch e.string("icon") {
    case "bookmark":
      move(x, y)
      line(x + w, y)
      line(x + w, y + h)
      line(x + w / 2, y + h * 0.67)
      line(x, y + h)
      path.closeSubpath()
    case "arrow":
      c.setLineWidth(e.number("sw", 4))
      move(x, y + h / 2)
      line(x + w, y + h / 2)
      move(x + w - h * 0.55, y + h * 0.08)
      line(x + w, y + h / 2)
      line(x + w - h * 0.55, y + h * 0.92)
    case "gapframe":
      let r = 26.0
      let g1 = y + h * 0.14
      let g2 = y + h * 0.5
      move(x, g1)
      line(x, y + r)
      path.addArc(tangent1End: CGPoint(x: x, y: y), tangent2End: CGPoint(x: x + r, y: y), radius: r)
      line(x + w - r, y)
      path.addArc(
        tangent1End: CGPoint(x: x + w, y: y), tangent2End: CGPoint(x: x + w, y: y + r), radius: r)
      line(x + w, g1)
      move(x + w, g2)
      line(x + w, y + h - r)
      path.addArc(
        tangent1End: CGPoint(x: x + w, y: y + h), tangent2End: CGPoint(x: x + w - r, y: y + h),
        radius: r)
      line(x + r, y + h)
      path.addArc(
        tangent1End: CGPoint(x: x, y: y + h), tangent2End: CGPoint(x: x, y: y + h - r), radius: r)
      line(x, g2)
    case "bubbles":
      for _ in 0..<60 {
        let xx = x + random() * w
        let yy = y + random() * h
        let r = 3 + random() * 5
        c.fillEllipse(in: CGRect(x: xx - r, y: yy - r, width: r * 2, height: r * 2))
      }
      return
    case "grain":
      seed = 5
      for _ in 0..<max(0, Int((w * h / 480).rounded())) {
        c.fill(CGRect(x: x + random() * w, y: y + random() * h, width: 2, height: 2))
      }
      return
    case "lines":
      for yy in stride(from: y + 62, to: y + h, by: 72) {
        c.fill(CGRect(x: x, y: yy, width: w, height: 2))
      }
      return
    case "grid":
      for xx in stride(from: x, through: x + w, by: 40) {
        c.fill(CGRect(x: xx, y: y, width: 1.5, height: h))
      }
      for yy in stride(from: y, through: y + h, by: 40) {
        c.fill(CGRect(x: x, y: yy, width: w, height: 1.5))
      }
      return
    case "filmholes":
      for xx in stride(from: x + 18, to: x + w, by: 62) {
        for yy in [y, y + h - 22] {
          c.addPath(roundedRect(CGRect(x: xx, y: yy, width: 30, height: 22), radii: .number(5)))
          c.fillPath()
        }
      }
      return
    case "checkbox":
      c.setLineWidth(e.number("sw", 6))
      c.addPath(
        roundedRect(CGRect(x: x + 3, y: y + 3, width: w - 6, height: h - 6), radii: .number(12)))
      c.strokePath()
      c.setLineWidth(e.number("sw", 6) + 2)
      move(x + w * 0.24, y + h * 0.52)
      line(x + w * 0.44, y + h * 0.72)
      line(x + w * 0.78, y + h * 0.3)
    case "ring":
      c.setLineWidth(e.number("sw", 3))
      path.addEllipse(in: e.rect.insetBy(dx: 2, dy: 2))
    case "corners":
      let length = min(w, h) * 0.12
      c.setLineWidth(e.number("sw", 6))
      move(x, y + length)
      line(x, y)
      line(x + length, y)
      move(x + w - length, y)
      line(x + w, y)
      line(x + w, y + length)
      move(x + w, y + h - length)
      line(x + w, y + h)
      line(x + w - length, y + h)
      move(x + length, y + h)
      line(x, y + h)
      line(x, y + h - length)
    case "archline":
      c.setLineWidth(e.number("sw", 3))
      move(x, y + h)
      line(x, y + w / 2)
      path.addArc(
        center: CGPoint(x: x + w / 2, y: y + w / 2), radius: w / 2, startAngle: .pi, endAngle: 0,
        clockwise: false)
      line(x + w, y + h)
    case "scribble":
      c.setLineWidth(e.number("sw", 5))
      move(x + w * 0.9, y + h * 0.05)
      path.addCurve(
        to: CGPoint(x: x + w * 0.25, y: y + h * 0.9),
        control1: CGPoint(x: x + w * 0.2, y: y + h * 0.1),
        control2: CGPoint(x: x + w * 1.05, y: y + h * 0.6))
      move(x + w * 0.45, y + h * 0.95)
      line(x + w * 0.22, y + h * 0.9)
      line(x + w * 0.32, y + h * 0.68)
    default: break
    }
    c.addPath(path)
    c.strokePath()
  }
}
