import Combine
import SwiftUI

@MainActor final class EditorProjectSession: ObservableObject {
  let document: CoverDocument
  let undoManager = UndoManager()
  @Published private(set) var isReady = false
  @Published private(set) var editorID = UUID()
  @Published private(set) var draftID: UUID?
  @Published private(set) var filename = "나의 표지"
  @Published var isOpening = false
  @Published var isSaving = false
  @Published var confirmReplacement = false
  @Published var exportSnapshot: CoverProjectFile?
  @Published var error: String?
  private let repository: ProjectDraftRepository
  private var observation: AnyCancellable?
  private var saveTask: Task<Void, Never>?
  private var revision = 0
  private var savedProject: CoverProject
  private var pending: (project: CoverProject, name: String)?
  private var pendingURL: URL?
  private var continueAfterSave = false
  private var restoring = false

  init() {
    let document = CoverDocument()
    self.document = document
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("EditorDrafts", isDirectory: true)
    repository = ProjectDraftRepository(directory: directory)
    savedProject = document.project
  }

  func restore(id: UUID, filename: String) async {
    guard !isReady, !restoring else { return }
    restoring = true
    defer { restoring = false }
    draftID = id
    self.filename = filename
    do {
      if let recovered = try await repository.load(id) {
        document.project = recovered
        recovered.fonts.forEach(CoverTypography.register)
      }
    } catch {
      // Keep the damaged recovery file available; new edits use a fresh file.
      draftID = UUID()
      self.error = "이전 작업을 복구하지 못했어요. 저장한 프로젝트 파일을 불러와 주세요."
    }
    isReady = true
    observation = document.$project.dropFirst().sink { [weak self] project in
      MainActor.assumeIsolated { self?.scheduleDraft(project, delayed: true) }
    }
    if let url = pendingURL {
      pendingURL = nil
      await open(url)
    }
  }

  func requestNew() { requestReplacement(CoverProject(), name: "나의 표지") }

  func open(_ url: URL) async {
    guard isReady else { pendingURL = url; return }
    do {
      let project = try await repository.readDocument(at: url)
      requestReplacement(project, name: url.deletingPathExtension().lastPathComponent)
    } catch { report(error) }
  }

  private func requestReplacement(_ project: CoverProject, name: String) {
    pending = (project, name)
    if document.project != savedProject { confirmReplacement = true }
    else { applyPending() }
  }

  func applyPending() {
    guard let pending else { return }
    document.project = pending.project
    pending.project.fonts.forEach(CoverTypography.register)
    filename = pending.name
    savedProject = pending.project
    undoManager.removeAllActions()
    editorID = UUID()
    self.pending = nil
    confirmReplacement = false
    flushDraft()
  }

  func cancelReplacement() {
    pending = nil
    continueAfterSave = false
    confirmReplacement = false
  }

  func prepareSave(continuing: Bool = false) {
    confirmReplacement = false
    continueAfterSave = continuing
    exportSnapshot = CoverProjectFile(project: document.project)
    isSaving = true
    flushDraft()
  }

  func saved(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
      if let snapshot = exportSnapshot { savedProject = snapshot.project }
      filename = url.deletingPathExtension().lastPathComponent
      if continueAfterSave { applyPending() }
    case .failure(let error): report(error)
    }
    continueAfterSave = false
    exportSnapshot = nil
    isSaving = false
  }

  func cancelSave() {
    continueAfterSave = false
    exportSnapshot = nil
    pending = nil
    isSaving = false
    confirmReplacement = false
  }

  func report(_ error: Error) {
    guard (error as NSError).code != NSUserCancelledError else { return }
    self.error = error.localizedDescription
  }

  func flushDraft() {
    guard isReady else { return }
    scheduleDraft(document.project, delayed: false)
  }

  private func scheduleDraft(_ project: CoverProject, delayed: Bool) {
    guard let id = draftID else { return }
    revision += 1
    let revision = revision, repository = repository
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      if delayed {
        do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
      }
      guard !Task.isCancelled else { return }
      do { try await repository.save(project, id: id, revision: revision) }
      catch { self?.error = "작업 초안을 보관하지 못했어요. 프로젝트 저장하기로 파일을 보관해 주세요." }
    }
  }
}
