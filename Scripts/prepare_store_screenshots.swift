import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Editable store artwork. Real app captures are embedded without retouching UI pixels.
// Text, backgrounds, borders and shadows are drawn separately from the captures.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let base = root.appendingPathComponent("Marketing/AppStore")
struct Story {
  let file: String
  let macTitle: String
  let padTitle: String
  let detail: String
}
let stories = [
  Story(file: "01-cover-editor", macTitle: "사진 한 장, 우리 도장만의 표지.",
    padTitle: "사진 한 장,\n우리 도장만의 표지.", detail: "사진과 문구를 넣고, 바뀌는 표지를 바로 확인하세요."),
  Story(file: "02-design-library", macTitle: "50가지 디자인으로, 다채롭게.",
    padTitle: "50가지 디자인으로,\n다채롭게.", detail: "마음에 드는 디자인에 22가지 테마로 색을 입히세요."),
  Story(file: "03-typography", macTitle: "글씨 하나까지, 원하는 느낌으로.",
    padTitle: "글씨 하나까지,\n원하는 느낌으로.", detail: "글씨체와 색, 강조와 정렬을 취향에 맞게 다듬으세요."),
  Story(file: "04-tutorial", macTitle: "첫 표지부터, 차근차근 함께.",
    padTitle: "첫 표지부터,\n차근차근 함께.", detail: "사진 불러오기부터 PNG 저장까지, 7단계로 익혀보세요.")
]
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func load(_ path: URL) -> CGImage {
  guard let source = CGImageSourceCreateWithURL(path as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError(path.path) }
  return image
}
func image(_ source: CGImage, rect: CGRect, context: CGContext) {
  context.saveGState()
  context.translateBy(x: rect.minX, y: rect.maxY)
  context.scaleBy(x: 1, y: -1)
  context.interpolationQuality = .high
  context.draw(source, in: CGRect(origin: .zero, size: rect.size))
  context.restoreGState()
}
func text(_ string: String, rect: CGRect, size: CGFloat, weight: NSFont.Weight = .regular,
          ink: NSColor, spacing: CGFloat = 0, alignment: NSTextAlignment = .left) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = alignment
  paragraph.lineSpacing = spacing
  let font = NSFont.systemFont(ofSize: size, weight: weight)
  let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink,
    .paragraphStyle: paragraph, .kern: -size * 0.025]
  let attributed = NSAttributedString(string: string, attributes: attributes)
  let needed = attributed.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
    options: [.usesLineFragmentOrigin, .usesFontLeading])
  precondition(needed.height <= rect.height + 2, "Text overflows: \(string)")
  attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}
func rounded(_ rect: CGRect, radius: CGFloat) -> CGPath {
  CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}
func framed(_ source: CGImage, rect: CGRect, radius: CGFloat, context: CGContext, dark: Bool) {
  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: 28), blur: 64,
                    color: color(0x10294E, dark ? 0.5 : 0.18).cgColor)
  context.addPath(rounded(rect, radius: radius))
  context.setFillColor(NSColor.white.cgColor)
  context.fillPath()
  context.restoreGState()
  context.saveGState()
  context.addPath(rounded(rect, radius: radius))
  context.clip()
  image(source, rect: rect, context: context)
  context.restoreGState()
  context.addPath(rounded(rect, radius: radius))
  context.setStrokeColor(color(dark ? 0xFFFFFF : 0x10294E, dark ? 0.22 : 0.12).cgColor)
  context.setLineWidth(2)
  context.strokePath()
}
if !CommandLine.arguments.contains("--intro-only") {
for (platform, prefix, width, height) in [("macOS", "mac", 2880, 1800), ("iPadOS", "ipad", 2064, 2752)] {
  for (index, story) in stories.enumerated() {
    let mac = platform == "macOS", dark = index == 1
    let w = CGFloat(width), h = CGFloat(height)
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fatalError("Cannot create canvas") }
    context.translateBy(x: 0, y: h)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    let bg1 = color(dark ? 0x112B59 : (index == 2 ? 0xF4F1FB : 0xF2F7FF))
    let bg2 = color(dark ? 0x2464AF : (index == 2 ? 0xDCE8FC : 0xDCEBFF))
    let gradient = CGGradient(colorsSpace: space, colors: [bg1.cgColor, bg2.cgColor] as CFArray, locations: [0,1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x:w,y:h), options: [])
    // Quiet framing accents keep attention on the actual app.
    context.setFillColor(color(0xFFFFFF, dark ? 0.045 : 0.28).cgColor)
    context.fillEllipse(in: CGRect(x: w * 0.6, y: h * 0.23, width: w * 0.75, height: w * 0.75))
    let ink = color(dark ? 0xFFFFFF : 0x14284B)
    let secondary = color(dark ? 0xD2E5FF : 0x536681)
    let margin: CGFloat = mac ? 144 : 112
    text(mac ? story.macTitle : story.padTitle,
      rect:CGRect(x:margin,y:mac ? 116 : 175,width:w-2*margin,height:mac ? 145 : 328),
      size:mac ? 104 : 128,weight:.bold,ink:ink,spacing:10)
    text(story.detail,rect:CGRect(x:margin,y:mac ? 270 : 535,width:w-2*margin,height:mac ? 74 : 85),
      size:mac ? 43 : 43,ink:secondary)
    let input = base.appendingPathComponent(String(format:"Source/Captures/%@-%02d.%@",prefix,index+1,mac ? "jpg" : "png"))
    let original = load(input)
    // In Mac captures 2–3 the pointer is parked on the bottom status strip.
    // Omit that strip; do not inpaint, redraw or cover any editing controls.
    let shot: CGImage
    if mac && (index == 1 || index == 2) {
      shot = original.cropping(to: CGRect(x: 0, y: 0, width: original.width, height: original.height - 90))!
    } else {
      shot = original
    }
    let targetHeight: CGFloat = mac ? 1288 : 1942
    let targetWidth = targetHeight * CGFloat(shot.width) / CGFloat(shot.height)
    let frame = CGRect(x:(w-targetWidth)/2,y:mac ? 388 : 690,width:targetWidth,height:targetHeight)
    precondition(frame.maxX < w && frame.maxY < h - 80)
    framed(shot,rect:frame,radius:mac ? 22 : 36,context:context,dark:dark)
    NSGraphicsContext.restoreGraphicsState()
    let output = base.appendingPathComponent("ko-KR/\(platform)/\(story.file).png")
    try FileManager.default.createDirectory(at:output.deletingLastPathComponent(),withIntermediateDirectories:true)
    guard let final=context.makeImage(),let destination=CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)
    else { fatalError("Cannot write \(output.path)") }
    CGImageDestinationAddImage(destination,final,nil)
    precondition(CGImageDestinationFinalize(destination))
    print("\(platform)/\(story.file).png · \(width)×\(height) · sRGB · opaque")
  }
}
}

