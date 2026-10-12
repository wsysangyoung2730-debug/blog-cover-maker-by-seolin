#if os(iOS)
  import SwiftUI

  /// Keep document creation, recents, Files access, and autosaving owned by the
  /// system. The accessory content frames the native primary action.
  @available(iOS 18.0, *)
  struct PadLaunchScene: Scene {
    var body: some Scene {
      DocumentGroupLaunchScene(Text("")) {
        NewDocumentButton("새 표지 만들기")
          .accessibilityIdentifier("createCover")
      } background: {
        PadLaunchBackground()
      } overlayAccessoryView: { geometry in
        PadLaunchWelcome(geometry: geometry)
      }
    }
  }

  private struct PadLaunchBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
      LinearGradient(
        colors: colorScheme == .dark
          ? [Color(red: 0.08, green: 0.11, blue: 0.20), Color(.systemBackground)]
          : [Color(red: 0.91, green: 0.94, blue: 1), Color(.systemBackground)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
    }
  }

  @available(iOS 18.0, *)
  private struct PadLaunchWelcome: View {
    let geometry: DocumentLaunchGeometryProxy
    @State private var showsTutorial = false
    @AppStorage("seolin.tutorial.presentedVersion") private var tutorialVersion = 0

    var body: some View {
      // The collapsed document browser occupies the lower half of the scene.
      // Its launch card centers the native action in the upper half. Reserve
      // that action's touch area and adapt the surrounding content separately.
      let top = max(geometry.frame.minY, geometry.titleViewFrame.minY)
      let bottom = geometry.frame.midY
      let center = (top + bottom) / 2
      let width = max(0, min(540, geometry.titleViewFrame.width - 32))
      let sectionHeight = max(0, (bottom - top) / 2 - 60)

      ZStack {
        ViewThatFits(in: .vertical) {
          introduction(showIcon: true)
          introduction(showIcon: false)
          ScrollView { introduction(showIcon: false) }
        }
        .frame(width: width, height: sectionHeight)
        .position(x: geometry.frame.midX, y: top + sectionHeight / 2 + 8)

        ScrollView {
          VStack(spacing: 20) {
            Button("사용법 보기", systemImage: "book.closed") {
              tutorialVersion = 1
              showsTutorial = true
            }
            .buttonStyle(.borderless).controlSize(.large)
            .frame(minHeight: 44)
            .accessibilityIdentifier("launchTutorial")
            Text("저장한 표지는 아래 ‘최근 항목’이나 ‘둘러보기’에서 열어요.")
              .font(.caption).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: width, height: sectionHeight)
        .position(x: geometry.frame.midX, y: center + 52 + sectionHeight / 2)
      }
      .sheet(isPresented: $showsTutorial) {
        TutorialView(completionTitle: "시작 화면으로")
      }
    }

    private func introduction(showIcon: Bool) -> some View {
      VStack(spacing: 16) {
        if showIcon {
          Image("LaunchIcon")
            .resizable().scaledToFit()
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .shadow(color: .black.opacity(0.1), radius: 12, y: 5)
            .accessibilityHidden(true)
        }
        VStack(spacing: 10) {
          Text("BLOG COVER MAKER · SEOLIN")
            .font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
          Text("나만의 블로그 표지")
            .font(.title.bold()).accessibilityAddTraits(.isHeader)
          Text("사진과 문구를 담아, 한 장의 표지로 완성하세요.")
            .font(.body).foregroundStyle(.secondary)
        }
      }
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
    }
  }
#endif
