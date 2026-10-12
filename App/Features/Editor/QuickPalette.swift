import SwiftUI

struct QuickPalette: View {
  @ObservedObject var store: EditorStore
  @State private var collapsed = false
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(
          store.selected.count == 1 ? store.primary?.name ?? "빠른 편집" : "\(store.selected.count)개 선택"
        ).font(.headline)
        Spacer()
        Button {
          collapsed.toggle()
        } label: {
          Image(systemName: collapsed ? "chevron.down" : "chevron.up")
        }
        Button {
          store.showQuick = false
        } label: {
          Image(systemName: "xmark")
        }
      }.buttonStyle(.plain)
      if !collapsed {
        let ids = Set(store.selected.filter { $0.type == "text" }.map(\.id))
        if !ids.isEmpty {
          TextStyleControls(store: store, ids: ids)
          FontPicker(store: store, ids: ids)
        }
        if let e = store.selected.first(where: { $0.colorKey != nil }) {
          SwatchPicker(store: store, token: e.string(e.colorKey!, "#fff")) { store.setColor($0) }
        }
        HStack {
          Button("그룹 묶기") { store.group() }.disabled(store.selected.count < 2)
          Button("그룹 풀기") { store.ungroup() }.disabled(!store.selected.contains { $0.group != nil })
        }
      }
    }.padding(14).frame(minWidth: 240, idealWidth: 280, maxWidth: 420).fixedSize(
      horizontal: false, vertical: true)
  }
}
