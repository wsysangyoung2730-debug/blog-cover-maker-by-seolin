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
  private struct Snapshot: Codable {
    var favorites: Set<String>
    var collapsed: Set<String>
    var columns: [[String]]
    var thumbnailSize: Double
    var leftWidth: Double
    var rightWidth: Double
  }
  init() {
    let state = UserDefaults.standard.data(forKey: "workspace.v1").flatMap {
      try? JSONDecoder().decode(Snapshot.self, from: $0)
    }
    favorites = state?.favorites ?? []
    collapsed = state?.collapsed ?? []
    columns = state?.columns ?? [["design"], [], ["properties", "words", "layers"]]
    thumbnailSize = state?.thumbnailSize ?? 116
    leftWidth = state?.leftWidth ?? 280
    rightWidth = state?.rightWidth ?? 320
  }
  private func save() {
    let s = Snapshot(
      favorites: favorites, collapsed: collapsed, columns: columns, thumbnailSize: thumbnailSize,
      leftWidth: leftWidth, rightWidth: rightWidth)
    if let data = try? JSONEncoder().encode(s) {
      UserDefaults.standard.set(data, forKey: "workspace.v1")
    }
  }
  func reset() {
    collapsed = []
    columns = [["design"], [], ["properties", "words", "layers"]]
    leftWidth = 280
    rightWidth = 320
  }
  func movePanel(_ id: String, to column: Int, before target: String? = nil) {
    guard id != target else { return }
    for i in columns.indices { columns[i].removeAll { $0 == id } }
    let index = target.flatMap { columns[column].firstIndex(of: $0) } ?? columns[column].count
    columns[column].insert(id, at: index)
  }
}
