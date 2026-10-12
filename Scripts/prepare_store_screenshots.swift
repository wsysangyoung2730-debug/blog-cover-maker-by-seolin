import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Format/color conversion and letterboxing only; captured app pixels are never redrawn.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let base = root.appendingPathComponent("Marketing/AppStore")
let names = ["01-cover-editor", "02-design-library", "03-typography", "04-tutorial"]
for (platform, prefix, width, height) in [("macOS", "mac", 2880, 1800), ("iPadOS", "ipad", 2064, 2752)] {
  for (index, name) in names.enumerated() {
    let input = base.appendingPathComponent(String(format: "Source/Captures/%@-%02d.%@", prefix, index + 1, prefix == "mac" ? "jpg" : "png"))
    guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width <= width, image.height <= height,
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fatalError("Invalid screenshot: \(input.path)") }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: (width - image.width) / 2, y: (height - image.height) / 2,
      width: image.width, height: image.height))
    let output = base.appendingPathComponent("ko-KR/\(platform)/\(name).png")
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let result = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("Cannot write \(output.path)") }
    CGImageDestinationAddImage(destination, result, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("PNG write failed") }
    print("\(platform)/\(name).png · \(width)×\(height) · sRGB · opaque")
  }
}
