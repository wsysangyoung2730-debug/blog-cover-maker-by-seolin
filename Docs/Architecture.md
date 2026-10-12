# 프로젝트 구조

macOS를 주력으로 하는 로컬 문서 편집 앱이다. iPadOS는 같은 템플릿, 문서 모델, 그리기·출력 엔진을 공유한다. 최소 지원은 macOS 14와 iPadOS 17이며 iPhone은 포함하지 않는다.

## 폴더별 책임

| 경로 | 책임 |
| --- | --- |
| `App/Application` | SwiftUI 앱 진입점, 문서 창 구성 |
| `App/Resources` | macOS·iPadOS 앱 아이콘 Asset Catalog |
| `App/Configuration` | Info.plist와 앱 메타데이터 |
| `App/Documents` | `.seolincover` 문서 직렬화와 PNG 파일 형식 |
| `App/Features/Editor` | 전체 편집 화면, 문서와 편집 상태 연결, 빠른 편집 UI |
| `App/Features/Editor/Canvas` | 공통 선택·이동·크기 조절과 네이티브 캔버스 연결 |
| `App/Features/DesignLibrary` | 디자인, 즐겨찾기, 테마 선택 |
| `App/Features/TextEditing` | 문구 입력과 글꼴 스타일 |
| `App/Features/Inspector` | 선택 요소 속성, 정렬·분배 |
| `App/Features/Layers` | 레이어 선택·순서·표시 상태 |
| `App/Features/Tutorial` | 문서와 독립적인 단계별 사용 안내·예시·진행 위치 보관 |
| `App/Features/Workspace` | 패널 배치·크기·접힘 설정 저장 |
| `App/Platforms/macOS` | AppKit 캔버스, 마우스·키보드 입력, 메뉴, 독립 빠른 편집창 |
| `App/Platforms/iPadOS` | UIKit 캔버스, 터치·Pencil·핀치 입력 |
| `App/Shared` | 재사용 조작 UI와 SwiftUI 확장 |
| `App/Support` | Debug 앱의 문서·Undo·PNG 검증 진입점 |
| `Sources/CoverCore/Models` | 문서, 요소, 템플릿·테마·글꼴 카탈로그 |
| `Sources/CoverCore/Editing` | 복제, 그룹, 정렬, 레이어, 사진 편집 연산 |
| `Sources/CoverCore/Rendering` | Core Graphics·Core Image 캔버스 및 PNG 출력 |
| `Sources/CoverCore/Typography` | 실제 글꼴 파일 로딩과 Core Text 배치 |
| `Sources/CoverCore/Resources` | 원본의 50개 템플릿·22개 테마·로고·17개 글꼴군 및 라이선스 |
| `Tests` | 공통 엔진 테스트 및 테스트 전용 폰트 자료 |
| `Reference` | 수정하지 않는 원본 HTML, 기능·결과 비교 기준 |
| `Scripts` | 원본 데이터 추출, 프로젝트 생성, 검증 |
| `Docs` | 구조, 기능 대응표, 확인한 검증과 한계 |
| `Design/Branding` | 앱 아이콘 원본·브랜드 참고 원본·제작 정보 |
| `.github` | 이슈·PR 양식과 자동 검증 |

## 코드 연결

앱 진입점은 문서 창을 만들고, 편집 화면은 `EditorStore`를 통해 문서 변경과 실행 취소를 관리한다. 기능별 화면과 플랫폼별 입력은 같은 편집 상태를 사용한다. 공통 모델·편집·렌더링 코드는 앱 화면이나 패널 구성에 의존하지 않는다.

Xcode 앱 타깃은 공통 소스를 직접 포함하며, `Package.swift`는 같은 `CoverCore`를 독립적으로 검증하는 데 사용한다. 별도 외부 Swift 패키지는 없다. 화면 미리보기와 PNG 출력은 동일한 렌더러를 사용하고 좌표 기준은 항상 1080×1080이다.

맥 전용 동작은 `Platforms/macOS`에, iPad 전용 동작은 `Platforms/iPadOS`에 둔다. 각 타깃에는 해당 플랫폼의 파일만 포함한다. iPad 화면의 제약 때문에 맥의 편집 기능을 줄이지 않는다. 공유 가능한 새 기능은 `Features`와 `CoverCore`에 추가한다.

## Xcode 탐색기와 프로젝트 생성

실제 폴더와 Xcode의 중첩 그룹을 일치시킨다. 파일명에는 긴 전체 경로가 표시되지 않는다. 소스나 리소스를 추가·이동한 뒤 `python3 Scripts/generate_project.py`를 실행하고 생성된 프로젝트 변경도 함께 커밋한다.

테스트 자료·문서·스크립트·원본·GitHub 설정은 탐색기에 표시하지만 앱 빌드 대상에는 넣지 않는다. 앱 리소스는 개별 파일로 복사하므로 기존 번들 탐색 방식을 유지한다. 프로젝트 재생성 시 기존 빌드·서명 설정을 보존하고, `INFOPLIST_FILE` 경로는 관리되는 위치로 맞춘다. 같은 입력으로 재생성한 프로젝트는 동일해야 한다.

Asset Catalog는 하나의 Xcode 리소스로 등록하고 내부 PNG·Contents.json을 별도 리소스로 복사하지 않는다. 타깃별 AppIconMac·AppIconPad를 지정해 컴파일된 앱에 아이콘을 포함한다.
