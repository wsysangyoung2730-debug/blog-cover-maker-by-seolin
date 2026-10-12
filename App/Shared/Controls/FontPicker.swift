import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct FontPicker: View {
  @ObservedObject var store: EditorStore
  var ids: Set<UUID>
  var body: some View {
    Picker(
      "글씨체",
      selection: Binding(
        get: { store.project.elements.first { ids.contains($0.id) }?.string("ff") ?? "" },
        set: { value in
          if value == "__add" {
            store.fontImportTargets = ids
            store.importKind = .font
          } else {
            store.setString("ff", value, ids: ids)
          }
        })
    ) {
      Text("디자인 기본 글씨체").tag("")
      ForEach(CoverCatalog.shared.fonts) { font in Text(font.label).tag(font.id) }
      ForEach(store.project.fonts) { font in Text(font.name + " (추가함)").tag(font.id) }
      Divider()
      Text("폰트 파일 추가…").tag("__add")
    }
  }
}
