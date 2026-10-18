import SwiftUI

@MainActor final class WorkspaceSettings: ObservableObject {
  static let shared = WorkspaceSettings()
  @Published var favorites: Set<String> { didSet { save() } }
  @Published var collapsed: Set<String> { didSet { save() } }
  @Published var columns: [[String]] { didSet { save() } }
  @Published var thumbnailSize: Double { didSet { save() } }
  @Published var leftWidth: Double { didSet { save() } }
  @Published var rightWidth: Double { didSet { save() } }
  @Published var draggingPanel: String?
  private let defaults: UserDefaults
  private struct Snapshot: Codable {
    var favorites: Set<String>
    var collapsed: Set<String>
    var columns: [[String]]
    var thumbnailSize: Double
    var leftWidth: Double
    var rightWidth: Double
  }
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let state = defaults.data(forKey: "workspace.v1").flatMap {
      try? JSONDecoder().decode(Snapshot.self, from: $0)
    }
    let panels: Set<String> = ["design", "properties", "words", "layers"]
    favorites = (state?.favorites ?? []).intersection(Set(CoverCatalog.shared.templates.map(\.id)))
    collapsed = (state?.collapsed ?? []).intersection(panels)
    let savedColumns = state?.columns ?? []
    let flattened = savedColumns.flatMap { $0 }
    columns = savedColumns.count == 3 && flattened.count == 4 && Set(flattened) == panels
      ? savedColumns : [["design"], [], ["properties", "words", "layers"]]
    thumbnailSize = min(260, max(70, state?.thumbnailSize ?? 116))
    leftWidth = min(480, max(220, state?.leftWidth ?? 280))
    rightWidth = min(500, max(260, state?.rightWidth ?? 320))
  }
  private func save() {
    let s = Snapshot(
      favorites: favorites, collapsed: collapsed, columns: columns, thumbnailSize: thumbnailSize,
      leftWidth: leftWidth, rightWidth: rightWidth)
    if let data = try? JSONEncoder().encode(s) {
      defaults.set(data, forKey: "workspace.v1")
    }
  }
  func reset() {
    collapsed = []
    columns = [["design"], [], ["properties", "words", "layers"]]
    leftWidth = 280
    rightWidth = 320
  }
  func movePanel(_ id: String, to column: Int, before target: String? = nil) {
    guard ["design", "properties", "words", "layers"].contains(id),
      columns.indices.contains(column), id != target else { return }
    for i in columns.indices { columns[i].removeAll { $0 == id } }
    let index = target.flatMap { columns[column].firstIndex(of: $0) } ?? columns[column].count
    columns[column].insert(id, at: index)
  }
}
