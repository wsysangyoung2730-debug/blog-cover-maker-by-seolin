import Foundation

/// Local recovery copies are separate from documents explicitly chosen by the user.
public actor ProjectDraftRepository {
  private let directory: URL
  private var savedRevisions: [UUID: Int] = [:]

  public init(directory: URL) { self.directory = directory }

  public func load(_ id: UUID) throws -> CoverProject? {
    let url = fileURL(id)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try CoverProject.decode(Data(contentsOf: url))
  }

  public func save(_ project: CoverProject, id: UUID, revision: Int) throws {
    guard revision >= savedRevisions[id, default: -1] else { return }
    let data = try project.encoded()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: fileURL(id), options: .atomic)
    savedRevisions[id] = revision
  }

  public func readDocument(at url: URL) throws -> CoverProject {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    var data: Result<Data, Error>?
    var coordinationError: NSError?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
      data = Result { try Data(contentsOf: coordinatedURL) }
    }
    if let coordinationError { throw coordinationError }
    guard let data else { throw CocoaError(.fileReadUnknown) }
    return try CoverProject.decode(data.get())
  }

  private func fileURL(_ id: UUID) -> URL {
    directory.appendingPathComponent(id.uuidString).appendingPathExtension("seolincover")
  }
}