// A separate opening card keeps the existing four feature images unchanged.
// Preserve the supplied logo silhouette and recolor its alpha to white for navy.
func whiteLogo(_ source: CGImage) -> CGImage {
  let space = CGColorSpace(name: CGColorSpace.sRGB)!
  let context = CGContext(data: nil, width: source.width, height: source.height,
    bitsPerComponent: 8, bytesPerRow: source.width * 4, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  let rect = CGRect(x: 0, y: 0, width: source.width, height: source.height)
  context.draw(source, in: rect)
  context.setBlendMode(.sourceIn)
  context.setFillColor(NSColor.white.cgColor)
  context.fill(rect)
  return context.makeImage()!
}
let brandLogo = whiteLogo(load(root.appendingPathComponent("Design/Branding/References/seolin-logo-basic.png")))
let appIcon = load(root.appendingPathComponent("Design/Branding/blog-cover-maker-icon.png"))
for (platform, prefix, width, height) in [("macOS", "mac", 2880, 1800), ("iPadOS", "ipad", 2064, 2752)] {
  let mac = platform == "macOS", w = CGFloat(width), h = CGFloat(height)
  let space = CGColorSpace(name: CGColorSpace.sRGB)!
  let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  context.translateBy(x: 0, y: h)
  context.scaleBy(x: 1, y: -1)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
  let gradient = CGGradient(colorsSpace: space,
    colors: [color(0x18275D).cgColor, color(0x263E84).cgColor] as CFArray, locations: [0, 1])!
  context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])
  context.setFillColor(color(0x84BFFF, 0.055).cgColor)
  context.fillEllipse(in: CGRect(x: w * 0.36, y: h * 0.24, width: w * 0.9, height: w * 0.9))
  let margin: CGFloat = mac ? 152 : 132
  text(mac ? "블로그 표지,\n손쉽게 만들고\n편집하세요." : "블로그 표지,\n손쉽게 만들고 편집하세요.",
    rect: CGRect(x: margin, y: mac ? 200 : 154, width: mac ? 975 : w - 2 * margin,
                 height: mac ? 510 : 330),
    size: mac ? 112 : 114, weight: .bold, ink: .white, spacing: 14)
  text("사진과 문구를 넣고,\n원하는 디자인으로 간편하게 완성하세요.",
    rect: CGRect(x: margin, y: mac ? 750 : 525, width: mac ? 915 : w - 2 * margin, height: 150),
    size: mac ? 43 : 47, ink: color(0xD0E0FF), spacing: 10)
  let iconSide: CGFloat = mac ? 268 : 276
  let iconY: CGFloat = mac ? 1035 : 776
  framed(appIcon, rect: CGRect(x: margin, y: iconY, width: iconSide, height: iconSide),
    radius: 54, context: context, dark: true)
  text("BLOG COVER\nMAKER",
    rect: CGRect(x: margin + iconSide + 42, y: iconY + 35,
                 width: mac ? 585 : 1160, height: 165),
    size: mac ? 59 : 66, weight: .semibold, ink: .white, spacing: 4)
  text("by SEOLIN",
    rect: CGRect(x: margin + iconSide + 46, y: iconY + 205, width: 600, height: 60),
    size: 34, ink: color(0xB5CEF5))

  let capture = load(base.appendingPathComponent("Source/Captures/\(prefix)-01.\(mac ? "jpg" : "png")"))
  let shotWidth: CGFloat = mac ? 1588 : 860
  let shotHeight = shotWidth * CGFloat(capture.height) / CGFloat(capture.width)
  let shotRect = CGRect(x: mac ? 1140 : (w - shotWidth) / 2,
                        y: mac ? 350 : 1190, width: shotWidth, height: shotHeight)
  framed(capture, rect: shotRect, radius: mac ? 24 : 35, context: context, dark: true)
  let logoWidth: CGFloat = mac ? 272 : 256
  let logoHeight = logoWidth * CGFloat(brandLogo.height) / CGFloat(brandLogo.width)
  let logoRect = CGRect(x: w - margin - logoWidth, y: h - 100 - logoHeight,
                        width: logoWidth, height: logoHeight)
  precondition(shotRect.maxY < logoRect.minY - 50)
  image(brandLogo, rect: logoRect, context: context)
  NSGraphicsContext.restoreGraphicsState()
  let output = base.appendingPathComponent("ko-KR/\(platform)/00-brand-intro.png")
  let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, context.makeImage()!, nil)
  precondition(CGImageDestinationFinalize(destination))
  print("\(platform)/00-brand-intro.png · \(width)×\(height) · sRGB · opaque")
}
