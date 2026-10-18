#if os(iOS)
  import Combine
  import SwiftUI
  import UniformTypeIdentifiers

  struct PadEditorScene: View {
    @StateObject private var session = EditorProjectSession()
    @SceneStorage("seolin.editor.draftID") private var draftID = ""
    @SceneStorage("seolin.editor.filename") private var filename = "나의 표지"
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
      NavigationStack {
        if session.isReady {
          EditorRoot(document: session.document, projectActions: EditorProjectActions(
            newProject: { session.requestNew() }, openProject: { session.isOpening = true },
            saveProject: { session.prepareSave() }
          ), undoManager: session.undoManager).id(session.editorID)
        } else {
          ProgressView("표지를 준비하고 있어요")
        }
      }
      .task {
        let id = UUID(uuidString: draftID) ?? UUID()
        draftID = id.uuidString
        await session.restore(id: id, filename: filename)
      }
      .onOpenURL { url in Task { await session.open(url) } }
      .onChange(of: session.filename) { _, name in filename = name }
      .onChange(of: session.draftID) { _, id in if let id { draftID = id.uuidString } }
      .onChange(of: scenePhase) { _, phase in if phase != .active { session.flushDraft() } }
      .onDisappear { session.flushDraft() }
      .fileImporter(isPresented: $session.isOpening, allowedContentTypes: [.seolinCover]) { result in
        switch result {
        case .success(let url): Task { await session.open(url) }
        case .failure(let error): session.report(error)
        }
      }
      .fileExporter(
        isPresented: $session.isSaving, document: session.exportSnapshot,
        contentTypes: [.seolinCover], defaultFilename: session.filename,
        onCompletion: { session.saved($0) }, onCancellation: { session.cancelSave() }
      )
      .confirmationDialog("현재 표지를 저장할까요?", isPresented: $session.confirmReplacement,
                          titleVisibility: .visible) {
        Button("저장하고 계속") { session.prepareSave(continuing: true) }
        Button("저장하지 않고 계속", role: .destructive) { session.applyPending() }
        Button("취소", role: .cancel) { session.cancelReplacement() }
      } message: {
        Text("저장하면 사진과 문구를 나중에 다시 편집할 수 있어요.")
      }
      .alert("프로젝트를 처리하지 못했어요", isPresented: Binding(
        get: { session.error != nil }, set: { if !$0 { session.error = nil } }
      )) {
        Button("확인", role: .cancel) { session.error = nil }
      } message: { Text(session.error ?? "") }
    }
  }

#endif
