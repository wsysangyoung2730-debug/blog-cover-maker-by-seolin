import CoreGraphics
import Foundation

/// Retains every original template attribute, including effects only used by one design.
public enum JSONValue: Codable, Equatable {
  case number(Double)
  case string(String)
  case bool(Bool)
  case array([JSONValue])
  case object([String: JSONValue])
  case null
  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() {
      self = .null
    } else if let v = try? c.decode(Bool.self) {
      self = .bool(v)
    } else if let v = try? c.decode(Double.self) {
      self = .number(v)
    } else if let v = try? c.decode(String.self) {
      self = .string(v)
    } else if let v = try? c.decode([JSONValue].self) {
      self = .array(v)
    } else {
      self = .object(try c.decode([String: JSONValue].self))
    }
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .number(let v): try c.encode(v)
    case .string(let v): try c.encode(v)
    case .bool(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    case .object(let v): try c.encode(v)
    case .null: try c.encodeNil()
    }
  }
  public var number: Double? {
    if case .number(let v) = self { return v }
    return nil
  }
  public var string: String? {
    if case .string(let v) = self { return v }
    return nil
  }
  public var array: [JSONValue] {
    if case .array(let v) = self { return v }
    return []
  }
  public var object: [String: JSONValue] {
    if case .object(let v) = self { return v }
    return [:]
  }
  public var truth: Bool {
    switch self {
    case .bool(let v): return v
    case .number(let v): return v != 0
    case .string(let v): return !v.isEmpty
    case .object, .array: return true
    case .null: return false
    }
  }
}

public struct CoverElement: Codable, Equatable, Identifiable {
  public var id = UUID()
  public var values: [String: JSONValue]
  public init(_ values: [String: JSONValue]) { self.values = values }
  public func number(_ key: String, _ fallback: Double = 0) -> Double {
    values[key]?.number ?? fallback
  }
  public func string(_ key: String, _ fallback: String = "") -> String {
    values[key]?.string ?? fallback
  }
  public func flag(_ key: String) -> Bool { values[key]?.truth ?? false }
  public mutating func set(_ key: String, _ value: Double) { values[key] = .number(value) }
  public mutating func set(_ key: String, _ value: String) { values[key] = .string(value) }
  public mutating func set(_ key: String, _ value: Bool) { values[key] = .bool(value) }
  public var type: String { string("type") }
  public var name: String {
    get { string("name", "요소") }
    set { set("name", newValue) }
  }
  public var x: Double {
    get { number("x") }
    set { set("x", newValue) }
  }
  public var y: Double {
    get { number("y") }
    set { set("y", newValue) }
  }
  public var w: Double {
    get { number("w") }
    set { set("w", newValue) }
  }
  public var h: Double {
    get { number("h") }
    set { set("h", newValue) }
  }
  public var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
  public var group: String? { values["g"]?.string }
  public var isForeground: Bool { type == "text" || string("layer") == "fg" }
  public var isBackdrop: Bool { w * h >= 1080 * 1080 * 0.85 }
  public var isPickable: Bool { !flag("hidden") && !flag("pass") && !isBackdrop }
  public var colorKey: String? {
    if type == "text" || type == "icon" { return "color" }
    if type == "arc" { return "stroke" }
    if values["fill"]?.string != nil { return "fill" }
    if values["stroke"]?.string != nil { return "stroke" }
    return nil
  }
}

