# 구조

macOS를 주력으로 하는 로컬 문서 편집 앱이다. iPadOS는 같은 템플릿, 문서 모델, 그리기·출력 엔진을 공유한다.

- App/Application: SwiftUI 앱 진입점과 macOS 메뉴
- App/Configuration: 앱 Info.plist
- App/Documents: 네이티브 문서와 PNG 파일 형식
- App/Features/Editor: 편집 화면 진입점, Canvas 입력·표시, Panels 편집 도구, State 편집 상태·작업 화면 설정
- App/Shared/Extensions: 공통 SwiftUI 확장
- App/Support: Debug 앱의 문서·Undo·출력 검증
- Sources/CoverCore: 문서 모델, 템플릿, 편집 연산, 이미지 렌더링
- Sources/CoverCore/Resources: 원본에서 추출한 50개 템플릿·22개 테마·폰트
- Reference/original.html: 수정하지 않는 원본과 결과 비교 기준
- Tests: 문서 저장, 편집 연산, 전체 템플릿 출력 검증
- Scripts: 원본 데이터 추출, Xcode 프로젝트 생성, 검증

편집 좌표와 PNG 출력은 항상 1080×1080을 기준으로 한다. 화면 미리보기와 출력은 같은 렌더러를 사용한다.

최소 지원: macOS 14, iPadOS 17. iPhone은 대상에 포함하지 않는다.

## Xcode 폴더 표시

`Scripts/generate_project.py`는 실제 디렉터리에 대응하는 중첩 그룹을 만든다. 파일 참조에는 파일명만 기록하고 상위 그룹을 기준으로 경로를 해석한다. 소스를 추가하거나 이동한 뒤 생성 스크립트를 다시 실행하고 프로젝트 파일도 함께 커밋한다.

테스트·Fixtures·문서·스크립트·원본은 탐색기에 표시하되 앱 빌드 대상에 넣지 않는다. 앱 리소스는 기존과 동일하게 개별 파일로 복사하므로 폰트·카탈로그·로고의 번들 탐색 방식은 유지된다. 프로젝트 재생성 시 기존 빌드 설정과 서명 설정을 보존하며, `INFOPLIST_FILE`만 관리되는 새 경로로 맞춘다.
