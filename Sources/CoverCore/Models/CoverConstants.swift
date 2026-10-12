import Foundation

public enum CoverConstants {
  public static let canvasSize = 1080.0
  public static let documentVersion = 1
  public static var resourceBundle: Bundle {
    #if SWIFT_PACKAGE
      return .module
    #else
      return .main
    #endif
  }
}