public struct CoverTemplate: Decodable, Identifiable {
  public let id: String
  public let name: String
  public let category: String
  public let elements: [[String: JSONValue]]
}
public struct CoverTheme: Decodable, Identifiable {
  public let id: String
  public let name: String
  public let dark: String
  public let main: String
  public let accent: String
  public let paper: String
  public let ink: String
  public let rb: Int?
  public func color(_ key: String) -> String {
    switch key {
    case "dark": return dark
    case "main": return main
    case "accent": return accent
    case "paper": return paper
    default: return ink
    }
  }
}
public struct CoverFont: Codable, Identifiable, Equatable {
  public let id: String
  public let name: String?
  public let n: String?
  public let w: String
  public let f: String
  public var label: String { name ?? n ?? id }
  public var family: String { f.replacingOccurrences(of: "\"", with: "") }
}
public struct CoverCatalog: Decodable {
  public let templates: [CoverTemplate]
  public let themes: [CoverTheme]
  public let titleFonts: [CoverFont]
  public let fonts: [CoverFont]
  public let defaults: [String: JSONValue]
  public static let shared: CoverCatalog = {
    guard let url = CoverConstants.resourceBundle.url(forResource: "catalog", withExtension: "json")
    else { fatalError("디자인 데이터가 누락되었습니다") }
    do { return try JSONDecoder().decode(CoverCatalog.self, from: Data(contentsOf: url)) } catch {
      fatalError("디자인 데이터를 읽을 수 없습니다: \(error)")
    }
  }()
}
public struct PhotoHistory: Codable, Equatable {
  public var items: [String?] = []
  public var index = -1
  public init() {}
  public mutating func push(_ id: String?) {
    items = Array(items.prefix(index + 1))
    items.append(id)
    index = items.count - 1
  }
  public mutating func step(_ delta: Int) -> Bool {
    let next = index + delta
    guard items.indices.contains(next) else { return false }
    index = next
    return true
  }
  public var current: String? { items.indices.contains(index) ? items[index] : nil }
}
public struct UserFontAsset: Codable, Equatable, Identifiable {
  public var id: String
  public var name: String
  public var postScriptName: String
  public var data: Data
}
public struct CoverProject: Codable, Equatable {
  public var version = 1
  public var templateID = "full"
  public var themeID = "blue"
  public var titleFontID = "gothic"
  public var dim = 55.0
  public var words: [String: String] = [:]
  public var elements: [CoverElement] = []
  public var images: [String: Data] = [:]
  public var mainPhoto = PhotoHistory()
  public var frameHistory: [String: PhotoHistory] = [:]
  public var fonts: [UserFontAsset] = []
  public init() {
    let c = CoverCatalog.shared
    words = c.defaults.compactMapValues { $0.string }
    for key in ["tpl", "theme", "font"] { words.removeValue(forKey: key) }
    applyTemplate("full")
  }
  public mutating func applyTemplate(_ id: String) {
    guard let template = CoverCatalog.shared.templates.first(where: { $0.id == id }) else { return }
    templateID = id
    elements = template.elements.map { raw in
      var e = CoverElement(raw)
      if e.type == "photo" {
        e.values["o0"] = .object(raw.filter { ["x", "y", "w", "h", "rot"].contains($0.key) })
      }
      if e.type == "text" { e.set("baseSize", e.number("size", 60)) }
      return e
    }
  }
  public var theme: CoverTheme {
    CoverCatalog.shared.themes.first { $0.id == themeID } ?? CoverCatalog.shared.themes[0]
  }
  public func text(for e: CoverElement) -> String {
    let raw = e.string("bind").isEmpty ? e.string("text") : words[e.string("bind"), default: ""]
    return e.flag("upper") ? raw.uppercased() : raw
  }
  public func imageID(for e: CoverElement) -> String? {
    e.values["src"]?.string ?? mainPhoto.current
  }
  public func opacity(for e: CoverElement) -> Double {
    let a = e.values["dim"]?.array ?? []
    if a.count == 2 { return min(1, (a[0].number ?? 0) + (a[1].number ?? 0) * dim / 100) }
    return e.number("opacity", 1)
  }
  public mutating func setText(_ text: String, elementID: UUID) {
    guard let i = elements.firstIndex(where: { $0.id == elementID }) else { return }
    let bind = elements[i].string("bind")
    if bind.isEmpty {
      elements[i].set("text", text)
      elements[i].values.removeValue(forKey: "manualSize")
    } else {
      words[bind] = text
      for index in elements.indices where elements[index].string("bind") == bind {
        elements[index].values.removeValue(forKey: "manualSize")
      }
    }
  }
  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(self)
  }
  public static func decode(_ data: Data) throws -> CoverProject {
    let p = try JSONDecoder().decode(CoverProject.self, from: data)
    guard p.version == 1 else { throw ProjectError.unsupportedVersion }
    guard p.elements.count <= 10000,
      p.elements.allSatisfy({ e in
        e.x.isFinite && e.y.isFinite && e.w.isFinite && e.h.isFinite && e.w >= 0 && e.h >= 0
      })
    else { throw ProjectError.invalidGeometry }
    return p
  }
}
public enum ProjectError: LocalizedError {
  case unsupportedVersion, invalidGeometry, invalidImage, invalidFont, exportFailed
  public var errorDescription: String? {
    switch self {
    case .unsupportedVersion: return "이 버전의 프로젝트는 열 수 없습니다."
    case .invalidGeometry: return "프로젝트의 요소 위치나 크기가 올바르지 않습니다."
    case .invalidImage: return "이미지를 열 수 없습니다. JPG·PNG 등 이미지 파일을 선택하세요."
    case .invalidFont: return "이 폰트를 읽을 수 없습니다. 유효한 폰트 파일을 선택하세요."
    case .exportFailed: return "이미지를 저장하지 못했습니다."
    }
  }
}
