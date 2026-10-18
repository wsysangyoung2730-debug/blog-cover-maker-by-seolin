import SwiftUI

enum TutorialStep: Int, CaseIterable, Identifiable {
  case welcome, photo, design, text, layout, document, export
  var id: Int { rawValue }

  var label: String {
    switch self {
    case .welcome: "화면 익히기"
    case .photo: "사진 불러오기"
    case .design: "디자인 고르기"
    case .text: "문구 편집하기"
    case .layout: "배치 다듬기"
    case .document: "작업 저장하기"
    case .export: "PNG 내보내기"
    }
  }

  var symbol: String {
    switch self {
    case .welcome: "rectangle.3.group"
    case .photo: "photo.badge.plus"
    case .design: "square.grid.2x2"
    case .text: "textformat"
    case .layout: "square.3.layers.3d"
    case .document: "doc.badge.arrow.up"
    case .export: "square.and.arrow.up"
    }
  }

  var title: String {
    switch self {
    case .welcome: "첫 표지, 함께 만들어 볼까요?"
    case .photo: "이야기의 시작은 사진 한 장"
    case .design: "사진에 어울리는 디자인 찾기"
    case .text: "전하고 싶은 말을 담아보세요"
    case .layout: "위치와 순서를 내 취향대로"
    case .document: "다음에도 이어서 편집하려면"
    case .export: "완성한 표지를 이미지로"
    }
  }

  var subtitle: String {
    switch self {
    case .welcome: "사진부터 저장까지, 일곱 단계로 편집 흐름을 익혀보세요."
    case .photo: "기본 사진을 넣으면 여러 디자인에 같은 사진이 반영돼요."
    case .design: "50종 디자인과 22종 테마로 표지의 분위기를 바꿔보세요."
    case .text: "제목과 부제목을 바꾸고 글씨체·색·크기를 조절해요."
    case .layout: "사진·글씨·장식을 선택하면 더 자세히 편집할 수 있어요."
    case .document: "편집용 문서에는 사진·문구·배치·추가 폰트가 함께 들어가요."
    case .export: "블로그에 올릴 때는 1080 × 1080 PNG로 내보내세요."
    }
  }

  struct Instruction: Identifiable {
    let title: String
    let detail: String
    var id: String { title }
    init(_ title: String, _ detail: String) {
      self.title = title
      self.detail = detail
    }
  }

