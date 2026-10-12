import CoreGraphics
import CoreText
import Foundation

public enum CoverTypography {
  private struct BundledFace {
    var font: CTFont
    var weight: Double
    var variable: Bool
  }
  private static let bundledFaces: [String: [BundledFace]] = {
    var faces: [String: [BundledFace]] = [:]
    let weights: [String: Double] = [
      "Thin": 100, "ExtraLight": 200, "Light": 300,
      "Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700, "ExtraBold": 800, "Black": 900,
    ]
    for url in CoverConstants.resourceBundle.urls(
      forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
    {
      guard let provider = CGDataProvider(url: url as CFURL), let graphics = CGFont(provider) else {
        continue
      }
      let file = url.deletingPathExtension().lastPathComponent
      let family = String(file.split(separator: "-")[0])
      let style = String(file.split(separator: "-").last ?? "Regular")
      let face = BundledFace(
        font: CTFontCreateWithGraphicsFont(graphics, 48, nil, nil),
        weight: weights[style] ?? 400, variable: file.contains("[wght]"))
      faces[family, default: []].append(face)
    }
    return faces
  }()
  private static func bundledFont(family: String, weight: Double, size: Double) -> CTFont {
    let key = family.lowercased().filter { $0.isLetter || $0.isNumber }
    guard
      let face = bundledFaces[key]?.min(by: { abs($0.weight - weight) < abs($1.weight - weight) })
    else {
      // This is only a corrupt-resource fallback; supported options always resolve to their bundled file.
      return CTFontCreateUIFontForLanguage(.system, size, nil)!
    }
    if face.variable {
      let descriptor = CTFontDescriptorCreateWithAttributes(
        [
          kCTFontVariationAttribute: [NSNumber(value: 0x7767_6874): min(900, max(100, weight))]
        ] as CFDictionary)
      return CTFontCreateCopyWithAttributes(face.font, size, nil, descriptor)
    }
    return CTFontCreateCopyWithAttributes(face.font, size, nil, nil)
  }
  private final class FontData: NSObject {
    let descriptor: CTFontDescriptor
    init(_ descriptor: CTFontDescriptor) { self.descriptor = descriptor }
  }
  private static let userDescriptors = NSCache<NSString, FontData>()
  private static func descriptor(for asset: UserFontAsset) -> CTFontDescriptor? {
    if let cached = userDescriptors.object(forKey: asset.id as NSString) {
      return cached.descriptor
    }
    guard
      let descriptors = CTFontManagerCreateFontDescriptorsFromData(asset.data as CFData)
        as? [CTFontDescriptor], let first = descriptors.first
    else { return nil }
    userDescriptors.setObject(FontData(first), forKey: asset.id as NSString)
    return first
  }
  public static func registerBundledFonts() {
    _ = bundledFaces
  }
  public static func register(_ asset: UserFontAsset) {
    _ = descriptor(for: asset)
  }
  public static func importFont(_ data: Data, name: String) throws -> UserFontAsset {
    guard
      let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData)
        as? [CTFontDescriptor], let descriptor = descriptors.first,
      let postscript = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
    else { throw ProjectError.invalidFont }
    let asset = UserFontAsset(
      id: UUID().uuidString, name: name, postScriptName: postscript, data: data)
    register(asset)
    return asset
  }
  public static func font(_ e: CoverElement, project p: CoverProject, size: Double) -> CTFont {
    var family = "Noto Sans KR"
    var weight = "400"
    let catalog = CoverCatalog.shared
    if let user = p.fonts.first(where: { $0.id == e.string("ff") }),
      let descriptor = descriptor(for: user)
    {
      let base = CTFontCreateWithFontDescriptor(descriptor, size, nil)
      return base
    }
    if let f = catalog.fonts.first(where: { $0.id == e.string("ff") }) {
      family = f.family
      weight = f.w
    } else {
      switch e.string("font", "title") {
      case "title":
        if let f = catalog.titleFonts.first(where: { $0.id == p.titleFontID }) {
          family = f.family
          weight = f.w
        }
      case "light":
        family = p.titleFontID == "myeongjo" ? "Nanum Myeongjo" : "Noto Sans KR"
        weight = p.titleFontID == "myeongjo" ? "700" : p.titleFontID == "bhs" ? "500" : "300"
      case "medium":
        family = p.titleFontID == "myeongjo" ? "Nanum Myeongjo" : "Noto Sans KR"
        weight = p.titleFontID == "myeongjo" ? "800" : "500"
      case "script": family = "Great Vibes"
      case "serif":
        family = "Nanum Myeongjo"
        weight = e.string("weight", "800")
      case "display": family = "Black Han Sans"
      default: weight = e.string("weight", "400")
      }
    }
    weight = e.string("fw", weight)
    return bundledFont(family: family, weight: Double(weight) ?? 400, size: size)
  }
  public static func attributes(_ e: CoverElement, project: CoverProject, size: Double)
    -> [NSAttributedString.Key: Any]
  {
    let selectedFont = font(e, project: project, size: size)
    var result: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): selectedFont,
      NSAttributedString.Key(kCTKernAttributeName as String): e.number("spacing"),
    ]
    // A single-face uploaded font may have no bold sibling. Preserve the face and synthesize bold.
    if (Double(e.string("fw")) ?? 0) >= 600
      && !CTFontGetSymbolicTraits(selectedFont).contains(.traitBold)
    {
      result[NSAttributedString.Key(kCTStrokeWidthAttributeName as String)] = -2.0
    }
    return result
  }
  public static func width(_ text: String, e: CoverElement, project: CoverProject, size: Double)
    -> Double
  {
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: text, attributes: attributes(e, project: project, size: size)))
    return CTLineGetTypographicBounds(line, nil, nil, nil)
  }
  public struct Line {
    public var text: String
    public var offset: Int
  }
  public struct Layout {
    public var size: Double
    public var lines: [Line]
    public var height: Double
    public var step: Double
  }
  public static func layout(_ e: CoverElement, project: CoverProject) -> Layout {
    var size = e.number("baseSize", e.number("size", 60))
    let raw = project.text(for: e)
    func lines(_ size: Double) -> [Line] {
      var output: [Line] = []
      var offset = 0
      for paragraph in raw.components(separatedBy: "\n") {
        if e.flag("wrap") {
          var current = ""
          var lineOffset = offset
          var position = offset
          for word in paragraph.components(separatedBy: " ") {
            let candidate = current.isEmpty ? word : current + " " + word
            if !current.isEmpty
              && width(candidate, e: e, project: project, size: size) > e.w - 2 * e.number("padX")
            {
              output.append(Line(text: current, offset: lineOffset))
              current = word
              lineOffset = position
            } else {
              if current.isEmpty { lineOffset = position }
              current = candidate
            }
            position += word.utf16.count + 1
          }
          output.append(Line(text: current, offset: lineOffset))
        } else {
          output.append(Line(text: paragraph, offset: offset))
        }
        offset += paragraph.utf16.count + 1
      }
      return output
    }
    var ls = lines(size)
    let fit = e.values["fit"] != .bool(false) && !e.flag("manualSize")
    if fit && e.flag("wrap") && e.number("maxLines") > 0 {
      while ls.count > Int(e.number("maxLines")) && size > 24 {
        size -= 2
        ls = lines(size)
      }
    } else if fit && !e.flag("wrap") {
      while ls.map({ width($0.text, e: e, project: project, size: size) }).max() ?? 0 > e.w - 2
        * e.number("padX") && size > 16
      {
        size -= 2
        ls = lines(size)
      }
    }
    let bg = e.values["bg"]?.string != nil
    let step =
      bg ? size * 1.22 + e.number("padY") * 2 + e.number("gap", 10) : size * e.number("lh", 1.25)
    let height =
      raw.isEmpty
      ? 0
      : bg
        ? Double(ls.count) * step - e.number("gap", 10)
        : Double(max(0, ls.count - 1)) * step + size * 1.2
    return Layout(size: size, lines: ls, height: height, step: step)
  }
  public static func measured(_ e: CoverElement, project: CoverProject) -> CoverElement {
    guard e.type == "text" else { return e }
    var output = e
    let layout = layout(e, project: project)
    output.h = layout.height
    output.set("size", layout.size)
    return output
  }
  public static func visibleBounds(_ e: CoverElement, project: CoverProject) -> CGRect {
    guard e.type == "text" else { return e.rect }
    let l = layout(e, project: project)
    let w =
      (l.lines.map { width($0.text, e: e, project: project, size: l.size) }.max() ?? 0) + e.number(
        "padX") * 2
    let x =
      e.string("align") == "center"
      ? e.x + e.w / 2 - w / 2 : e.string("align") == "right" ? e.x + e.w - w : e.x
    return CGRect(x: x, y: e.y, width: w, height: max(8, l.height))
  }
}
