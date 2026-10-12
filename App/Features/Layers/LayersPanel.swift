import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct LayersPanel: View {
  @ObservedObject var store: EditorStore
  @State private var editing: UUID?
  @State private var text = ""
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
              .onSubmit { finish(element, cancel: false) }.cancelOnEscape {
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
    store.finishText()
    editing = e.id
    text = e.type == "text" ? store.project.text(for: e) : e.name
  }
  private func finish(_ e: CoverElement, cancel: Bool) {
    if !cancel {
      store.change("레이어 편집") { project in
        if e.type == "text" {
          project.setText(text, elementID: e.id)
        } else if let i = project.elements.firstIndex(where: { $0.id == e.id }),
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          project.elements[i].name = text
        }
      }
    }
    editing = nil
  }
  private func reorder(_ providers: [NSItemProvider], before id: UUID?) -> Bool {
    guard let p = providers.first else { return false }
    p.loadObject(ofClass: NSString.self) { value, _ in
      guard let s = value as? String, s.hasPrefix("layer:") else { return }
      Task { @MainActor in
        guard let dragged = UUID(uuidString: String(s.dropFirst(6))),
          store.project.elements.contains(where: { $0.id == dragged }) else { return }
        let ids = store.selection.contains(dragged) ? store.selection : [dragged]
        store.change("레이어 순서") { CoverEditing.reorder(ids, before: id, in: &$0) }
      }
    }
    return true
  }
}
