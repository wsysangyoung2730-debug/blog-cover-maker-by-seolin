import CoreText
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
  import AppKit
#endif

struct EditorProjectActions {
  var newProject: () -> Void
  var openProject: () -> Void
  var saveProject: () -> Void
}

struct EditorRoot: View {
  @StateObject private var store: EditorStore
  private let projectActions: EditorProjectActions?
  private let documentUndoManager: UndoManager?
  @ObservedObject private var workspace = WorkspaceSettings.shared
  @Environment(\.undoManager) private var undoManager
  @Environment(\.openURL) private var openURL
  @State private var importing = false
  @State private var pendingImportKind: EditorStore.ImportKind = .base
  @State private var pendingFontTargets: Set<UUID>?
  @State private var smallPanel = "design"
  @State private var showSmallInspector = false
  @State private var widthStart: Double?
  @FocusState private var textFocused: Bool
  @AppStorage("seolinLink") private var linkIndex = 0
  @AppStorage("seolin.tutorial.presentedVersion") private var tutorialVersion = 0
  #if os(macOS)
    @State private var palette: FloatingPalette?
  #endif
  private let links = [
    ("인스타그램", "https://www.instagram.com/seolin5_tkd/"), ("스마트플레이스", "https://naver.me/5Gpnv8PK"),
    ("네이버 블로그", "https://blog.naver.com/brinicle4865"),
  ]
  init(document: CoverDocument, projectActions: EditorProjectActions? = nil, undoManager: UndoManager? = nil) {
    _store = StateObject(wrappedValue: EditorStore(document: document))
    documentUndoManager = undoManager
    #if os(macOS)
      self.projectActions = projectActions ?? EditorProjectActions(
        newProject: { NSDocumentController.shared.newDocument(nil) },
        openProject: { NSDocumentController.shared.openDocument(nil) },
        saveProject: { NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil) }
      )
    #else
      self.projectActions = projectActions
    #endif
  }
  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        if geometry.size.width >= 1060 {
          HStack(spacing: 0) {
            panelColumn(0).frame(width: min(workspace.leftWidth, geometry.size.width * 0.28))
            divider(left: true)
            VStack(spacing: 0) {
              stage
              if !workspace.columns[1].isEmpty {
                panelColumn(1).frame(maxHeight: 300)
              } else {
                panelDrop(column: 1)
              }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            divider(left: false)
            panelColumn(2).frame(width: min(workspace.rightWidth, geometry.size.width * 0.3))
          }
        } else {
          stage
          HStack {
            ForEach(
              [("design", "디자인"), ("properties", "사진·요소"), ("words", "문구"), ("layers", "레이어")],
              id: \.0
            ) { id, name in
              Button(name) {
                smallPanel = id
                showSmallInspector = true
              }.buttonStyle(.bordered)
            }
            Toggle("여러 개 선택", isOn: $store.multipleSelection).toggleStyle(.button)
          }.padding(10)
        }
        Divider()
        HStack {
          Text(store.status).lineLimit(1)
          Spacer()
          Text("1080 × 1080 · \(store.project.elements.count)개 레이어").monospacedDigit()
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 7)
      }
    }
    .navigationTitle("BLOG COVER MAKER")
    #if os(macOS)
      .frame(minWidth: 1100, minHeight: 720)
      .focusedSceneValue(\.editorStore, store)
    #endif
    .toolbar { toolbar }
    .onAppear {
      store.undoManager = documentUndoManager ?? undoManager
      store.undoManager?.levelsOfUndo = 60
      store.refreshThumbnails()
      if tutorialVersion < 1 {
        tutorialVersion = 1
        store.showTutorial = true
      }
      #if DEBUG && STORE_SCREENSHOTS && os(iOS)
        if StoreScreenshotFixture.document != nil,
          let panel = StoreScreenshotFixture.argument("--screenshot-panel"),
          ["design", "properties", "words", "layers"].contains(panel)
        {
          smallPanel = panel
          showSmallInspector = true
        }
      #endif
    }
    .sheet(isPresented: $store.showTutorial) { TutorialView() }
    .onChange(of: store.showTutorial) { _, showing in
      if showing { store.showQuick = false }
    }
    .onChange(of: store.importKind) { _, kind in
      if let kind {
        store.finishText()
        pendingImportKind = kind
        pendingFontTargets = store.fontImportTargets
        importing = true
      }
    }
    .onChange(of: importing) { _, showing in
      if !showing {
        store.importKind = nil
        store.fontImportTargets = nil
      }
    }
    .fileImporter(
      isPresented: $importing,
      allowedContentTypes: pendingImportKind == .font
        ? [
          .font, UTType(filenameExtension: "woff") ?? .data,
          UTType(filenameExtension: "woff2") ?? .data,
        ] : [.image], allowsMultipleSelection: pendingImportKind == .add
    ) { result in
      let kind = pendingImportKind
      store.importKind = nil
      switch result {
      case .success(let urls):
        store.fontImportTargets = pendingFontTargets
        store.importFiles(urls, kind: kind)
      case .failure(let error):
        if (error as NSError).code != NSUserCancelledError {
          store.error = error.localizedDescription
        }
      }
    }
    .fileExporter(
      isPresented: $store.isExporting, document: store.exportData, contentType: .png,
      defaultFilename: store.exportName
    ) { result in
      switch result {
      case .success: store.status = "PNG를 저장했어요."
      case .failure(let error):
        if (error as NSError).code != NSUserCancelledError {
          store.error = error.localizedDescription
        }
      }
    }
    .alert(
      "작업을 완료하지 못했어요",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("확인", role: .cancel) { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .sheet(isPresented: $showSmallInspector) {
      NavigationStack {
        ScrollView { panelContent(smallPanel).padding(20) }.navigationTitle(panelTitle(smallPanel))
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("완료") { showSmallInspector = false }
            }
          }
      }.presentationDetents([.medium, .large])
    }
    .onChange(of: store.editingID) { _, id in textFocused = id != nil }
    #if os(macOS)
      .onChange(of: store.showQuick) { _, show in
        if show {
          if palette == nil { palette = FloatingPalette(store: store) }
          palette?.show()
        } else {
          palette?.hide()
        }
      }
      .onDisappear { palette?.hide() }
    #endif
  }
  private var stage: some View {
    GeometryReader { geometry in
      let side = max(100, min(geometry.size.width - 64, geometry.size.height - 80))
      VStack(spacing: 14) {
        HStack {
          Text(
            CoverCatalog.shared.templates.first { $0.id == store.project.templateID }?.name ?? "표지"
          ).font(.subheadline.weight(.semibold))
          Spacer()
          Text(store.panMode ? "사진 안쪽 위치 조절 중" : "미리보기").font(.caption).foregroundStyle(.secondary)
        }.frame(width: side)
        ZStack(alignment: .topLeading) {
          Rectangle().fill(.white)
          CanvasSurface(store: store)
          if let id = store.editingID, let e = store.project.elements.first(where: { $0.id == id })
          {
            let measured = CoverTypography.measured(e, project: store.project)
            let scale: CGFloat = side / 1080
            let textSize = measured.number("size")
            let editorWidth: CGFloat = max(120, CGFloat(e.w) * scale)
            let editorHeight: CGFloat = max(70, CGFloat(measured.h + textSize * 0.6) * scale)
            let editorX: CGFloat = CGFloat(e.x) * scale + editorWidth / 2
            let editorY: CGFloat = CGFloat(e.y) * scale + editorHeight / 2
            TextEditor(text: Binding(get: { store.editText }, set: { store.updateText($0) })).font(
              Font(CoverTypography.font(e, project: store.project, size: textSize * Double(scale)))
            ).foregroundStyle(.primary).scrollContentBackground(.hidden).padding(2).background(
              .regularMaterial
            ).border(Color.accentColor, width: 2).frame(
              width: editorWidth, height: editorHeight
            ).position(
              x: editorX, y: editorY
            ).focused($textFocused).cancelOnEscape { store.finishText(cancel: true) }
            VStack {
              HStack {
                Spacer()
                Button("취소") { store.finishText(cancel: true) }
                Button("완료") { store.finishText() }.keyboardShortcut(.return, modifiers: .command)
              }
              Spacer()
            }.padding(8)
          }
        }.frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 5)).shadow(
          color: .black.opacity(0.12), radius: 14, y: 5)
        Text(store.panMode ? "사진을 끌어서 틀 안의 위치를 맞추세요." : "두 번 눌러 글씨 수정 · 사진 내부 위치 조절").font(.caption)
          .foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }.background(Color.primary.opacity(0.035).onTapGesture { store.select(nil) })
      #if os(iOS)
        .popover(isPresented: $store.showQuick) {
          QuickPalette(store: store).presentationCompactAdaptation(.popover)
        }
      #endif
  }
  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .navigation) {
      Button {
        openURL(URL(string: links[((linkIndex % 3) + 3) % 3].1)!)
        linkIndex = (linkIndex + 1) % 3
      } label: {
        if let url = CoverConstants.resourceBundle.url(
          forResource: "seolin-logo", withExtension: "png"), let data = try? Data(contentsOf: url),
          let image = ImageAssets.image(data)
        {
          Image(decorative: image, scale: 1).resizable().renderingMode(.template)
            .scaledToFit().frame(width: 24, height: 24).foregroundStyle(Color.accentColor)
        } else {
          Text("SEOLIN")
        }
      }.help(links[((linkIndex % 3) + 3) % 3].0 + " 열기")
    }
    ToolbarItemGroup {
      if let projectActions {
        Menu {
          Button("새 표지 만들기", systemImage: "doc.badge.plus") {
            projectAction(projectActions.newProject)
          }
          Button("불러오기…", systemImage: "folder") { projectAction(projectActions.openProject) }
          Button("저장하기…", systemImage: "square.and.arrow.down") {
            projectAction(projectActions.saveProject)
          }
        } label: {
          Label("프로젝트", systemImage: "doc")
        }.accessibilityIdentifier("projectMenu")
      }
      Button {
        store.importKind = .base
      } label: {
        Label("표지 사진 고르기", systemImage: "photo.badge.plus")
      }.labelStyle(.titleAndIcon).buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
        .accessibilityIdentifier("chooseCoverPhoto")
      Menu {
        Button("로고 추가") { store.importKind = .add }
        Button("글씨 추가") { addText() }
        Button("도형 추가") { addShape() }
        Button("폰트 추가") { store.importKind = .font }
      } label: {
        Label("추가", systemImage: "plus")
      }
      Button {
        store.undo()
      } label: {
        Label("실행 취소", systemImage: "arrow.uturn.backward")
      }
      Button {
        store.redo()
      } label: {
        Label("다시 실행", systemImage: "arrow.uturn.forward")
      }
    }
    ToolbarItemGroup(placement: .primaryAction) {
      Button {
        store.showTutorial = true
      } label: {
        Label("튜토리얼", systemImage: "questionmark.circle")
      }.help("사용 튜토리얼 열기").accessibilityIdentifier("openTutorial")
      Button {
        store.export(.all)
      } label: {
        Label("사진 내보내기", systemImage: "square.and.arrow.up")
      }.labelStyle(.titleAndIcon).buttonStyle(.borderedProminent).tint(.blue)
        .accessibilityIdentifier("exportCoverPhoto")
      Menu {
        Button("메뉴 배치 처음으로") { workspace.reset() }
        Toggle("여러 개 선택", isOn: $store.multipleSelection)
        Button("빠른 편집창") { store.showQuick.toggle() }
        Divider()
        Menu("부분 이미지 내보내기") {
          ForEach(ExportMode.allCases.filter { $0 != .all }) { mode in
            Button(mode.label + " PNG") { store.export(mode) }
          }
        }
        Divider()
        ForEach(links, id: \.0) { title, url in Link(title, destination: URL(string: url)!) }
      } label: {
        Label("보기", systemImage: "sidebar.right")
      }
    }
  }
  private func projectAction(_ action: () -> Void) {
    store.finishText()
    store.end()
    store.showQuick = false
    action()
  }
  private func panelTitle(_ id: String) -> String {
    ["design": "디자인", "properties": "사진·요소", "words": "문구", "layers": "레이어"][id] ?? id
  }
  @ViewBuilder private func panelContent(_ id: String) -> some View {
    switch id {
    case "design": DesignPanel(store: store)
    case "properties": PropertiesPanel(store: store)
    case "words": WordsPanel(store: store)
    case "layers": LayersPanel(store: store)
    default: EmptyView()
    }
  }
  private func panelColumn(_ column: Int) -> some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(workspace.columns[column], id: \.self) { id in
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).onDrag {
                workspace.draggingPanel = id
                return NSItemProvider(object: ("panel:" + id) as NSString)
              }
              Text(panelTitle(id)).font(.headline)
              Spacer()
              Button {
                toggle(id)
              } label: {
                Image(systemName: workspace.collapsed.contains(id) ? "chevron.down" : "chevron.up")
              }.buttonStyle(.plain).help("접기·펼치기")
            }.contentShape(Rectangle()).onTapGesture(count: 2) { toggle(id) }
            if !workspace.collapsed.contains(id) { panelContent(id) }
          }.padding(14).onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            dropPanel(providers, column: column, before: id)
          }
          Divider()
        }
        panelDrop(column: column)
      }
    }.background(.background)
  }
  private func panelDrop(column: Int) -> some View {
    Color.clear.frame(height: workspace.draggingPanel == nil ? 6 : 60).overlay {
      if workspace.draggingPanel != nil {
        Text("여기에 패널 놓기").font(.caption).foregroundStyle(.secondary)
      }
    }.onDrop(of: [UTType.plainText], isTargeted: nil) { dropPanel($0, column: column) }
  }
  private func dropPanel(_ providers: [NSItemProvider], column: Int, before: String? = nil) -> Bool
  {
    guard let provider = providers.first else { return false }
    provider.loadObject(ofClass: NSString.self) { value, _ in
      guard let string = value as? String, string.hasPrefix("panel:") else { return }
      Task { @MainActor in
        workspace.movePanel(String(string.dropFirst(6)), to: column, before: before)
        workspace.draggingPanel = nil
      }
    }
    return true
  }
  private func toggle(_ id: String) {
    if workspace.collapsed.contains(id) {
      workspace.collapsed.remove(id)
    } else {
      workspace.collapsed.insert(id)
    }
  }
  private func divider(left: Bool) -> some View {
    Rectangle().fill(.quaternary).frame(width: 5).contentShape(Rectangle()).gesture(
      DragGesture().onChanged { value in
        if widthStart == nil { widthStart = left ? workspace.leftWidth : workspace.rightWidth }
        let width =
          (widthStart ?? 280) + (left ? value.translation.width : -value.translation.width)
        if left {
          workspace.leftWidth = max(220, min(480, width))
        } else {
          workspace.rightWidth = max(260, min(500, width))
        }
      }.onEnded { _ in widthStart = nil }
    ).onTapGesture(count: 2) {
      if left { workspace.leftWidth = 280 } else { workspace.rightWidth = 320 }
    }
  }
  private func addText() {
    let e = CoverElement([
      "type": .string("text"), "name": .string("새 글씨"), "text": .string("새로운 문구"),
      "x": .number(100), "y": .number(460), "w": .number(880), "h": .number(72),
      "size": .number(60), "font": .string("title"), "color": .string("#ffffff"),
      "align": .string("center"),
    ])
    store.change("글씨 추가") { $0.elements.append(e) }
    store.select(e.id)
    store.startText(e.id)
  }
  private func addShape() {
    let e = CoverElement([
      "type": .string("rect"), "name": .string("새 도형"), "x": .number(300), "y": .number(400),
      "w": .number(480), "h": .number(200), "r": .number(20), "fill": .string("$main"),
    ])
    store.change("도형 추가") { $0.elements.append(e) }
    store.select(e.id)
  }
}
