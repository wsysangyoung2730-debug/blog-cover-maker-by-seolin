#if DEBUG
  import Foundation
  import Darwin

  /// Runs model/document checks without driving the UI or touching user documents.
  @MainActor enum EditorVerification {
    static func runIfRequested() {
      let args = CommandLine.arguments
      guard let i = args.firstIndex(of: "--verify-editor"), args.indices.contains(i + 1) else {
        return
      }
      let output = URL(fileURLWithPath: args[i + 1], isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let document = CoverDocument()
        let store = EditorStore(document: document)
        let undo = UndoManager()
        undo.groupsByEvent = false
        store.undoManager = undo
        let initial = store.project
        undo.beginUndoGrouping()
        store.change("문구와 테마") {
          $0.words["line1"] = "서린 태권도 검증"
          $0.themeID = "coral"
        }
        undo.endUndoGrouping()
        let edited = store.project
        guard document.project == edited else { throw Failure("문서 상태 연결 실패") }
        undo.undo()
        guard store.project == initial else { throw Failure("전체 상태 실행 취소 실패") }
        undo.redo()
        guard store.project == edited else { throw Failure("전체 상태 다시 실행 실패") }
        // Finishing a canvas text draft before another action must preserve both undo records.
        let textID = store.project.elements.first { $0.type == "text" }!.id
        let originalText = store.project.text(for: store.project.elements.first { $0.id == textID }!)
        store.startText(textID)
        store.updateText("취소 검증")
        store.finishText(cancel: true)
        guard store.project.text(for: store.project.elements.first { $0.id == textID }!) == originalText
        else { throw Failure("글씨 취소 실패") }
        undo.beginUndoGrouping()
        store.startText(textID)
        store.updateText("글씨 확정 후 테마 변경")
        store.change("테마") { $0.themeID = "mint" }
        undo.endUndoGrouping()
        guard store.editingID == nil else { throw Failure("다른 작업 전 글씨 확정 실패") }
        store.finishText(cancel: true)
        guard store.project.themeID == "mint" else { throw Failure("글씨 취소가 후속 변경을 덮어씀") }
        undo.undo()
        guard store.project == edited else { throw Failure("글씨와 테마 실행 취소 실패") }
        undo.redo()
        let replacement = CoverProject()
        document.project = replacement
        guard store.project == replacement else { throw Failure("외부 문서 복원 연결 실패") }
        let suite = "com.seolin.verification." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(#"{"favorites":[],"collapsed":[],"columns":[],"thumbnailSize":-1,"leftWidth":-1,"rightWidth":999999}"#.utf8), forKey: "workspace.v1")
        let workspace = WorkspaceSettings(defaults: defaults)
        guard workspace.columns.count == 3, workspace.leftWidth == 220,
          workspace.rightWidth == 500 else { throw Failure("손상된 작업 공간 복구 실패") }
        workspace.movePanel("untrusted", to: 0)
        guard workspace.columns.flatMap({ $0 }).count == 4 else { throw Failure("잘못된 패널 드롭 허용") }
        let file = try store.project.encoded()
        try file.write(
          to: output.appendingPathComponent("Verification.seolincover"), options: .atomic)
        guard try CoverProject.decode(file) == store.project else { throw Failure("문서 왕복 저장 실패") }
        let renderer = CoverRenderer()
        for mode in ExportMode.allCases {
          try renderer.png(project: store.project, mode: mode).write(
            to: output.appendingPathComponent(mode.rawValue + ".png"))
        }
        for template in CoverCatalog.shared.templates {
          var p = store.project
          p.applyTemplate(template.id)
          guard let image = renderer.image(project: p, size: 216) else {
            throw Failure(template.id)
          }
          try ImageAssets.png(image).write(
            to: output.appendingPathComponent(template.id + "-preview.png"))
        }
        let report = "문서 연결·외부 복원, 글씨 편집/취소/후속 작업, 실행 취소·다시 실행, 작업 공간 복구, 프로젝트 왕복 저장, PNG 3종, 템플릿 50종 출력 통과\n"
        try report.write(
          to: output.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
        print(report)
        exit(0)
      } catch {
        fputs("검증 실패: \(error)\n", stderr)
        exit(1)
      }
    }
    struct Failure: Error {
      let message: String
      init(_ message: String) { self.message = message }
    }
  }
#endif
