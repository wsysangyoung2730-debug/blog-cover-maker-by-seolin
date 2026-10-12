import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct NumberControl: View {
  var title: String
  var value: Binding<Double>
  var range: ClosedRange<Double>
  var unit: String = ""
  var editing: (Bool) -> Void = { _ in }
  var body: some View {
    VStack(spacing: 5) {
      HStack {
        Text(title)
        Spacer()
        TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
          .multilineTextAlignment(.trailing).frame(width: 58).textFieldStyle(.roundedBorder)
        Text(unit).foregroundStyle(.secondary)
      }.font(.caption)
      Slider(value: value, in: range, onEditingChanged: editing)
    }
  }
}
