import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct WordsPanel: View {
  @ObservedObject var store: EditorStore
  @FocusState private var focusedField: String?
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
          ).textFieldStyle(.plain).padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
              RoundedRectangle(cornerRadius: 8).stroke(
                enabled ? Color.blue.opacity(focusedField == key ? 1 : 0.55)
                  : Color.secondary.opacity(0.2), lineWidth: focusedField == key ? 2 : 1)
            }
            .focused($focusedField, equals: key).disabled(!enabled)
            .accessibilityLabel(name)
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
      VStack(alignment: .leading, spacing: 5) {
        Text("제목 글씨체").font(.caption).foregroundStyle(.secondary)
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
          .pickerStyle(.menu).labelsHidden().lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
      }
      Button("폰트 파일 추가", systemImage: "textformat") { store.importKind = .font }
      Text("추가한 폰트는 프로젝트에 함께 저장됩니다.").font(.caption).foregroundStyle(.secondary)
    }.onChange(of: focusedField) { _, key in
      if let key { store.wordTarget = key }
    }
  }
}
struct TextStyleControls: View {
  @ObservedObject var store: EditorStore
  var ids: Set<UUID>
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("스타일").font(.caption).foregroundStyle(.secondary)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
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
        }.frame(maxWidth: .infinity)
        ForEach([("it", "기울임"), ("ul", "밑줄"), ("st", "취소선")], id: \.0) { key, label in
          Button(label) { store.toggle(key, ids: ids) }.frame(maxWidth: .infinity)
        }
      }.font(.caption).buttonStyle(.bordered)
      Text("효과·크기").font(.caption).foregroundStyle(.secondary)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
        Button("그림자") { store.toggle("shadow", ids: ids) }.frame(maxWidth: .infinity)
        Button("가−") { size(-4) }.frame(maxWidth: .infinity).accessibilityLabel("글씨 작게")
        Button("가+") { size(4) }.frame(maxWidth: .infinity).accessibilityLabel("글씨 크게")
      }.buttonStyle(.bordered)
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
