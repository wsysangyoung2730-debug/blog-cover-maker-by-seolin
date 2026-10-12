import CoreText
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class EditorStore: ObservableObject {
  let document: CoverDocument
  @Published var project: CoverProject {
    didSet {
      document.project = project
      thumbnailTask?.cancel()
      thumbnailTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        self.refreshThumbnails()
      }
    }
  }
  @Published var selection: Set<UUID> = []
  @Published var primaryID: UUID?
  @Published var panMode = false
  @Published var multipleSelection = false
  @Published var editingID: UUID?
  @Published var editText = ""
  @Published var error: String?
  @Published var status = "사진을 넣거나 디자인을 선택하세요."
  @Published var marquee: CGRect?
  @Published var guideX = false
  @Published var guideY = false
  @Published var showQuick = false
  @Published var importKind: ImportKind?
  @Published var exportData: PNGDocument?
  @Published var exportName = "seolin_cover"
  @Published var isExporting = false
  @Published var thumbs: [String: CGImage] = [:]
  @Published var wordTarget = "line1"
  var undoManager: UndoManager?
  var fontImportTargets: Set<UUID>?
  let renderer = CoverRenderer()
  var interactionStart: CoverProject?
  private var thumbnailTask: Task<Void, Never>?
  private var originalEdit: CoverProject?
  private var lastPhoto: UUID?
  enum ImportKind: String, Identifiable {
    case base, replace, add, font
    var id: String { rawValue }
  }
  init(document: CoverDocument) {
    self.document = document
    project = document.project
  }
  var selected: [CoverElement] {
    project.elements.filter { selection.contains($0.id) && !$0.flag("hidden") }
  }
  var primary: CoverElement? { selected.first { $0.id == primaryID } ?? selected.last }
  var inspected: [CoverElement] {
    if !selected.isEmpty { return selected }
    if let photo = project.elements.first(where: { $0.id == lastPhoto && !$0.flag("hidden") }) {
      return [photo]
    }
    return project.elements.first(where: { $0.type == "photo" && !$0.flag("hidden") }).map { [$0] }
      ?? []
  }
  var photo: CoverElement? {
    inspected.count == 1 && inspected.first?.type == "photo" ? inspected.first : nil
  }
  var photoHistory: PhotoHistory {
    if let photo, let h = project.frameHistory[photo.id.uuidString] { return h }
    if let photo, let src = photo.values["src"]?.string {
      var h = PhotoHistory()
      h.push(src)
      return h
    }
    return project.mainPhoto
  }
  func change(_ name: String, _ body: (inout CoverProject) -> Void) {
    let before = project
    body(&project)
    if interactionStart == nil { register(before, name: name) }
  }
  private func register(_ before: CoverProject, name: String) {
    guard before != project else { return }
    undoManager?.registerUndo(withTarget: self) { target in target.restore(before, name: name) }
    undoManager?.setActionName(name)
  }
  private func restore(_ state: CoverProject, name: String) {
    let before = project
    project = state
    selection = selection.intersection(Set(state.elements.map(\.id)))
    register(before, name: name)
  }
  func begin() { if interactionStart == nil { interactionStart = project } }
  func end(_ name: String = "요소 편집") {
    if let before = interactionStart {
      interactionStart = nil
      register(before, name: name)
    }
  }
  func cancelInteraction() {
    if let before = interactionStart {
      interactionStart = nil
      project = before
    }
    marquee = nil
    guideX = false
    guideY = false
  }
  func select(_ id: UUID?, additive: Bool = false, individual: Bool = false) {
    guard let id, let e = project.elements.first(where: { $0.id == id }) else {
      selection = []
      primaryID = nil
      panMode = false
      showQuick = false
      return
    }
    let ids =
      individual || e.group == nil
      ? Set([id]) : Set(project.elements.filter { $0.group == e.group }.map(\.id))
    if additive {
      if selection.contains(id) { selection.subtract(ids) } else { selection.formUnion(ids) }
    } else {
      selection = ids
    }
    primaryID = id
    if e.type == "photo" { lastPhoto = id } else { panMode = false }
    if e.type == "text" && !e.string("bind").isEmpty { wordTarget = e.string("bind") }
  }
  func chooseTemplate(_ id: String) {
    finishText()
    change("디자인 변경") { $0.applyTemplate(id) }
    select(nil)
    status = "디자인을 바꿨어요."
  }
  func resetDesign() {
    change("디자인 초기화") {
      $0.dim = 55
      $0.applyTemplate($0.templateID)
    }
    select(nil)
  }
  func delete() {
    guard !selection.isEmpty else { return }
    let ids = selection
    change("삭제") { $0.elements.removeAll { ids.contains($0.id) } }
    select(nil)
  }
  func duplicate() {
    let ids = selection
    var copies = Set<UUID>()
    change("복제") { copies = CoverEditing.duplicate(ids, in: &$0) }
    selection = copies
    primaryID = copies.first
  }
  func group() {
    let ids = selection
    change("그룹 묶기") { CoverEditing.group(ids, in: &$0) }
  }
  func ungroup() {
    let ids = selection
    change("그룹 풀기") { CoverEditing.ungroup(ids, in: &$0) }
  }
  func align(_ how: String) {
    let ids = Set(inspected.map(\.id))
    change("위치 맞추기") { _ = CoverEditing.align(ids, how: how, in: &$0) }
  }
  func moveLayer(_ direction: String) {
    let ids = selection
    change("레이어 순서") { CoverEditing.move(ids, direction: direction, in: &$0) }
  }
  func selectAll() {
    selection = Set(
      project.elements.filter {
        $0.isPickable && !($0.type == "text" && project.text(for: $0).isEmpty)
      }.map(\.id))
  }
  func selectSame() {
    guard let type = primary?.type else { return }
    selection = Set(project.elements.filter { $0.isPickable && $0.type == type }.map(\.id))
  }
  func nudge(dx: Double, dy: Double) {
    let ids = selection
    change("위치 이동") { p in
      for i in p.elements.indices where ids.contains(p.elements[i].id) {
        p.elements[i].x += dx
        p.elements[i].y += dy
      }
    }
  }
  func setNumber(_ key: String, _ value: Double, ids: Set<UUID>? = nil) {
    let ids = ids ?? Set(inspected.map(\.id))
    change("속성 변경") { p in
      for i in p.elements.indices where ids.contains(p.elements[i].id) {
        p.elements[i].set(key, value)
        if key == "size" {
          p.elements[i].set("baseSize", value)
          p.elements[i].set("manualSize", true)
        }
        if key == "opacity" { p.elements[i].values.removeValue(forKey: "dim") }
      }
    }
  }
  func setString(_ key: String, _ value: String, ids: Set<UUID>? = nil) {
    let ids = ids ?? Set(selected.map(\.id))
    change("속성 변경") { p in
      for i in p.elements.indices where ids.contains(p.elements[i].id) {
        if value.isEmpty {
          p.elements[i].values.removeValue(forKey: key)
        } else {
          p.elements[i].set(key, value)
        }
        if key == "ff" { p.elements[i].values.removeValue(forKey: "manualSize") }
      }
    }
  }
  func setColor(_ token: String, ids: Set<UUID>? = nil) {
    let ids = ids ?? selection
    change("색 변경") { p in
      for i in p.elements.indices where ids.contains(p.elements[i].id) {
        if let key = p.elements[i].colorKey { p.elements[i].set(key, token) }
      }
    }
  }
  func toggle(_ key: String, ids: Set<UUID>) {
    let on = !project.elements.filter { ids.contains($0.id) }.allSatisfy { $0.flag(key) }
    change("글씨 꾸미기") { p in
      for i in p.elements.indices where ids.contains(p.elements[i].id) {
        p.elements[i].set(key, on)
      }
    }
  }
  func wordIDs(_ key: String) -> Set<UUID> {
    Set(
      project.elements.filter {
        $0.type == "text"
          && (key == "hl"
            ? $0.values["hl"]?.string != nil && !$0.string("bind").isEmpty
            : $0.string("bind") == key)
      }.map(\.id))
  }
  func startText(_ id: UUID) {
    guard let e = project.elements.first(where: { $0.id == id && $0.type == "text" }) else {
      return
    }
    select(id, individual: true)
    originalEdit = project
    editingID = id
    editText = project.text(for: e)
    showQuick = false
  }
  func updateText(_ text: String) {
    editText = text
    if let id = editingID { project.setText(text, elementID: id) }
  }
  func finishText(cancel: Bool = false) {
    guard let before = originalEdit else { return }
    if cancel { project = before } else { register(before, name: "글씨 수정") }
    editingID = nil
    originalEdit = nil
  }
  func photoStep(_ delta: Int) {
    let id = photo?.id
    change("사진 기록 변경") { CoverEditing.stepPhoto(delta, elementID: id, in: &$0) }
  }
  func resetPhoto() {
    guard let id = photo?.id else { return }
    change("사진 위치 초기화") { p in
      if let i = p.elements.firstIndex(where: { $0.id == id }) {
        CoverEditing.resetPhoto(&p.elements[i])
      }
    }
    panMode = false
  }
  func useMainPhoto() {
    guard let id = photo?.id else { return }
    change("기본 사진 사용") { p in
      if let i = p.elements.firstIndex(where: { $0.id == id }) {
        p.elements[i].values.removeValue(forKey: "src")
        p.frameHistory.removeValue(forKey: id.uuidString)
        CoverEditing.resetCrop(&p.elements[i])
      }
    }
  }
  func importFiles(_ urls: [URL], kind: ImportKind, at point: CGPoint? = nil, target: UUID? = nil) {
    let before = project
    do {
      for url in urls {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        switch kind {
        case .font:
          let font = try CoverTypography.importFont(
            data, name: url.deletingPathExtension().lastPathComponent)
          project.fonts.append(font)
          for i in project.elements.indices
          where (fontImportTargets ?? selection).contains(project.elements[i].id)
            && project.elements[i].type == "text"
          {
            project.elements[i].set("ff", font.id)
          }
        case .add:
          let id = try CoverEditing.addPhoto(data, at: point, in: &project)
          select(id)
        case .base: try CoverEditing.replacePhoto(data, elementID: nil, in: &project)
        case .replace:
          try CoverEditing.replacePhoto(data, elementID: target ?? photo?.id, in: &project)
        }
      }
      register(before, name: kind == .font ? "폰트 추가" : "사진 불러오기")
      status = "불러왔어요."
      fontImportTargets = nil
    } catch {
      project = before
      self.error = error.localizedDescription
    }
  }
  func export(_ mode: ExportMode) {
    finishText()
    do {
      exportData = PNGDocument(data: try renderer.png(project: project, mode: mode))
      let formatter = DateFormatter()
      formatter.dateFormat = "MMdd"
      exportName =
        "seolin_cover_\(project.templateID)_\(formatter.string(from:Date()))\(mode == .all ? "" : mode == .background ? "_bg" : "_text")"
      isExporting = true
    } catch { self.error = error.localizedDescription }
  }
  func refreshThumbnails() {
    var p = project
    var images: [String: CGImage] = [:]
    for template in CoverCatalog.shared.templates {
      p.applyTemplate(template.id)
      images[template.id] = renderer.image(project: p, size: 180)
    }
    thumbs = images
  }
}
