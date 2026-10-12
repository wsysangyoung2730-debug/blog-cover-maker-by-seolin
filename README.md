# BLOG COVER MAKER by SEOLIN

**macOS를 주력으로 하는 Swift 블로그 표지 편집 앱**입니다. iPadOS는 같은 문서·템플릿·출력 엔진을 공유하며 터치에 맞춘 화면을 제공합니다.

원본 HTML의 50종 디자인, 22종 테마, 사진·문구·레이어·그룹·정렬·폰트 편집과 PNG 분리 출력을 네이티브 코드로 옮겼습니다. 편집 화면은 SwiftUI, 맥 입력은 AppKit, iPad 입력은 UIKit, 공통 그리기는 Core Graphics·Core Text·Core Image를 사용합니다. WebView는 사용하지 않습니다.

## 시작하기

1. `develop` 브랜치를 받습니다.
2. `BlogCoverMakerBySeolin.xcodeproj`를 Xcode에서 엽니다.
3. **BlogCoverMakerMac → My Mac**을 선택하고 실행합니다.
4. 시작 창에서 **New Document**를 누르면 편집기가 열립니다.

- 주력 타깃: `BlogCoverMakerMac` (macOS 14 이상)
- 보조 타깃: `BlogCoverMakerPad` (iPadOS 17 이상, iPhone 제외)
- iPad 확인: `BlogCoverMakerPad` 스킴에서 iPad 시뮬레이터를 선택합니다.
- 실기기 실행·배포 시 Xcode의 Signing & Capabilities에서 본인 개발 팀을 선택합니다.
- 별도 서버·API 키·외부 Swift 패키지가 필요하지 않습니다. 기본 폰트도 앱에 포함됩니다.

## 작업 흐름

- **기본 사진**을 넣고 왼쪽에서 디자인을 고릅니다.
- 오른쪽에서 문구를 입력하거나 표지의 글씨를 두 번 눌러 직접 고칩니다.
- 사진을 두 번 누르거나 **위치 맞추기**를 선택하면 틀 안에서 사진을 움직입니다.
- 우측 레이어 목록에서 순서·표시 상태를 관리합니다.
- **파일 → 저장**으로 사진·추가 폰트가 포함된 `.seolincover` 문서를 저장합니다.
- **내보내기**에서 전체 / 배경 / 글씨·장식 PNG를 각각 저장합니다.
- 화면 구성이 좁은 iPad에서는 하단 버튼으로 디자인·사진·문구·레이어 패널을 엽니다.

프로젝트 저장은 PNG 내보내기와 별개입니다. 원본의 ‘글씨만 저장’은 일부 전경 장식도 포함하므로 앱에서는 **글씨·장식만**으로 표시합니다.

## 맥 조작

| 조작 | 기능 |
| --- | --- |
| Command + S / O / N | 문서 저장 / 열기 / 새 문서 |
| Command + Z / Shift + Command + Z | 실행 취소 / 다시 실행 |
| Command + D | 선택 요소 복제 |
| Command + G / Shift + Command + G | 그룹 묶기 / 풀기 |
| Command + A | 캔버스에서 선택 가능한 요소 전체 선택 |
| Shift·Command + 클릭 | 다중 선택 |
| Option + 클릭 | 그룹 안의 개별 요소 선택 |
| 방향키 / Shift + 방향키 | 1 / 10픽셀 이동 |
| Delete | 선택 요소 삭제 |
| 사진 위 마우스 휠 | 사진 확대·축소 |
| 빈 공간 드래그 | 범위 선택 |
| Shift + 모서리 드래그 | 사진·도형 비율 유지 |

빠른 편집창은 이동·너비 조절·접기가 가능합니다. 패널의 손잡이를 다른 열로 끌어 작업 화면을 구성할 수 있습니다. 즐겨찾기와 패널 배치·접힘·열 너비는 앱 설정에 보관합니다.

## 구조

```text
App/
├── Application/               앱 진입점과 메뉴
├── Configuration/             Info.plist
├── Documents/                 문서 저장·열기 형식
├── Features/Editor/           편집 화면
│   ├── Canvas/                macOS·iPadOS 캔버스와 입력 처리
│   ├── Panels/                편집 패널과 빠른 편집창
│   └── State/                 편집 상태와 작업 화면 설정
├── Shared/Extensions/         공통 SwiftUI 확장
└── Support/                   Debug 편집 검증
Sources/CoverCore/             공통 문서·편집·텍스트·그리기 엔진
└── Resources/                 디자인 데이터와 로고
    └── Fonts/                 기본 폰트·라이선스·목록
Tests/CoverCoreTests/          공통 엔진 테스트와 Fixtures
Reference/original.html        변경하지 않은 원본
Scripts/                      데이터 추출·프로젝트 생성
Docs/                         구조·기능 대응표·검증 기록
```

프로젝트 파일은 커밋되어 있어 별도 생성 도구 없이 열 수 있습니다. Swift 소스나 리소스를 추가한 경우 `python3 Scripts/generate_project.py`로 프로젝트 참조를 갱신합니다. Xcode 그룹은 실제 폴더 구조와 동일하게 생성되며, 기존 개발 팀·서명·버전 설정은 유지됩니다.

## 검증

```sh
swift test
xcodebuild -project BlogCoverMakerBySeolin.xcodeproj -scheme BlogCoverMakerMac -derivedDataPath .build-output CODE_SIGNING_ALLOWED=NO build
xcodebuild -project BlogCoverMakerBySeolin.xcodeproj -scheme BlogCoverMakerPad -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath .build-output CODE_SIGNING_ALLOWED=NO build
.build-output/Build/Products/Debug/BlogCoverMakerMac.app/Contents/MacOS/BlogCoverMakerMac --verify-editor .build-output/verification
```

마지막 명령은 Debug 앱의 문서·Undo 검증 경로입니다. 사용자 문서를 건드리지 않고 지정 폴더에 테스트 프로젝트, PNG 세 종류, 디자인 50종의 미리보기를 만듭니다.

- [기능 대응표](Docs/FeatureParity.md)
- [검증 기록과 범위](Docs/Validation.md)
- [구조](Docs/Architecture.md)
- [개발 규칙](AGENTS.md)

네이티브 렌더러와 브라우저의 글꼴·그림자 처리 차이가 있어 픽셀 단위의 동일성을 보장하지는 않습니다. 실제 기기별 터치·Pencil 사용성과 모든 디자인의 시각적 미세 조정은 지속 검수 대상입니다.

## Git 규칙

- 출시: `main`, 개발 통합: `develop`
- 작업 브랜치: `태그/#이슈번호-작업범위`
- 커밋: `[소문자 태그] 한글 명령조`, 제목 50자 이내
- 태그: `init`, `feat`, `fix`, `docs`, `setting`, `add`, `refactor`, `chore`
- 작업 브랜치에 최신 `develop`을 병합하고 검증한 뒤 `develop` 대상 PR로 통합합니다.
- `init`은 최초 커밋에만 사용합니다.

## 폰트

원본의 Google Fonts 17개 글꼴군과 각 OFL 라이선스를 포함합니다. 다운로드 주소와 SHA-256은 `Sources/CoverCore/Resources/Fonts/font-manifest.json`에 기록되어 있습니다. 사용자 추가 폰트는 프로젝트 문서 안에 보관됩니다.
