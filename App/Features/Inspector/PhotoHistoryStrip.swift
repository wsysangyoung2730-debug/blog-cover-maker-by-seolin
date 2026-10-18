import ImageIO
import SwiftUI

struct PhotoHistoryStrip: View {
  @ObservedObject var store: EditorStore

  var body: some View {
    let history = store.photoHistory
    if !history.items.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Text("사진 기록").font(.caption).foregroundStyle(.secondary)
          Spacer(minLength: 0)
          Button { store.photoStep(-1) } label: {
            Image(systemName: "chevron.left")
          }.disabled(history.index <= 0).accessibilityLabel("이전 사진")
          Text("\(history.index + 1) / \(history.items.count)")
            .font(.caption).monospacedDigit().fixedSize()
          Button { store.photoStep(1) } label: {
            Image(systemName: "chevron.right")
          }.disabled(history.index >= history.items.count - 1).accessibilityLabel("다음 사진")
        }
        ScrollViewReader { proxy in
          ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
              ForEach(history.items.indices, id: \.self) { position in
                let imageID = history.items[position]
                let selected = position == history.index
                ZStack(alignment: .topTrailing) {
                  Button { store.selectPhoto(position) } label: {
                    PhotoHistoryThumbnail(imageID: imageID, data: imageID.flatMap { store.project.images[$0] })
                      .frame(width: 96, height: 80).clipped()
                      .overlay(alignment: .bottomLeading) {
                        if selected {
                          Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(5)
                        }
                      }
                      .clipShape(RoundedRectangle(cornerRadius: 8))
                      .overlay {
                        RoundedRectangle(cornerRadius: 8)
                          .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.3),
                                        lineWidth: selected ? 3 : 1)
                      }
                  }.buttonStyle(.plain)
                    .accessibilityLabel(imageID == nil ? "기본 사진" : "사진 \(position + 1)")
                    .accessibilityValue(selected ? "선택됨" : "")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                  Button { store.removePhoto(at: position) } label: {
                    Image(systemName: "xmark")
                      .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                      .frame(width: 22, height: 22)
                      .background(.black.opacity(0.7), in: Circle())
                      .frame(width: 44, height: 44).contentShape(Rectangle())
                  }.buttonStyle(.plain)
                    .accessibilityLabel("사진 \(position + 1) 기록 삭제")
                    .help("이 사진을 기록에서 삭제")
                }.id(position)
              }
            }.padding(.vertical, 3)
          }.scrollIndicators(.visible)
            .onAppear { proxy.scrollTo(history.index, anchor: .center) }
            .onChange(of: history) { _, value in
              withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(value.index, anchor: .center) }
            }
        }.frame(height: 94)
      }
    }
  }
}

private struct PhotoHistoryThumbnail: View {
  let imageID: String?
  let data: Data?
  @State private var image: CGImage?

  var body: some View {
    ZStack {
      Color.secondary.opacity(0.1)
      if let image {
        Image(decorative: image, scale: 1).resizable().scaledToFill()
      } else {
        VStack(spacing: 3) {
          Image(systemName: "photo")
          Text(imageID == nil ? "기본 사진" : "사진").font(.caption2)
        }.foregroundStyle(.secondary)
      }
    }.task(id: imageID) {
      image = nil
      guard let data else { return }
      let thumbnail = await PhotoHistoryThumbnailLoader.shared.image(data)
      guard !Task.isCancelled else { return }
      image = thumbnail
    }
  }
}

private actor PhotoHistoryThumbnailLoader {
  static let shared = PhotoHistoryThumbnailLoader()
  func image(_ data: Data) -> CGImage? {
    guard !Task.isCancelled, let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      return nil
    }
    return CGImageSourceCreateThumbnailAtIndex(source, 0, [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 192,
    ] as CFDictionary)
  }
}
