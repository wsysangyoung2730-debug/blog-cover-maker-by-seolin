import SwiftUI

extension View {
  @ViewBuilder func cancelOnEscape(_ action: @escaping () -> Void) -> some View {
    #if os(macOS)
      self.onExitCommand(perform: action)
    #else
      self
    #endif
  }
}
