import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct PropertiesPanel: View {
  @ObservedObject var store: EditorStore
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let element = store.inspected.first {
        Text(store.inspected.count > 1 ? "\(store.inspected.count)개 선택" : element.name).font(
          .subheadline.bold())
        if store.selected.isEmpty {
          Text("마지막 사진 설정 · 요소를 선택하면 바뀝니다.").font(.caption).foregroundStyle(.secondary)
        }
        if let photo = store.photo {
          Button("표지 사진 고르기", systemImage: "photo.badge.plus") {
            store.importKind = .replace
          }.buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
          Button("로고 추가", systemImage: "plus") { store.importKind = .add }
          if photo.values["src"]?.string != nil { Button("기본 사진으로 되돌리기") { store.useMainPhoto() } }
          let history = store.photoHistory
          if history.items.count > 1 {
            HStack {
              Button {
                store.photoStep(-1)
              } label: {
                Image(systemName: "chevron.left")
              }.disabled(history.index <= 0)
              Text("\(history.index+1) / \(history.items.count)").monospacedDigit()
              Button {
                store.photoStep(1)
              } label: {
                Image(systemName: "chevron.right")
              }.disabled(history.index >= history.items.count - 1)
              Spacer()
              Text("사진 기록").font(.caption).foregroundStyle(.secondary)
            }
          }
          VStack(alignment: .leading, spacing: 8) {
            Text(store.panMode ? "사진 안쪽 위치 맞추기" : "사진 위치 맞추기").font(.caption.bold())
            AlignmentControls(store: store)
            ViewThatFits(in: .horizontal) {
              HStack { photoPositionButtons(photo) }
              VStack(alignment: .leading) { photoPositionButtons(photo) }
            }
          }
          numeric("사진 확대", "zoom", 20...300, multiplier: 100, unit: "%")
        }
        let textIDs = Set(store.inspected.filter { $0.type == "text" }.map(\.id))
        if !textIDs.isEmpty {
          if store.inspected.count == 1 {
            Button("표지에서 글씨 고치기") { store.startText(element.id) }
            numeric("글씨 크기", "size", 8...400)
          }
          FontPicker(store: store, ids: textIDs)
          TextStyleControls(store: store, ids: textIDs)
        }
        if store.inspected.contains(where: { $0.colorKey != nil }) {
          SwatchPicker(
            store: store, token: element.colorKey.map { element.string($0, "#fff") } ?? "#fff"
          ) { store.setColor($0, ids: Set(store.inspected.map(\.id))) }
        }
        numeric("투명도", "opacity", 0...100, multiplier: 100, unit: "%")
        if store.inspected.count == 1 {
          numeric("흐리게", "blur", 0...60)
          numeric("회전", "rot", -180...180, unit: "°")
        }
        Divider()
        if store.photo == nil {
          Text("요소 위치 맞추기").font(.caption.bold())
          AlignmentControls(store: store)
        }
        if !store.selection.isEmpty {
          HStack {
            Button("복제") { store.duplicate() }
            Button("삭제", role: .destructive) { store.delete() }
            Spacer()
            Button("빠른 편집") { store.showQuick = true }
          }
          HStack {
            Button("그룹 묶기") { store.group() }.disabled(store.selected.count < 2)
            Button("그룹 풀기") { store.ungroup() }.disabled(
              !store.selected.contains { $0.group != nil })
          }
          Button("같은 종류 선택") { store.selectSame() }
        }
      } else {
        Text("사진을 넣거나 표지의 요소를 선택하세요.").foregroundStyle(.secondary)
        Button("표지 사진 고르기", systemImage: "photo.badge.plus") {
          store.importKind = .base
        }.buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
        Button("로고 추가") { store.importKind = .add }
      }
    }.buttonStyle(.bordered)
  }
  @ViewBuilder private func photoPositionButtons(_ photo: CoverElement) -> some View {
    Button(store.panMode ? "위치 맞추기 완료" : "사진 안쪽 위치 조절") {
      store.select(photo.id, individual: true)
      store.panMode.toggle()
    }
    Button("처음 위치로") { store.resetPhoto() }
  }
  private func numeric(
    _ title: String, _ key: String, _ range: ClosedRange<Double>, multiplier: Double = 1,
    unit: String = ""
  ) -> some View {
    NumberControl(
      title: title,
      value: Binding(
        get: {
          guard let e = store.inspected.first else { return range.lowerBound }
          if key == "opacity" { return store.project.opacity(for: e) * multiplier }
          if key == "size" { return CoverTypography.layout(e, project: store.project).size }
          return e.number(key, key == "zoom" ? 1 : 0) * multiplier
        },
        set: { store.setNumber(key, max(range.lowerBound, min(range.upperBound, $0)) / multiplier) }
      ), range: range, unit: unit,
      editing: { editing in editing ? store.begin() : store.end("속성 변경") })
  }
}
struct AlignmentControls: View {
  @ObservedObject var store: EditorStore
  private let items = [
    ("l", "왼쪽", "align.horizontal.left"), ("c", "가로 가운데", "align.horizontal.center"),
    ("r", "오른쪽", "align.horizontal.right"), ("t", "위", "align.vertical.top"),
    ("m", "세로 가운데", "align.vertical.center"), ("b", "아래", "align.vertical.bottom"),
  ]
  var body: some View {
    VStack {
      HStack {
        ForEach(items, id: \.0) { key, title, icon in
          Button {
            store.align(key)
          } label: {
            Image(systemName: icon).frame(maxWidth: .infinity)
          }.help(title).accessibilityLabel(title)
        }
      }
      if CoverEditing.units(store.inspected).count >= 3 {
        HStack {
          Button("가로 간격 고르게") { store.align("dh") }
          Button("세로 간격 고르게") { store.align("dv") }
        }
      }
    }
  }
}
