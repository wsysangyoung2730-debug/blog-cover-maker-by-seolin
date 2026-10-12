import SwiftUI
import UniformTypeIdentifiers

extension UTType {
  static let seolinCover = UTType(exportedAs: "com.seolin.cover-project", conformingTo: .json)
}

final class CoverDocument: ReferenceFileDocument {
  typealias Snapshot = CoverProject
  static var readableContentTypes: [UTType] { [.seolinCover] }
  @Published var project: CoverProject
  init(project: CoverProject = CoverProject()) { self.project = project }
  required init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    project = try CoverProject.decode(data)
    project.fonts.forEach(CoverTypography.register)
  }
  func snapshot(contentType: UTType) throws -> CoverProject { project }
  func fileWrapper(snapshot: CoverProject, configuration: WriteConfiguration) throws -> FileWrapper
  { FileWrapper(regularFileWithContents: try snapshot.encoded()) }
}
struct PNGDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.png] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
