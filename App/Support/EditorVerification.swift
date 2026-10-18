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
        try verifyTouchMovement()
        try verifyPhotoAlignment()
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
    private static func verifyTouchMovement() throws {
      var project = CoverProject()
      project.elements = [
        CoverElement(["type": .string("rect"), "x": .number(100), "y": .number(100),
                      "w": .number(200), "h": .number(200), "fill": .string("#ffffff")]),
        CoverElement(["type": .string("rect"), "x": .number(500), "y": .number(500),
                      "w": .number(100), "h": .number(100), "fill": .string("#ffffff")]),
      ]
      let store = EditorStore(document: CoverDocument(project: project))
      let interaction = CanvasInteraction(store)
      let start = CGPoint(x: 200, y: 200)
      let end = CGPoint(x: 240, y: 230)
      interaction.down(start, deferSelectionToggle: true)
      interaction.up(start, showsQuickPalette: false)
      guard store.selection == [project.elements[0].id], !store.showQuick else {
        throw Failure("iPad 선택 후 팝업 없이 드래그 준비 실패")
      }
      let undo = UndoManager()
      undo.groupsByEvent = false
      store.undoManager = undo
      for multiple in [false, true] {
        store.multipleSelection = multiple
        let ids = multiple ? Set(project.elements.map(\.id)) : Set([project.elements[0].id])
        store.selection = ids
        undo.beginUndoGrouping()
        interaction.down(start, deferSelectionToggle: true)
        interaction.drag(end)
        interaction.up(end, showsQuickPalette: false)
        undo.endUndoGrouping()
        guard store.selection == ids, !store.showQuick else {
          throw Failure("iPad 드래그 중 선택 해제 또는 팝업 표시")
        }
        for (before, after) in zip(project.elements, store.project.elements) {
          let moved = ids.contains(before.id)
          guard after.x == before.x + (moved ? 40 : 0),
                after.y == before.y + (moved ? 30 : 0) else {
            throw Failure("iPad 단일·다중 선택 이동 실패")
          }
        }
        undo.undo()
        guard store.project == project else { throw Failure("iPad 이동 실행 취소 실패") }
      }
      interaction.down(start, deferSelectionToggle: true)
      interaction.up(start, showsQuickPalette: false)
      guard !store.selection.contains(project.elements[0].id) else {
        throw Failure("다중 선택 모드의 탭 선택 전환 실패")
      }
    }
    private static func verifyPhotoAlignment() throws {
      var project = CoverProject()
      let photo = CoverElement([
        "type": .string("photo"), "x": .number(90), "y": .number(140),
        "w": .number(800), "h": .number(600), "zoom": .number(1.5),
        "ox": .number(120), "oy": .number(-90),
      ])
      project.elements = [photo]
      let store = EditorStore(document: CoverDocument(project: project))
      let interaction = CanvasInteraction(store)
      let point = CGPoint(x: 400, y: 400)
      interaction.down(point, double: true)
      interaction.up(point)
      guard store.panMode else { throw Failure("사진 더블클릭 내부 편집 진입 실패") }
      let undo = UndoManager()
      undo.groupsByEvent = false
      store.undoManager = undo
      undo.beginUndoGrouping()
      store.align("c")
      undo.endUndoGrouping()
      guard store.project.elements[0].number("ox") == 0,
        store.project.elements[0].number("oy") == -90,
        store.project.elements[0].rect == photo.rect, store.panMode
      else { throw Failure("사진 내부 가로 가운데 정렬 실패") }
      undo.undo()
      guard store.project == project else { throw Failure("사진 내부 정렬 실행 취소 실패") }
      undo.redo()
      guard store.project.elements[0].number("ox") == 0 else {
        throw Failure("사진 내부 정렬 다시 실행 실패")
      }
      undo.beginUndoGrouping()
      store.align("m")
      undo.endUndoGrouping()
      guard store.project.elements[0].number("oy") == 0 else {
        throw Failure("사진 내부 세로 가운데 정렬 실패")
      }
      store.panMode = false
      undo.beginUndoGrouping()
      store.align("c")
      undo.endUndoGrouping()
      guard store.project.elements[0].rect.midX == 540 else {
        throw Failure("일반 사진 틀 가운데 정렬 실패")
      }
    }
    struct Failure: Error {
      let message: String
      init(_ message: String) { self.message = message }
    }
  }
#endif
