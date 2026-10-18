import SwiftUI

#if os(macOS)
  struct CanvasSurface: NSViewRepresentable {
    @ObservedObject var store: EditorStore
    func makeNSView(context: Context) -> MacCanvas { MacCanvas(store: store) }
    func updateNSView(_ view: MacCanvas, context: Context) { view.needsDisplay = true }
  }
#elseif os(iOS)
  struct CanvasSurface: UIViewRepresentable {
    @ObservedObject var store: EditorStore
    func makeUIView(context: Context) -> PadCanvas { PadCanvas(store: store) }
    func updateUIView(_ view: PadCanvas, context: Context) { view.setNeedsDisplay() }
  }
#endif
