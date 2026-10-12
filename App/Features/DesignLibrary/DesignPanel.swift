import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct DesignPanel: View {
  @ObservedObject var store: EditorStore
  @ObservedObject var workspace = WorkspaceSettings.shared
  @State private var category = "all"
  @State private var search = ""
  private var filtered: [CoverTemplate] {
    CoverCatalog.shared.templates.filter { t in
      (category == "all" || category == "favorites" && workspace.favorites.contains(t.id)
        || t.category == category)
        && (search.isEmpty || t.name.localizedCaseInsensitiveContains(search))
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("디자인 검색", text: $search).textFieldStyle(.roundedBorder)
      Picker("분류", selection: $category) {
        Text("전체 50종").tag("all")
        Text("즐겨찾기").tag("favorites")
        Text("사진 가득").tag("photo")
        Text("액자·카드").tag("frame")
        Text("화면 나누기").tag("split")
      }
      HStack {
        Image(systemName: "square.grid.3x3")
        Slider(value: $workspace.thumbnailSize, in: 70...260)
        Image(systemName: "square.grid.2x2")
      }.help("디자인 미리보기 크기").onTapGesture(count: 2) { workspace.thumbnailSize = 116 }
      Divider()
      Text("테마 · \(store.project.theme.name)").font(.subheadline.bold())
      themeGrid(rainbow: false)
      Text("무지개 테마").font(.caption).foregroundStyle(.secondary)
      themeGrid(rainbow: true)
      Text("테마 밝기 \(Int(100-store.project.dim))").font(.caption)
      Slider(
        value: Binding(
          get: { 100 - store.project.dim },
          set: { value in store.change("밝기 변경") { $0.dim = 100 - value } }), in: 0...100,
        onEditingChanged: { editing in editing ? store.begin() : store.end("밝기 변경") })
      Button("디자인 처음 상태로", systemImage: "arrow.counterclockwise") { store.resetDesign() }.frame(
        maxWidth: .infinity)
      Divider()
      LazyVGrid(columns: [GridItem(.adaptive(minimum: workspace.thumbnailSize))], spacing: 12) {
        ForEach(filtered) { template in
          VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
              Group {
                if let image = store.thumbs[template.id] {
                  Image(decorative: image, scale: 1).resizable()
                } else {
                  Rectangle().fill(.quaternary)
                }
              }.aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
              Button {
                if workspace.favorites.contains(template.id) {
                  workspace.favorites.remove(template.id)
                } else {
                  workspace.favorites.insert(template.id)
                }
              } label: {
                Image(systemName: workspace.favorites.contains(template.id) ? "star.fill" : "star")
                  .foregroundStyle(workspace.favorites.contains(template.id) ? .yellow : .white)
                  .padding(6).background(.black.opacity(0.45), in: Circle())
              }.buttonStyle(.plain).help("즐겨찾기")
            }
            Text(
              String(
                format: "%02d",
                (CoverCatalog.shared.templates.firstIndex { $0.id == template.id } ?? 0) + 1) + "  "
                + template.name
            ).font(.caption).lineLimit(1)
          }.padding(5).background(
            store.project.templateID == template.id ? Color.accentColor.opacity(0.14) : .clear,
            in: RoundedRectangle(cornerRadius: 11)
          ).overlay {
            RoundedRectangle(cornerRadius: 11).stroke(
              store.project.templateID == template.id ? Color.accentColor : .clear, lineWidth: 2)
          }.contentShape(Rectangle()).onTapGesture { store.chooseTemplate(template.id) }
            .accessibilityLabel(template.name)
        }
      }
      if filtered.isEmpty {
        Text("디자인의 별을 눌러 즐겨찾기에 추가하세요.").font(.caption).foregroundStyle(.secondary)
      }

    }
  }
  private func themeGrid(rainbow: Bool) -> some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 7) {
      ForEach(CoverCatalog.shared.themes.filter { ($0.rb != nil) == rainbow }) { theme in
        Button {
          store.change("테마 변경") { $0.themeID = theme.id }
        } label: {
          Circle().fill(
            LinearGradient(
              colors: [
                Color(cgColor: CoverRenderer.color(theme.main, project: store.project)),
                Color(cgColor: CoverRenderer.color(theme.accent, project: store.project)),
              ], startPoint: .topLeading, endPoint: .bottomTrailing)
          ).frame(width: 25, height: 25).padding(3).overlay {
            Circle().stroke(
              store.project.themeID == theme.id ? Color.accentColor : .clear, lineWidth: 2)
          }
        }.buttonStyle(.plain).help(theme.name).accessibilityLabel(theme.name)
      }
    }
  }
}
