import Foundation
import XCTest
@testable import CoverCore

final class ProjectDraftTests: XCTestCase {
  func testRecoverySeparatesWindowsAndRejectsLateSaves() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = ProjectDraftRepository(directory: directory)
    let firstID = UUID(), secondID = UUID()
    let missing = try await repository.load(firstID)
    XCTAssertNil(missing)
    let original = CoverProject()
    var latest = original
    latest.words["line1"] = "이어서 편집할 표지"
    latest.images["test"] = try ImageAssets.png(XCTUnwrap(CoverRenderer().image(project: latest, size: 32)))
    latest.mainPhoto.push("test")
    try await repository.save(latest, id: firstID, revision: 2)
    try await repository.save(original, id: firstID, revision: 1)
    try await repository.save(original, id: secondID, revision: 3)
    let reopened = ProjectDraftRepository(directory: directory)
    let recoveredFirst = try await reopened.load(firstID)
    let recoveredSecond = try await reopened.load(secondID)
    XCTAssertEqual(recoveredFirst, latest)
    XCTAssertEqual(recoveredSecond, original)
    let userFile = directory.appendingPathComponent("기존 문서.seolincover")
    try latest.encoded().write(to: userFile)
    let imported = try await reopened.readDocument(at: userFile)
    XCTAssertEqual(imported, latest)
    XCTAssertEqual(try Data(contentsOf: userFile), try latest.encoded())
  }

  func testCorruptRecoveryIsReportedWithoutOverwritingIt() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let id = UUID()
    let file = directory.appendingPathComponent(id.uuidString).appendingPathExtension("seolincover")
    let badData = Data("not a project".utf8)
    try badData.write(to: file)
    do {
      _ = try await ProjectDraftRepository(directory: directory).load(id)
      XCTFail("손상된 초안을 성공으로 처리함")
    } catch {
      XCTAssertEqual(try Data(contentsOf: file), badData)
    }
  }
}
