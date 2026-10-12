# App Store 한국어 스크린샷

완성본은 `ko-KR/macOS` 4장과 `ko-KR/iPadOS` 4장이다. 같은 번호 순서로 App Store Connect의 각 플랫폼에 등록한다. 영상 App Preview가 아닌 정지 스크린샷이다. 생성일: 2026-10-13.

| 순서 | 파일 | 보여주는 기능 |
| --- | --- | --- |
| 1 | 01-cover-editor.png | 사진과 문구로 표지 편집 |
| 2 | 02-design-library.png | 카드형 디자인·테마 선택 |
| 3 | 03-typography.png | 폴라로이드 디자인과 고운바탕 글씨체 |
| 4 | 04-tutorial.png | 7단계 사용 튜토리얼 |

- **Mac 주력**: 2880×1800, 16:10, 8-bit RGB PNG, sRGB, 불투명.
- **iPad**: 13형 iPad Pro 시뮬레이터, 2064×2752 세로, 8-bit RGB PNG, sRGB, 불투명.
- [Apple 스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)을 기준으로 크기·형식·투명도를 확인했다. 실제 업로드·심사 승인은 별도다.

## 이미지 출처와 실제 화면

`Source/taekwondo-lesson.png`는 사용자가 요청한 ‘태권도장에서 관장님이 아이를 지도하는 실사 스타일’을 내장 image_gen으로 생성했다. 실제 원생이나 관장님을 촬영한 사진이 아니며 두 인물은 가상이다. [최종 생성 프롬프트](Source/GenerationPrompt.txt)를 보존했다. 앱에 사진 생성 기능이 있다는 의미가 아니다.

Mac은 샌드박스를 적용한 실제 Release 앱을 별도 QA Bundle ID로 복제해 샘플 문서를 열었다. iPad는 Simulator의 실제 EditorRoot·CanvasSurface·TutorialView를 실행했다. 사용자 허용을 받아 Xcode simctl로 화면을 저장했다. iPad 촬영 빌드는 샘플 문서를 직접 여는 별도 시작점만 제공하며, 문서 브라우저는 건너뛴다. UI와 표지 결과를 합성하거나 AI로 다시 그리지 않았다.

Mac 캡처 원본은 JPEG, iPad는 PNG이며 `Source/Captures`에 보존한다. 최종본은 sRGB·불투명 PNG로 변환했다. Mac 1번은 좌우 여백, 2·3번은 위아래 1px, 4번은 실제 튜토리얼 창 주위에 여백을 추가해 16:10에 맞췄다. 앱 픽셀을 늘리거나 내용·버튼을 바꾸지 않았다.

사진·샘플 문서·스크린샷은 Marketing에만 있으며 앱 번들에 포함하지 않는다. 촬영용 시작점은 `DEBUG && STORE_SCREENSHOTS && os(iOS)`일 때만 컴파일된다. 일반 Debug와 Release는 기존 DocumentGroup을 사용한다. Release 검증은 촬영용 실행 인자가 바이너리에 없는지도 검사한다.

## 재현 및 검증

저장소 루트에서 다음을 실행한다. 이미지는 원본 캡처가 변경되지 않았다면 다시 만들 필요가 없다.

```sh
python3 Scripts/make_store_fixtures.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift Scripts/prepare_store_screenshots.swift
python3 Scripts/verify_store_screenshots.py
```

캡처를 의도적으로 바꾼 경우 시각 검수 후 `python3 Scripts/verify_store_screenshots.py --write-manifest`로 SHA-256 목록을 갱신한다. 원본이 그대로인데 목록을 갱신해 무결성 실패를 숨기지 않는다.

iPad 촬영 전용 빌드:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project BlogCoverMakerBySeolin.xcodeproj -scheme BlogCoverMakerPad \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build-output/store \
  CODE_SIGNING_ALLOWED=NO 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG STORE_SCREENSHOTS' build
```

전용 Simulator에 설치 후 `simctl get_app_container <UDID> com.seolin.blogcovermaker.ipad data`로 얻은 Documents 폴더에 샘플을 복사한다. `simctl launch <UDID> com.seolin.blogcovermaker.ipad --screenshot-fixture <문서의 절대 경로> -seolin.tutorial.presentedVersion 1`로 실행하고 화면 렌더링 완료를 확인한 다음 `simctl io <UDID> screenshot <출력 경로>`로 촬영한다. 시나리오 변경 전 앱을 종료한다.

- 1번: `01-full.seolincover`.
- 2번: `02-card.seolincover`, 추가 인자 `--screenshot-panel design`.
- 3번: `03-polaroid.seolincover`.
- 4번: `03-polaroid.seolincover`, `-seolin.tutorial.presentedVersion 0 -seolin.tutorial.step 0`.

촬영 전용 빌드를 배포하지 않는다. 일반 스킴 Release로 Archive하고 `Scripts/verify_release.py`를 통과한 결과를 사용한다.

## 스토어 설명 초안

**이름**: BLOG COVER MAKER by SEOLIN

**부제**: 사진과 문구로 완성하는 블로그 표지

**홍보 문구**: 사진 한 장으로 시작해 나만의 블로그 표지를 완성하세요. 50가지 디자인과 다양한 글씨체, 사진·문구·레이어 편집을 Mac과 iPad에서 사용할 수 있습니다.

**설명**:

사진을 고르고 디자인을 선택한 다음, 전하고 싶은 문구를 넣어 보세요. BLOG COVER MAKER by SEOLIN은 블로그 표지를 만드는 편집 앱입니다.

- 50가지 표지 디자인과 22가지 테마
- 사진 위치·크기, 글씨체·색상·강조·정렬 편집
- 레이어와 그룹으로 요소 배치 관리
- 사진과 추가 폰트를 포함한 프로젝트 파일 저장
- 1080×1080 전체 표지, 배경, 글씨·장식 PNG 출력
- 처음 사용하는 분을 위한 7단계 튜토리얼

Mac에서는 넓은 편집 화면과 키보드 단축키를, iPad에서는 화면 크기에 맞는 터치 편집 화면을 제공합니다. 핵심 편집 기능은 인터넷 연결이나 회원가입 없이 사용할 수 있습니다.

**키워드 초안**: 블로그,표지,썸네일,사진,문구,디자인,태권도,포스터,이미지,편집

## 심사 메모 초안

회원가입과 로그인은 필요하지 않습니다. 새 문서를 만들면 튜토리얼이 표시됩니다. 닫은 뒤 상단 사진 버튼에서 사용자가 선택한 이미지 파일을 가져오고, 디자인과 문구를 편집할 수 있습니다. 프로젝트는 .seolincover로 저장하며 상단 내보내기에서 PNG를 저장합니다. 맥에서는 파일 메뉴의 저장·열기도 사용할 수 있습니다. 로고 버튼은 외부 서린 소셜 페이지를 기본 브라우저로 엽니다. 스크린샷의 태권도 사진은 소개용 샘플이며 앱에 기본 포함되거나 자동 생성되는 사진이 아닙니다.

지원 URL·연락처·저작권자·가격·국가·연령 등급·개인정보 설문은 소유자 계정에서 확정해야 한다. 개인정보보호 웹사이트는 이번 작업 범위에서 제외했다. [배포 점검표](../../Docs/ReleaseChecklist.md)를 함께 확인한다.
