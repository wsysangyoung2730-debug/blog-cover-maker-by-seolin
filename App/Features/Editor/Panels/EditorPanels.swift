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

struct SwatchPicker: View {
  @ObservedObject var store: EditorStore
  var token: String
  var change: (String) -> Void
  private let tokens = [
    "$main", "$accent", "$dark", "$ink", "$paper", "#ffffff", "#000000", "#E5262A", "#F27A1A",
    "#F5C400", "#22A447", "#1E7BFF", "#3340B5", "#8A3FD1",
  ]
  var body: some View {
    VStack(alignment: .leading) {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
        ForEach(tokens, id: \.self) { value in
          Button {
            change(value)
          } label: {
            Circle().fill(Color(cgColor: CoverRenderer.color(value, project: store.project))).frame(
              width: 24, height: 24
            ).overlay { Circle().stroke(.gray.opacity(0.3), lineWidth: 1) }.padding(2).overlay {
              Circle().stroke(token == value ? Color.accentColor : .clear, lineWidth: 2)
            }
          }.buttonStyle(.plain).accessibilityLabel(value)
        }
      }
      ColorPicker(
        "직접 색 고르기",
        selection: Binding(
          get: { Color(cgColor: CoverRenderer.color(token, project: store.project)) },
          set: { color in
            if let cg = color.cgColor?.converted(
              to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let components = cg.components, components.count >= 3
            {
              change(
                String(
                  format: "#%02X%02X%02X", Int(components[0] * 255), Int(components[1] * 255),
                  Int(components[2] * 255)))
            }
          }), supportsOpacity: false)
    }
  }
}
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
struct NumberControl: View {
  var title: String
  var value: Binding<Double>
  var range: ClosedRange<Double>
  var unit: String = ""
  var editing: (Bool) -> Void = { _ in }
  var body: some View {
    VStack(spacing: 5) {
      HStack {
        Text(title)
        Spacer()
        TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
          .multilineTextAlignment(.trailing).frame(width: 58).textFieldStyle(.roundedBorder)
        Text(unit).foregroundStyle(.secondary)
      }.font(.caption)
      Slider(value: value, in: range, onEditingChanged: editing)
    }
  }
}
struct WordsPanel: View {
  @ObservedObject var store: EditorStore
  private let fields = [
    ("line1", "제목 첫 줄"), ("line2", "제목 둘째 줄"), ("hl", "강조할 단어"), ("tag", "태그"), ("sub", "부제목"),
    ("en", "영문 장식 글자"), ("handle", "인스타 계정"),
  ]
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(fields, id: \.0) { key, name in
        let enabled = !store.wordIDs(key).isEmpty
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button {
              store.wordTarget = key
            } label: {
              Circle().fill(
                Color(
                  cgColor: CoverRenderer.color(
                    store.project.elements.first { store.wordIDs(key).contains($0.id) }?.string(
                      key == "hl" ? "hl" : "color", "#fff"), project: store.project))
              ).frame(width: 15, height: 15).overlay { Circle().stroke(.gray.opacity(0.4)) }
            }.buttonStyle(.plain).help(name + " 꾸미기").disabled(!enabled)
          }
          TextField(
            enabled ? name : "이 디자인에는 없어요",
            text: Binding(
              get: { enabled ? store.project.words[key, default: ""] : "" },
              set: { v in
                store.wordTarget = key
                store.change("문구 수정") { p in
                  p.words[key] = v
                  for i in p.elements.indices where p.elements[i].string("bind") == key {
                    p.elements[i].values.removeValue(forKey: "manualSize")
                  }
                }
              }), axis: .vertical
          ).textFieldStyle(.roundedBorder).disabled(!enabled)
        }
      }
      Divider()
      Text("글씨 꾸미기 · \(fields.first{$0.0==store.wordTarget}?.1 ?? "브랜드")").font(.subheadline.bold())
      let ids = store.wordIDs(store.wordTarget)
      if !ids.isEmpty {
        if store.wordTarget != "hl" {
          TextStyleControls(store: store, ids: ids)
          FontPicker(store: store, ids: ids)
        }
        SwatchPicker(
          store: store,
          token: store.project.elements.first { ids.contains($0.id) }?.string(
            store.wordTarget == "hl" ? "hl" : "color", "#fff") ?? "#fff"
        ) { color in
          if store.wordTarget == "hl" {
            store.setString("hl", color, ids: ids)
          } else {
            store.setColor(color, ids: ids)
          }
        }
      }
      Divider()
      Picker(
        "제목 글씨체",
        selection: Binding(
          get: { store.project.titleFontID },
          set: { value in
            store.change("제목 글씨체") { p in
              p.titleFontID = value
              for i in p.elements.indices {
                p.elements[i].values.removeValue(forKey: "ff")
                p.elements[i].values.removeValue(forKey: "manualSize")
              }
            }
          })
      ) { ForEach(CoverCatalog.shared.titleFonts) { font in Text(font.label).tag(font.id) } }
      Button("폰트 파일 추가", systemImage: "textformat") { store.importKind = .font }
      Text("추가한 폰트는 프로젝트에 함께 저장됩니다.").font(.caption).foregroundStyle(.secondary)
    }
  }
}
struct TextStyleControls: View {
  @ObservedObject var store: EditorStore
  var ids: Set<UUID>
  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 6) {
        Button("굵게") {
          let elements = store.project.elements.filter { ids.contains($0.id) }
          let bold = !elements.allSatisfy {
            if let override = Double($0.string("fw")) { return override >= 600 }
            return CTFontGetSymbolicTraits(
              CoverTypography.font($0, project: store.project, size: 20)
            )
            .contains(.traitBold)
          }
          store.setString("fw", bold ? "900" : "400", ids: ids)
        }
        ForEach([("it", "기울임"), ("ul", "밑줄"), ("st", "취소선")], id: \.0) { key, label in
          Button(label) { store.toggle(key, ids: ids) }
        }
      }.font(.caption).buttonStyle(.bordered)
      HStack {
        Button("그림자") { store.toggle("shadow", ids: ids) }
        Spacer()
        Button("가−") { size(-4) }
        Button("가+") { size(4) }
      }
      Picker(
        "글씨 정렬",
        selection: Binding(
          get: {
            store.project.elements.first { ids.contains($0.id) }?.string("align", "left") ?? "left"
          }, set: { store.setString("align", $0, ids: ids) })
      ) {
        Text("왼쪽").tag("left")
        Text("가운데").tag("center")
        Text("오른쪽").tag("right")
      }.pickerStyle(.segmented)
    }
  }
  private func size(_ delta: Double) {
    store.change("글씨 크기") { p in
      for i in p.elements.indices where ids.contains(p.elements[i].id) {
        let value = max(8, min(400, CoverTypography.layout(p.elements[i], project: p).size + delta))
        p.elements[i].set("size", value)
        p.elements[i].set("baseSize", value)
        p.elements[i].set("manualSize", true)
      }
    }
  }
}
struct PropertiesPanel: View {
  @ObservedObject var store: EditorStore
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let element = store.inspected.first {
        Text(store.inspected.count > 1 ? "\(store.inspected.count)개 선택" : element.name).font(
          .subheadline.bold())
        if store.selected.isEmpty {
          Text("마지막 사진 설정 · 요소를 선택하면 바뀝니다.").font(.caption).foregroundStyle(.secondary)
        }
        if let photo = store.photo {
          HStack {
            Button("사진 교체") { store.importKind = .replace }
            Button("사진·로고 추가") { store.importKind = .add }
          }
          HStack {
            Button(store.panMode ? "위치 맞추기 완료" : "위치 맞추기") {
              store.select(photo.id, individual: true)
              store.panMode.toggle()
            }
            Button("처음 위치로") { store.resetPhoto() }
          }
          if photo.values["src"]?.string != nil { Button("기본 사진으로 되돌리기") { store.useMainPhoto() } }
          let history = store.photoHistory
          if history.items.count > 1 {
            HStack {
              Button {
                store.photoStep(-1)
              } label: {
                Image(systemName: "chevron.left")
              }.disabled(history.index <= 0)
              Text("\(history.index+1) / \(history.items.count)").monospacedDigit()
              Button {
                store.photoStep(1)
              } label: {
                Image(systemName: "chevron.right")
              }.disabled(history.index >= history.items.count - 1)
              Spacer()
              Text("사진 기록").font(.caption).foregroundStyle(.secondary)
            }
          }
          numeric("사진 확대", "zoom", 20...300, multiplier: 100, unit: "%")
        }
        let textIDs = Set(store.inspected.filter { $0.type == "text" }.map(\.id))
        if !textIDs.isEmpty {
          if store.inspected.count == 1 {
            Button("표지에서 글씨 고치기") { store.startText(element.id) }
            numeric("글씨 크기", "size", 8...400)
          }
          FontPicker(store: store, ids: textIDs)
          TextStyleControls(store: store, ids: textIDs)
        }
        if store.inspected.contains(where: { $0.colorKey != nil }) {
          SwatchPicker(
            store: store, token: element.colorKey.map { element.string($0, "#fff") } ?? "#fff"
          ) { store.setColor($0, ids: Set(store.inspected.map(\.id))) }
        }
        numeric("투명도", "opacity", 0...100, multiplier: 100, unit: "%")
        if store.inspected.count == 1 {
          numeric("흐리게", "blur", 0...60)
          numeric("회전", "rot", -180...180, unit: "°")
        }
        Divider()
        Text("위치 맞추기").font(.caption.bold())
        AlignmentControls(store: store)
        if !store.selection.isEmpty {
          HStack {
            Button("복제") { store.duplicate() }
            Button("삭제", role: .destructive) { store.delete() }
            Spacer()
            Button("빠른 편집") { store.showQuick = true }
          }
          HStack {
            Button("그룹 묶기") { store.group() }.disabled(store.selected.count < 2)
            Button("그룹 풀기") { store.ungroup() }.disabled(
              !store.selected.contains { $0.group != nil })
          }
          Button("같은 종류 선택") { store.selectSame() }
        }
      } else {
        Text("사진을 넣거나 표지의 요소를 선택하세요.").foregroundStyle(.secondary)
        Button("사진·로고 추가") { store.importKind = .add }
      }
    }.buttonStyle(.bordered)
  }
  private func numeric(
    _ title: String, _ key: String, _ range: ClosedRange<Double>, multiplier: Double = 1,
    unit: String = ""
  ) -> some View {
    NumberControl(
      title: title,
      value: Binding(
        get: {
          guard let e = store.inspected.first else { return range.lowerBound }
          if key == "opacity" { return store.project.opacity(for: e) * multiplier }
          if key == "size" { return CoverTypography.layout(e, project: store.project).size }
          return e.number(key, key == "zoom" ? 1 : 0) * multiplier
        },
        set: { store.setNumber(key, max(range.lowerBound, min(range.upperBound, $0)) / multiplier) }
      ), range: range, unit: unit,
      editing: { editing in editing ? store.begin() : store.end("속성 변경") })
  }
}
struct AlignmentControls: View {
  @ObservedObject var store: EditorStore
  private let items = [
    ("l", "왼쪽", "align.horizontal.left"), ("c", "가로 가운데", "align.horizontal.center"),
    ("r", "오른쪽", "align.horizontal.right"), ("t", "위", "align.vertical.top"),
    ("m", "세로 가운데", "align.vertical.center"), ("b", "아래", "align.vertical.bottom"),
  ]
  var body: some View {
    VStack {
      HStack {
        ForEach(items, id: \.0) { key, title, icon in
          Button {
            store.align(key)
          } label: {
            Image(systemName: icon).frame(maxWidth: .infinity)
          }.help(title).accessibilityLabel(title)
        }
      }
      if CoverEditing.units(store.inspected).count >= 3 {
        HStack {
          Button("가로 간격 고르게") { store.align("dh") }
          Button("세로 간격 고르게") { store.align("dv") }
        }
      }
    }
  }
}
struct LayersPanel: View {
  @ObservedObject var store: EditorStore
  @State private var editing: UUID?
  @State private var text = ""
  @State private var original: CoverProject?
  var body: some View {
    VStack(spacing: 8) {
      HStack {
        ForEach([("front", "맨 위"), ("up", "위"), ("down", "아래"), ("back", "맨 아래")], id: \.0) {
          key, title in Button(title) { store.moveLayer(key) }.disabled(store.selection.isEmpty)
        }
      }.buttonStyle(.bordered).font(.caption)
      ForEach(store.project.elements.reversed()) { element in
        HStack(spacing: 6) {
          Button {
            store.change("레이어 표시") { p in
              if let i = p.elements.firstIndex(where: { $0.id == element.id }) {
                p.elements[i].set("hidden", !element.flag("hidden"))
              }
            }
          } label: {
            Image(systemName: element.flag("hidden") ? "eye.slash" : "eye")
          }.buttonStyle(.plain).help("보이기·숨기기")
          if editing == element.id {
            TextField("레이어 편집", text: $text, axis: .vertical).textFieldStyle(.roundedBorder)
              .onChange(of: text) { _, value in
                if element.type == "text" { store.project.setText(value, elementID: element.id) }
              }.onSubmit { finish(element, cancel: false) }.cancelOnEscape {
                finish(element, cancel: true)
              }
            Button {
              finish(element, cancel: false)
            } label: {
              Image(systemName: "checkmark")
            }.buttonStyle(.plain)
            Button {
              finish(element, cancel: true)
            } label: {
              Image(systemName: "xmark")
            }.buttonStyle(.plain)
          } else {
            VStack(alignment: .leading, spacing: 2) {
              Text((element.group != nil ? "▦ " : "") + element.name).lineLimit(1)
              if element.type == "text" {
                Text(store.project.text(for: element)).font(.caption2).foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              if element.type == "photo" && element.values["src"]?.string == nil {
                Text("기본 사진").font(.system(size: 9, weight: .bold)).padding(.horizontal, 5)
                  .background(.yellow.opacity(0.3), in: Capsule())
              }
            }
            Spacer(minLength: 0)
          }
        }.padding(8).background(
          store.selection.contains(element.id) ? Color.accentColor.opacity(0.15) : .clear,
          in: RoundedRectangle(cornerRadius: 7)
        ).opacity(element.flag("hidden") ? 0.5 : 1).contentShape(Rectangle())
          .onTapGesture(count: 2) { start(element) }.onTapGesture {
            #if os(macOS)
              let add = !NSEvent.modifierFlags.intersection([.command, .shift, .control]).isEmpty
            #else
              let add = store.multipleSelection
            #endif
            store.select(element.id, additive: add, individual: true)
          }
          .onDrag {
            if !store.selection.contains(element.id) { store.select(element.id, individual: true) }
            return NSItemProvider(object: ("layer:" + element.id.uuidString) as NSString)
          }
          .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            reorder(providers, before: element.id)
          }
          .contextMenu {
            Button("글씨·이름 수정") { start(element) }
            Button("복제") {
              store.select(element.id, individual: true)
              store.duplicate()
            }
            Button("삭제", role: .destructive) {
              store.select(element.id, individual: true)
              store.delete()
            }
          }
      }
      Color.clear.frame(height: 16).onDrop(of: [UTType.plainText], isTargeted: nil) {
        reorder($0, before: nil)
      }
    }
  }
  private func start(_ e: CoverElement) {
    editing = e.id
    original = store.project
    text = e.type == "text" ? store.project.text(for: e) : e.name
    store.begin()
  }
  private func finish(_ e: CoverElement, cancel: Bool) {
    if cancel {
      store.cancelInteraction()
    } else {
      if e.type != "text", let i = store.project.elements.firstIndex(where: { $0.id == e.id }),
        !text.trimmingCharacters(in: .whitespaces).isEmpty
      {
        store.project.elements[i].name = text
      }
      store.end("레이어 편집")
    }
    editing = nil
    original = nil
  }
  private func reorder(_ providers: [NSItemProvider], before id: UUID?) -> Bool {
    guard let p = providers.first else { return false }
    p.loadObject(ofClass: NSString.self) { value, _ in
      guard let s = value as? String, s.hasPrefix("layer:") else { return }
      Task { @MainActor in
        let ids = store.selection
        store.change("레이어 순서") { CoverEditing.reorder(ids, before: id, in: &$0) }
      }
    }
    return true
  }
}
