import SwiftUI

struct TutorialView: View {
  var completionTitle = "편집 시작하기"
  @Environment(\.dismiss) private var dismiss
  @AppStorage("seolin.tutorial.step") private var savedStep = 0
  private var step: TutorialStep { TutorialStep(rawValue: savedStep) ?? .welcome }
  private var isLast: Bool { step == .export }

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        Divider()
        HStack(spacing: 0) {
          if geometry.size.width >= 760 {
            stepList.frame(width: 190)
            Divider()
          }
          ScrollView {
            VStack(alignment: .leading, spacing: 20) {
              if geometry.size.width < 760 { stepMenu }
              VStack(alignment: .leading, spacing: 8) {
                Text(
                  String(format: "STEP %02d / %02d", step.rawValue + 1, TutorialStep.allCases.count)
                )
                .font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(Color.accentColor)
                Text(step.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                  .accessibilityAddTraits(.isHeader)
                Text(step.subtitle).font(.subheadline).foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              TutorialPreview(step: step).frame(height: 148).accessibilityHidden(true)
              VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(step.instructions.enumerated()), id: \.element.id) {
                  index, instruction in
                  HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)").font(.caption.bold()).foregroundStyle(Color.accentColor)
                      .frame(width: 24, height: 24)
                      .background(Color.accentColor.opacity(0.1), in: Circle())
                      .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                      Text(instruction.title).font(.subheadline.bold())
                      Text(instruction.detail).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                  }.accessibilityElement(children: .combine)
                }
              }
              Label {
                Text(step.tip).font(.caption).fixedSize(horizontal: false, vertical: true)
              } icon: {
                Image(systemName: "lightbulb")
              }.foregroundStyle(.secondary).padding(12).frame(
                maxWidth: .infinity, alignment: .leading
              )
              .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            }.padding(24).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
              .id(step)
          }
        }
        Divider()
        footer
      }
    }
    #if os(macOS)
      .frame(
        minWidth: 800, idealWidth: 880, maxWidth: 1000, minHeight: 640, idealHeight: 700,
        maxHeight: 850)
    #else
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    #endif
    .onAppear { savedStep = step.rawValue }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: "book.closed.fill").font(.title3).foregroundStyle(Color.accentColor)
        .frame(width: 40, height: 40)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 3) {
        Text("사용 튜토리얼").font(.headline)
        Text("BLOG COVER MAKER by SEOLIN").font(.caption2).foregroundStyle(.secondary)
      }
      Spacer()
      Button("닫기", systemImage: "xmark") { dismiss() }
        .labelStyle(.iconOnly).buttonStyle(.borderless).keyboardShortcut(.cancelAction)
        .help("튜토리얼 닫기 · 보던 단계는 기억해요")
        .accessibilityIdentifier("closeTutorial")
    }.padding(.horizontal, 24).padding(.vertical, 18)
  }

  private var stepList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 6) {
        Text("표지 만들기").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          .padding(.horizontal, 12).padding(.bottom, 8)
        ForEach(TutorialStep.allCases) { item in
          Button {
            savedStep = item.rawValue
          } label: {
            HStack(spacing: 10) {
              Image(systemName: item.symbol).frame(width: 20)
              Text(item.label).font(.subheadline)
              Spacer(minLength: 0)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
              .foregroundStyle(item == step ? Color.accentColor : Color.primary)
              .background(
                item == step ? Color.accentColor.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: 9))
          }.buttonStyle(.plain)
            .accessibilityLabel("\(item.rawValue + 1)단계, \(item.label)")
            .accessibilityAddTraits(item == step ? [.isSelected] : [])
            .accessibilityIdentifier("tutorialStep\(item.rawValue)")
        }
      }.padding(14).padding(.top, 10)
    }.background(Color.primary.opacity(0.025))
  }

  private var stepMenu: some View {
    Menu {
      ForEach(TutorialStep.allCases) { item in
        Button("\(item.rawValue + 1). \(item.label)", systemImage: item.symbol) {
          savedStep = item.rawValue
        }
      }
    } label: {
      Label("단계 선택", systemImage: "list.bullet").font(.subheadline)
    }
  }

  private var footer: some View {
    HStack(spacing: 12) {
      Button("이전") { savedStep = max(0, step.rawValue - 1) }
        .disabled(step == .welcome).keyboardShortcut(.leftArrow, modifiers: [])
      Spacer()
      Text("\(step.rawValue + 1) / \(TutorialStep.allCases.count)")
        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        .accessibilityLabel("전체 \(TutorialStep.allCases.count)단계 중 \(step.rawValue + 1)단계")
      Spacer()
      Button(isLast ? completionTitle : "다음") {
        if isLast {
          savedStep = 0
          dismiss()
        } else {
          savedStep = step.rawValue + 1
        }
      }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("tutorialNext")
    }.controlSize(.large).padding(.horizontal, 24).padding(.vertical, 16)
  }
}
