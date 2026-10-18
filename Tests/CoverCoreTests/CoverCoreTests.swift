import CoreGraphics
import CoreText
import XCTest

@testable import CoverCore

final class CoverCoreTests: XCTestCase {
  func testPhotoContentAlignmentKeepsCropAndZoom() throws {
    let context = try XCTUnwrap(CGContext(
      data: nil, width: 800, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let image = try XCTUnwrap(context.makeImage())
    var project = CoverProject()
    let photo = CoverElement([
      "type": .string("photo"), "x": .number(90), "y": .number(140),
      "w": .number(300), "h": .number(300), "zoom": .number(2),
      "ox": .number(45), "oy": .number(-70), "src": .string("photo"),
    ])
    project.elements = [photo]
    project.images["photo"] = try ImageAssets.png(image)
    for (how, key, expected) in [
      ("l", "ox", 450.0), ("c", "ox", 0), ("r", "ox", -450),
      ("t", "oy", 150), ("m", "oy", 0), ("b", "oy", -150),
    ] {
      XCTAssertTrue(CoverEditing.alignPhotoContent(photo.id, how: how, in: &project))
      XCTAssertEqual(project.elements[0].number(key), expected, accuracy: 0.001)
      XCTAssertEqual(project.elements[0].rect, photo.rect)
      XCTAssertEqual(project.elements[0].number("zoom"), 2)
    }
    let before = project
    XCTAssertFalse(CoverEditing.alignPhotoContent(photo.id, how: "dh", in: &project))
    XCTAssertEqual(project, before)
  }

  func testPagePhotoAlignmentUsesSharedImageTransform() {
    var project = CoverProject()
    var first = CoverElement(["type": .string("photo"), "ox": .number(80), "oy": .number(25)])
    first.set("zoom", 1.5)
    let page = CoverElement(["type": .string("photo"), "page": .bool(true), "ox": .number(90)])
    project.elements = [first, page]
    XCTAssertTrue(CoverEditing.alignPhotoContent(page.id, how: "c", in: &project))
    XCTAssertEqual(project.elements[0].number("ox"), 0)
    XCTAssertEqual(project.elements[0].number("oy"), 25)
    XCTAssertEqual(project.elements[1], page)
  }
  override class func setUp() { CoverTypography.registerBundledFonts() }
  func testCatalogPreservesEveryTemplateThemeAndFontOption() {
    let catalog = CoverCatalog.shared
    XCTAssertEqual(catalog.templates.count, 50)
    XCTAssertEqual(Set(catalog.templates.map(\.id)).count, 50)
    XCTAssertEqual(catalog.themes.count, 22)
    XCTAssertEqual(catalog.fonts.count, 19)
    XCTAssertEqual(catalog.titleFonts.count, 8)
    XCTAssertEqual(
      Set(catalog.templates.flatMap(\.elements).compactMap { $0["type"]?.string }),
      ["photo", "text", "rect", "ellipse", "arc", "path", "icon"])
  }
  func testProjectRoundTripIncludesWordsPhotoHistoryAndFontData() throws {
    var p = CoverProject()
    p.words["line1"] = "한글 제목 저장"
    p.themeID = "mint"
    p.mainPhoto.push("first")
    p.mainPhoto.push("second")
    _ = p.mainPhoto.step(-1)
    p.images["first"] = Data([1, 2, 3])
    p.fonts = [
      UserFontAsset(id: "font", name: "사용자", postScriptName: "Test", data: Data([4, 5, 6]))
    ]
    XCTAssertEqual(try CoverProject.decode(p.encoded()), p)
  }
  func testFutureDocumentVersionIsRejected() throws {
    var p = CoverProject()
    p.version = 999
    XCTAssertThrowsError(try CoverProject.decode(p.encoded()))
  }
  func testEveryFontOptionUsesItsBundledFamily() {
    let project = CoverProject()
    func normalized(_ family: String) -> String {
      family.lowercased().filter { $0.isLetter || $0.isNumber }
    }
    for option in CoverCatalog.shared.fonts {
      let element = CoverElement(["type": .string("text"), "ff": .string(option.id)])
      let font = CoverTypography.font(element, project: project, size: 42)
      XCTAssertEqual(
        normalized(CTFontCopyFamilyName(font) as String),
        normalized(option.id == "pen" ? "Nanum Pen" : option.family), option.id)
    }
    for option in CoverCatalog.shared.titleFonts {
      var p = project
      p.titleFontID = option.id
      let font = CoverTypography.font(CoverElement(["type": .string("text")]), project: p, size: 42)
      XCTAssertEqual(
        normalized(CTFontCopyFamilyName(font) as String),
        normalized(option.id == "pen" ? "Nanum Pen" : option.family), option.id)
    }
  }
  func testPhotoHistoryTruncatesForwardBranch() {
    var h = PhotoHistory()
    h.push("a")
    h.push("b")
    h.push("c")
    XCTAssertTrue(h.step(-1))
    h.push("d")
    XCTAssertEqual(h.items, ["a", "b", "d"])
    XCTAssertFalse(h.step(1))
    XCTAssertEqual(h.current, "d")
  }
  func testDuplicationBreaksTextBindingAndCreatesIndependentGroup() {
    var p = CoverProject()
    let selected = Array(p.elements.filter { $0.type == "text" }.prefix(2))
    let ids = Set(selected.map(\.id))
    CoverEditing.group(ids, in: &p)
    let originalGroup = p.elements.first { $0.id == selected[0].id }!.group
    let copies = CoverEditing.duplicate(ids, in: &p)
    let copied = p.elements.filter { copies.contains($0.id) }
    XCTAssertEqual(copied.count, 2)
    XCTAssertEqual(Set(copied.compactMap(\.group)).count, 1)
    XCTAssertNotEqual(copied[0].group, originalGroup)
    XCTAssertTrue(copied.allSatisfy { $0.string("bind").isEmpty })
    XCTAssertEqual(copied[0].string("text"), p.text(for: selected[0]))
  }
  func testGroupAlignmentPreservesRelativeOffsets() {
    var p = CoverProject()
    p.elements = [rect(20, 40, 80, 50), rect(140, 80, 60, 70)]
    let ids = Set(p.elements.map(\.id))
    CoverEditing.group(ids, in: &p)
    XCTAssertTrue(CoverEditing.align(ids, how: "c", in: &p))
    XCTAssertEqual(p.elements[1].x - p.elements[0].x, 120)
    XCTAssertEqual(CoverEditing.bounds(p.elements, project: p).midX, 540, accuracy: 0.1)
  }
  func testDistributionAccountsForDifferentElementWidths() {
    var p = CoverProject()
    p.elements = [rect(0, 0, 100, 50), rect(170, 0, 200, 50), rect(500, 0, 50, 50)]
    XCTAssertTrue(CoverEditing.align(Set(p.elements.map(\.id)), how: "dh", in: &p))
    XCTAssertEqual(
      p.elements[1].x - p.elements[0].rect.maxX, p.elements[2].x - p.elements[1].rect.maxX,
      accuracy: 0.1)
  }
  func testLayerReorderingPreservesRelativeSelectionOrder() {
    var p = CoverProject()
    p.elements = [rect(0, 0, 10, 10), rect(0, 0, 20, 20), rect(0, 0, 30, 30), rect(0, 0, 40, 40)]
    let original = p.elements.map(\.id)
    CoverEditing.move([original[0], original[2]], direction: "front", in: &p)
    XCTAssertEqual(p.elements.map(\.id), [original[1], original[3], original[0], original[2]])
  }
  func testEveryTemplateRendersAndTextFits() throws {
    let renderer = CoverRenderer()
    var p = CoverProject()
    for template in CoverCatalog.shared.templates {
      p.applyTemplate(template.id)
      let image = try XCTUnwrap(renderer.image(project: p, size: 128), template.id)
      XCTAssertEqual(image.width, 128)
      for e in p.elements where e.type == "text" {
        let l = CoverTypography.layout(e, project: p)
        XCTAssertTrue(l.height.isFinite)
        XCTAssertGreaterThan(l.size, 0)
      }
    }
  }
  func testPNGExportSizeAndTransparentForeground() throws {
    let renderer = CoverRenderer()
    var p = CoverProject()
    p.elements = [rect(100, 100, 30, 30)]
    let data = try renderer.png(project: p, mode: .foreground)
    let image = try XCTUnwrap(ImageAssets.image(data))
    XCTAssertEqual(image.width, 1080)
    XCTAssertEqual(image.height, 1080)
    let bytes = try XCTUnwrap(image.dataProvider?.data) as Data
    XCTAssertTrue(bytes.allSatisfy { $0 == 0 })
  }
  func testBasePhotoReplacementUpdatesAllSharedFrames() throws {
    var p = CoverProject()
    p.applyTemplate("strips")
    let image = try XCTUnwrap(CoverRenderer().image(project: CoverProject(), size: 32))
    let data = try ImageAssets.png(image)
    try CoverEditing.replacePhoto(
      data, elementID: p.elements.first { $0.type == "photo" }!.id, in: &p)
    XCTAssertEqual(p.mainPhoto.items.count, 1)
    XCTAssertEqual(
      Set(p.elements.filter { $0.type == "photo" }.compactMap { p.imageID(for: $0) }).count, 1)
  }
  func testWebFontFormats() throws {
    for ext in ["woff", "woff2"] {
      let url = try XCTUnwrap(
        Bundle.module.url(forResource: "GreatVibes", withExtension: ext, subdirectory: "Fixtures"))
      let asset = try CoverTypography.importFont(Data(contentsOf: url), name: "호환성 검증")
      XCTAssertFalse(asset.postScriptName.isEmpty)
      var project = CoverProject()
      project.fonts = [asset]
      let element = CoverElement(["type": .string("text"), "ff": .string(asset.id)])
      let font = CoverTypography.font(element, project: project, size: 48)
      XCTAssertEqual(CTFontCopyPostScriptName(font) as String, asset.postScriptName)
    }
  }
  func testUploadedFontBoldAndDocumentRestorePreserveRendering() throws {
    let url = try XCTUnwrap(
      Bundle.module.url(
        forResource: "GreatVibes",
        withExtension: "woff2", subdirectory: "Fixtures"))
    var asset = try CoverTypography.importFont(Data(contentsOf: url), name: "나만의 폰트")
    // Loading must use the embedded font, even if a saved display identifier is unavailable.
    asset.postScriptName = "Unavailable-Saved-Identifier"
    var project = CoverProject()
    project.fonts = [asset]
    let element = CoverElement([
      "type": .string("text"), "ff": .string(asset.id),
      "text": .string("Seolin Cover"), "x": .number(60), "y": .number(100),
      "w": .number(950), "size": .number(110), "baseSize": .number(110),
      "color": .string("#000000"), "fit": .bool(false),
    ])
    project.elements = [element]
    XCTAssertEqual(
      CTFontCopyPostScriptName(CoverTypography.font(element, project: project, size: 48))
        as String, "GreatVibes-Regular")
    let renderer = CoverRenderer()
    let normal = try renderer.png(project: project, mode: .all)
    project.elements[0].set("fw", "900")
    let bold = try renderer.png(project: project, mode: .all)
    XCTAssertNotEqual(normal, bold)
    let restored = try CoverProject.decode(project.encoded())
    XCTAssertEqual(try renderer.png(project: restored, mode: .all), bold)
    project.elements[0].set("fw", "400")
    XCTAssertEqual(try renderer.png(project: project, mode: .all), normal)
  }
  func testMalformedDocumentsRejectUnsafeGeometryHistoryAndDuplicateIDs() throws {
    var p = CoverProject()
    p.elements[0].w = 1e100
    XCTAssertThrowsError(try CoverProject.decode(p.encoded()))
    p = CoverProject()
    p.elements.append(p.elements[0])
    XCTAssertThrowsError(try CoverProject.decode(p.encoded()))
    p = CoverProject()
    p.mainPhoto.index = Int.min
    XCTAssertThrowsError(try CoverProject.decode(p.encoded()))
    p = CoverProject()
    p.elements[0].set("blur", 1e100)
    XCTAssertThrowsError(try CoverProject.decode(p.encoded()))
    p = CoverProject()
    p.dim = 1e100
    XCTAssertThrowsError(try CoverProject.decode(p.encoded()))
  }
  func testCorruptHistoryCursorAndOverflowDoNotTrap() {
    var history = PhotoHistory()
    history.index = Int.min
    history.push("first")
    XCTAssertEqual(history.current, "first")
    history.index = Int.max
    XCTAssertFalse(history.step(1))
    history.push("second")
    XCTAssertEqual(history.items, ["first", "second"])
  }
  func testReorderingOntoSelectedLayerKeepsItsOrder() {
    var p = CoverProject()
    let before = p.elements
    CoverEditing.reorder([before[1].id, before[2].id], before: before[1].id, in: &p)
    XCTAssertEqual(p.elements, before)
  }
  func testExtremeTextSizeIsBoundedBeforeFitting() {
    let element = CoverElement(["type": .string("text"), "text": .string("안전한 글씨"),
      "baseSize": .number(1e300), "w": .number(600), "h": .number(100)])
    let layout = CoverTypography.layout(element, project: CoverProject())
    XCTAssertTrue((8...400).contains(layout.size))
    XCTAssertTrue(layout.height.isFinite)
  }
  private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CoverElement {
    CoverElement([
      "type": .string("rect"), "x": .number(x), "y": .number(y), "w": .number(w), "h": .number(h),
      "fill": .string("#fff"),
    ])
  }
}