  var instructions: [Instruction] {
    switch self {
    case .welcome:
      #if os(macOS)
        return [
          .init("왼쪽에서 디자인, 가운데에서 결과", "오른쪽 문구·사진·레이어 패널에서 세부 내용을 고쳐요."),
          .init("상단 도구막대에서 시작", "기본 사진을 넣고, 추가·실행 취소·내보내기를 이용해요."),
          .init("필요할 때 다시 열기", "도구막대 ‘튜토리얼’ 또는 도움말 → 사용 튜토리얼에서 돌아오세요."),
        ]
      #else
        return [
          .init("표지는 가운데에서 확인", "넓은 화면에서는 양옆 패널, 좁은 화면에서는 하단 버튼을 사용해요."),
          .init("상단 도구막대에서 시작", "기본 사진을 넣고, 추가·실행 취소·내보내기를 이용해요."),
          .init("필요할 때 다시 열기", "도구막대의 물음표 ‘튜토리얼’에서 언제든 돌아올 수 있어요."),
        ]
      #endif
    case .photo:
      return [
        .init("‘표지 사진 고르기’ 선택", "노란색 ‘표지 사진 고르기’를 누르고 이미지 파일을 골라요."),
        .init(
          "틀 안의 위치 맞추기",
          platform(
            "사진을 두 번 클릭하고 안쪽 이미지를 끌어보세요. 마우스 휠로 확대해요.", "사진을 두 번 탭한 뒤 끌어서 위치를 맞추고, 두 손가락으로 확대해요.")),
        .init("다른 사진이나 로고도 추가", "‘추가 → 로고 추가’로 별도 이미지를 올릴 수 있어요."),
      ]
    case .design:
      return [
        .init("‘디자인’에서 미리보기 선택", "전체·즐겨찾기와 이름 검색을 이용하고, 미리보기 바로 위 막대로 크기를 조절해요."),
        .init("테마와 밝기 조절", "색상 원을 골라 전체 분위기를 바꾸고 밝기를 조절해요."),
        .init("자주 쓰는 디자인은 별표", "미리보기의 별을 누르면 즐겨찾기에서 모아볼 수 있어요."),
      ]
    case .text:
      return [
        .init("‘문구’ 패널에서 내용 입력", "현재 디자인에서 쓰는 제목·부제목 등의 입력칸이 활성화돼요."),
        .init(
          "표지 위에서 바로 수정",
          platform("글씨를 두 번 클릭해 편집하고 ‘완료’를 누르세요. Esc로 취소할 수 있어요.", "글씨를 두 번 탭해 편집한 다음 ‘완료’를 누르세요.")),
        .init("글씨체와 스타일 선택", "글씨를 선택하면 크기·색·굵기 등을 바꿀 수 있어요. ‘추가 → 폰트 추가’도 지원해요."),
      ]
    case .layout:
      return [
        .init("요소 이동과 크기 조절", "글씨·사진·장식을 끌어 이동하고 모서리 핸들로 크기를 바꿔요."),
        .init(
          "여러 요소를 함께 선택",
          platform(
            "Shift 또는 Command를 누른 채 클릭하세요. 요소 메뉴에서 그룹으로 묶을 수 있어요.",
            "‘여러 개 선택’을 켜고 요소를 탭하세요. 선택한 요소들을 함께 움직일 수 있어요.")),
        .init("레이어에서 앞뒤 순서 조절", "레이어를 끌어 순서를 바꾸고 눈 아이콘으로 잠시 숨겨보세요."),
      ]
    case .document:
      return [
        .init(
          "편집용 문서 저장",
          platform(
            "파일 → 저장 또는 ⌘S를 누르고 이름과 위치를 정하세요.",
            "문서 제목 메뉴에서 이름과 위치를 관리해요. 문서 브라우저로 돌아가 파일을 확인할 수 있어요.")),
        .init("다음 작업은 문서에서 이어가기", "저장된 .seolincover 파일을 열면 사진과 문구를 다시 편집할 수 있어요."),
        .init("맥과 iPad에서 같은 문서 사용", "파일 앱이나 iCloud Drive 등으로 문서를 옮겨 다른 기기에서 열 수 있어요."),
      ]
    case .export:
      return [
        .init("상단 ‘내보내기’ 선택", "한 장의 완성된 표지가 필요하면 ‘표지 전체 PNG’를 골라요."),
        .init("용도에 따라 따로 저장", "‘배경만’과 ‘글씨·장식만’을 나눠 내보낼 수도 있어요."),
        .init("파일 이름과 저장 위치 확인", "PNG를 저장한 뒤 블로그나 다른 편집 도구에서 사용하세요."),
      ]
    }
  }

  var tip: String {
    switch self {
    case .welcome: "이 화면은 사용법 안내예요. 단계 이동이나 닫기로 작업 중인 표지가 바뀌지 않아요."
    case .photo: "사진·요소 패널에서 이전·다음 사진 기록을 확인하거나 위치를 처음 상태로 되돌릴 수 있어요."
    case .design: "디자인을 바꾸면 수동 배치와 추가 요소가 초기화돼요. 실수했다면 실행 취소로 돌아오세요."
    case .text: "원하는 문구 칸이 비활성화돼 있다면, 그 문구를 사용하는 디자인으로 바꿔보세요."
    case .layout:
      platform(
        "⌘Z 실행 취소 · ⇧⌘Z 다시 실행 · ⌘D 복제. ‘보기 → 빠른 편집창’도 활용해보세요.",
        "실수했다면 상단 되돌리기 화살표를 누르세요. 보기 메뉴에서 빠른 편집창도 열 수 있어요.")
    case .document: "문서는 다시 편집하기 위한 파일이에요. 블로그에 올릴 이미지가 필요하면 다음 단계에서 PNG로 내보내세요."
    case .export: "PNG는 완성된 이미지예요. 글씨·사진을 따로 수정할 수 있도록 편집용 문서도 함께 보관하세요."
    }
  }

  private func platform(_ mac: String, _ pad: String) -> String {
    #if os(macOS)
      mac
    #else
      pad
    #endif
  }
}
