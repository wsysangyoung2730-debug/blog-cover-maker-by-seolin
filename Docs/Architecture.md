# 구조

macOS를 주력으로 하는 로컬 문서 편집 앱이다. iPadOS는 같은 템플릿, 문서 모델, 그리기·출력 엔진을 공유한다.

- App: SwiftUI 앱, 편집 화면, 플랫폼별 입력과 파일 창
- Sources/CoverCore: 문서 모델, 템플릿, 편집 연산, 이미지 렌더링
- Sources/CoverCore/Resources: 원본에서 추출한 50개 템플릿·22개 테마·폰트
- Reference/original.html: 수정하지 않는 원본과 결과 비교 기준
- Tests: 문서 저장, 편집 연산, 전체 템플릿 출력 검증
- Scripts: 원본 데이터 추출, Xcode 프로젝트 생성, 검증

편집 좌표와 PNG 출력은 항상 1080×1080을 기준으로 한다. 화면 미리보기와 출력은 같은 렌더러를 사용한다.

최소 지원: macOS 14, iPadOS 17. iPhone은 대상에 포함하지 않는다.
