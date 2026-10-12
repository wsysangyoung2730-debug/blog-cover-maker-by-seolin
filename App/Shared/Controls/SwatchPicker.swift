import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct SwatchPicker: View {
  @ObservedObject var store: EditorStore
  var token: String
  var change: (String) -> Void
  private let tokens = [
    "$main", "$accent", "$dark", "$ink", "$paper", "#ffffff", "#000000", "#E5262A", "#F27A1A",
    "#F5C400", "#22A447", "#1E7BFF", "#3340B5", "#8A3FD1",
  ]
  var body: some View {
    VStack(alignment: .leading) {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
        ForEach(tokens, id: \.self) { value in
          Button {
            change(value)
          } label: {
            Circle().fill(Color(cgColor: CoverRenderer.color(value, project: store.project))).frame(
              width: 24, height: 24
            ).overlay { Circle().stroke(.gray.opacity(0.3), lineWidth: 1) }.padding(2).overlay {
              Circle().stroke(token == value ? Color.accentColor : .clear, lineWidth: 2)
            }
          }.buttonStyle(.plain).accessibilityLabel(value)
        }
      }
      ColorPicker(
        "직접 색 고르기",
        selection: Binding(
          get: { Color(cgColor: CoverRenderer.color(token, project: store.project)) },
          set: { color in
            if let cg = color.cgColor?.converted(
              to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let components = cg.components, components.count >= 3
            {
              change(
                String(
                  format: "#%02X%02X%02X", Int(components[0] * 255), Int(components[1] * 255),
                  Int(components[2] * 255)))
            }
          }), supportsOpacity: false)
    }
  }
}
