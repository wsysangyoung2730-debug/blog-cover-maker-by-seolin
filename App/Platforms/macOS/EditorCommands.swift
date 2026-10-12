import SwiftUI

#if os(macOS)
  private struct EditorStoreKey: FocusedValueKey { typealias Value = EditorStore }
  extension FocusedValues {
    var editorStore: EditorStore? {
      get { self[EditorStoreKey.self] }
      set { self[EditorStoreKey.self] = newValue }
    }
  }
  struct EditorCommands: Commands {
    @FocusedValue(\.editorStore) private var store
    var body: some Commands {
      CommandGroup(replacing: .help) {
        Button("사용 튜토리얼") { store?.showTutorial = true }
          .disabled(store == nil)
      }
      CommandGroup(after: .newItem) {
        Divider()
        Button("기본 사진 불러오기…") { store?.importKind = .base }.keyboardShortcut(
          "i", modifiers: .command)
        Button("사진·로고 추가…") { store?.importKind = .add }
        Button("폰트 추가…") { store?.importKind = .font }
        Divider()
        Menu("PNG 내보내기") {
          ForEach(ExportMode.allCases) { mode in Button(mode.label) { store?.export(mode) } }
        }
      }
      CommandMenu("요소") {
        Button("복제") { store?.duplicate() }.keyboardShortcut("d")
        Button("삭제") { store?.delete() }.keyboardShortcut(.delete, modifiers: [])
        Divider()
        Button("그룹 묶기") { store?.group() }.keyboardShortcut("g")
        Button("그룹 풀기") { store?.ungroup() }.keyboardShortcut("g", modifiers: [.command, .shift])
        Button("같은 종류 선택") { store?.selectSame() }
        Divider()
        Button("맨 앞으로") { store?.moveLayer("front") }
        Button("앞으로") { store?.moveLayer("up") }
        Button("뒤로") { store?.moveLayer("down") }
        Button("맨 뒤로") { store?.moveLayer("back") }
        Divider()
        Button("빠른 편집창") { store?.showQuick = true }
      }
    }
  }
#endif
