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
        let report = "문서 연결, 실행 취소, 다시 실행, 프로젝트 왕복 저장, PNG 3종, 템플릿 50종 출력 통과\n"
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
