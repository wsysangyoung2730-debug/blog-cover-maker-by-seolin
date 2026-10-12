import SwiftUI

/// Illustrations for the guide; they never read or mutate the open document.
struct TutorialPreview: View {
  let step: TutorialStep
  private let ink = Color(red: 0.16, green: 0.28, blue: 0.29)

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.055))
      switch step {
      case .welcome, .photo, .text, .layout:
        HStack(spacing: 24) {
          poster
          VStack(alignment: .leading, spacing: 10) {
            Image(systemName: step.symbol).font(.title2).foregroundStyle(Color.accentColor)
            Text(previewTitle).font(.subheadline.bold())
            Text(previewDetail).font(.caption).foregroundStyle(.secondary)
          }
        }.padding(16)
      case .design:
        HStack(spacing: 16) {
          ForEach(0..<3) { index in
            VStack(spacing: 8) {
              ZStack {
                RoundedRectangle(cornerRadius: 6).fill(
                  [Color.teal, .orange, .indigo][index].opacity(0.18))
                Image(systemName: ["photo", "rectangle.inset.filled", "square.split.2x1"][index])
                  .font(.largeTitle).foregroundStyle([Color.teal, .orange, .indigo][index])
              }.frame(maxWidth: 92).frame(height: 76)
                .overlay(
                  RoundedRectangle(cornerRadius: 6).stroke(
                    index == 0 ? Color.accentColor : .clear, lineWidth: 2))
              Text(["사진 가득", "액자·카드", "화면 나누기"][index]).font(.caption)
            }
          }
        }.padding(16)
      case .document:
        HStack(spacing: 20) {
          Image(systemName: "doc.richtext").font(.system(size: 52)).foregroundStyle(
            Color.accentColor)
          VStack(alignment: .leading, spacing: 9) {
            Text("나의 첫 표지.seolincover").font(.subheadline.bold())
            Text("사진 + 문구 + 배치 + 폰트").font(.caption).foregroundStyle(.secondary)
            Label("다시 열어 편집할 수 있어요", systemImage: "pencil").font(.caption)
          }
        }.padding(20)
      case .export:
        HStack(spacing: 20) {
          ForEach(["전체", "배경만", "글씨·장식만"], id: \.self) { title in
            VStack(spacing: 9) {
              Image(
                systemName: title == "전체" ? "photo.fill" : title == "배경만" ? "photo" : "textformat"
              )
              .font(.title).foregroundStyle(Color.accentColor)
              .frame(width: 68, height: 64).background(
                .background, in: RoundedRectangle(cornerRadius: 8))
              Text(title).font(.caption.bold())
              Text("PNG").font(.caption2).foregroundStyle(.secondary)
            }
          }
        }.padding(12)
      }
    }.overlay(alignment: .topTrailing) {
      Text("예시").font(.system(size: 9)).foregroundStyle(.tertiary).padding(10)
    }
  }

  private var poster: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.93, green: 0.94, blue: 0.87))
      VStack(spacing: 6) {
        ZStack {
          Rectangle().fill(ink.opacity(0.12))
          Image(systemName: "mountain.2.fill").font(.system(size: 30)).foregroundStyle(
            ink.opacity(0.5))
        }.frame(height: 58).clipped()
        Text("우리의 빛나는 하루").font(.system(size: 10, weight: .bold)).foregroundStyle(ink)
          .padding(3).overlay(
            Rectangle().stroke(step == .text ? Color.accentColor : .clear, lineWidth: 1.5))
        Text("STORIES BY SEOLIN").font(.system(size: 5, weight: .medium)).tracking(1)
          .foregroundStyle(ink)
      }.padding(10)
      if step == .layout {
        Rectangle().stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [3]))
          .padding(5)
        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption2)
          .foregroundStyle(Color.accentColor).frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      }
    }.frame(width: 116, height: 116).shadow(color: .black.opacity(0.08), radius: 5, y: 2)
  }

  private var previewTitle: String {
    switch step {
    case .photo: "사진 한 장으로 시작"
    case .text: "나만의 제목으로"
    case .layout: "조금 더 내 취향으로"
    default: "사진 → 디자인 → 문구"
    }
  }
  private var previewDetail: String {
    switch step {
    case .photo: "사진을 넣고 위치를 맞춰요."
    case .text: "글씨를 직접 눌러 수정해요."
    case .layout: "선택하고, 끌고, 정렬해요."
    default: "완성한 표지를 저장해요."
    }
  }
}
