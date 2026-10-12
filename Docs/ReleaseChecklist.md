# App Store 배포 점검

macOS가 주력이며 iPadOS를 함께 지원한다. 개인정보보호 웹사이트 제작·내용 점검은 요청에 따라 제외한다. 개인정보 명세 파일과 앱의 실제 데이터 처리는 포함한다.

## 코드와 번들 설정

- Mac App Sandbox와 사용자가 선택한 파일의 읽기·쓰기를 활성화했다. 사진·폰트는 선택한 파일을 프로젝트에 내장하며 원본에 지속 접근하는 별도 권한은 요청하지 않는다.
- 두 앱에 `PrivacyInfo.xcprivacy`를 포함한다. 자체 설정과 튜토리얼 진행 상황을 저장하는 UserDefaults에 `CA92.1`을 선언했다. 분석·광고 SDK, 앱 서버, 추적, 계정은 없다.
- 사진 보관함 전체, 카메라, 마이크에 직접 접근하지 않는다. 시스템 파일 선택기를 이용하므로 불필요한 권한 설명은 추가하지 않았다.
- iPad는 문서 브라우저 및 파일 원본 열기를 지원하도록 선언했다. 사용자가 선택한 파일 제공자에 저장하며 앱 자체 동기화 서버는 없다.
- 자체 암호화 구현이 없어 `ITSAppUsesNonExemptEncryption = NO`를 선언했다.
- macOS 14+, iPadOS 17+, iPad 전용. Mac은 arm64/x86_64 두 아키텍처를 검증한다.
- 첫 출시 버전은 `1.0.0`, 저작권은 `© 2026 SEOLIN`이다. macOS 첫 업로드는 빌드 1이었으며, iPad 시작 화면·입력 수정 반영 후 두 플랫폼을 `1.0.0 (2)`로 준비한다. 동일 버전 재업로드 시 빌드 번호를 올린다.
- 번들에 50개 디자인, 오프라인 폰트와 OFL 라이선스, 플랫폼별 아이콘을 포함한다.
- CI는 macOS 26 환경에서 Debug 검증에 이어 두 플랫폼 Release 아카이브를 검사한다. 이전 Xcode 16 빌드 성공만으로는 현재 iPad 업로드 SDK 요구 조건을 충족하지 못한다.

## 재현 방법

Xcode 26 이상을 선택하고 공통 테스트, Debug 앱의 `--verify-editor`, 두 플랫폼 Release archive를 실행한다. 아카이브 후 아래 검사를 수행한다.

```sh
python3 Scripts/verify_release.py /path/Mac.xcarchive/Products/Applications/BlogCoverMakerMac.app --platform mac
python3 Scripts/verify_release.py /path/Pad.xcarchive/Products/Applications/BlogCoverMakerPad.app --platform ipad
```

Mac 서명 후 `--signed`를 추가하면 코드 서명과 내장 샌드박스 권한도 검사한다. 로컬 임시 서명은 Apple 배포 서명을 대신하지 않는다.

## 제출 시 계정에서 마무리할 항목

- Apple Developer Team, 배포 인증서와 프로비저닝 프로파일로 Archive/Validate App 실행
- Mac과 iPad는 동일 Bundle ID `com.seolin.blogcovermaker`를 사용하고 같은 App Store Connect 앱의 macOS·iOS 플랫폼에 연결한다.
- 앱 이름, 카테고리, 지원 URL과 연락처, 저작권, 국가·가격, 연령 등급 설문 입력
- 앱 개인정보 설문에 현재 코드의 수집 없음 상태 반영. 향후 분석 SDK나 서버 추가 시 다시 검토
- 유료 판매 시 계약·세금·은행 정보 및 해당 판매 지역의 사업자 정보 확인
- 한국어 스크린샷 등록, 리뷰 담당자에게 문서 생성→편집→저장·내보내기 경로 제공
- 실제 Mac/iPad에서 배포 서명 빌드로 파일 제공자 저장·재열기, 여러 창, 회전·작은 창 사용 확인

이 점검은 Apple 심사 승인을 보장하지 않는다. 계정 등록·서명 준비 결과는 아래 배포 연결 기록을 따른다. 앱 빌드 업로드 결과는 아래 기록에 포함하며, 심사 제출·출시는 별도 단계다.

## 근거

- [Apple App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [UserDefaults 승인 사용 이유](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
- [문서 원본 열기](https://developer.apple.com/documentation/bundleresources/information-property-list/lssupportsopeningdocumentsinplace)
- [암호화 사용 선언](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)
- [2026년 SDK 최소 요구 사항](https://developer.apple.com/news/upcoming-requirements/?id=04282026a)
- [스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

확인일: 2026-10-13

## 2026-10-13 1차 실행 결과

- Xcode 27.0에서 macOS 범용·iPad 실기기용 Release 아카이브와 `verify_release.py` 통과.
- 별도 검증용 Bundle ID로 복제하고 로컬 임시 서명한 Mac 샌드박스 앱에서 문서 생성 및 첫 실행 튜토리얼 표시 확인.
- iPad 문서 관련 빌드 경고 해소. AppIntents를 사용하지 않는 앱의 메타데이터 추출 생략 안내만 남음.
- 이 시점에는 Apple 배포 인증서 검증·업로드·실기기 배포 테스트를 수행하지 않았다. 이후 서명 검증 결과는 아래 macOS 배포 연결 기록을 따른다.

## 편집 코드 감사와 수정

- 글씨 초안을 확정하지 않은 채 색·디자인 등을 바꾸고 취소하면 다른 변경까지 되돌아가던 경로를 수정했다. 새 작업 전에 글씨 편집을 확정한다.
- 레이어 이름·글씨 수정은 로컬 초안으로 유지하고 완료 시 한 번에 기록한다. 취소가 다른 작업 기록을 되돌리지 않는다.
- 문서 원복 등 외부 문서 상태 변경을 편집 화면에도 반영한다.
- 파일 선택을 취소한 뒤 같은 종류의 가져오기를 다시 실행할 수 있도록 상태를 초기화한다. 폰트 적용 대상은 선택기 완료까지 별도로 유지한다.
- iPad 여러 사진 드롭은 원래 순서대로 읽고 하나의 실행 취소 작업으로 반영한다. 삭제된 프레임을 대상으로 한 늦은 드롭 완료는 오류를 표시한다.
- 디자인 50종 미리보기 생성은 별도 actor에서 수행하며, 문구·테마·기본 사진 등이 바뀐 경우에만 갱신한다. 요소 위치 이동 때 전체 미리보기를 다시 만들지 않는다.
- 문서의 과도한 수치, 중복 레이어/폰트 ID, 잘못된 사진 기록을 거부한다. 텍스트 맞춤 반복과 질감 반복 수를 제한하고 사진 기록 정수 오버플로를 방지한다.
- 자기 자신 위에 레이어를 놓았을 때 맨 아래로 이동하던 문제, 다른 문서에서 온 레이어 드롭, 손상된 패널 설정을 처리한다.
- 전역 Delete 단축키를 제거하고 캔버스에서만 요소를 삭제해 글씨 입력을 방해하지 않도록 했다. Escape로 진행 중 드래그를 취소한다.

회귀 검사: 공통 엔진 18개 테스트, 문서 연결·외부 복원·글씨 취소·후속 편집·실행 취소·다시 실행·작업 공간 복구·저장 왕복·PNG 3종·50개 템플릿 렌더링.

## 최종 촬영·실행 확인

- 밝은 Mac 도구막대에서 투명한 흰색 서린 로고가 보이지 않던 문제를 브랜드 색상 템플릿 렌더링으로 수정했다.
- Mac 샌드박스 앱에서 외부 문서 열기·저장, 사진 선택 취소 후 재시도, 실제 PNG 파일 저장을 확인했다.
- macOS와 iPadOS 최종 Release archive 및 촬영 코드 제외 검증을 통과했다.
- [한국어 스크린샷 8장과 스토어 설명 초안](../Marketing/AppStore/README.md)을 준비했다. AI로 생성한 가상의 태권도 수업 사진을 실제 편집기에 적용했다.
- iPad Simulator에서 편집 화면과 튜토리얼의 시각 검수를 완료했다. 배포 서명된 실제 iPad의 파일 저장·회전·Pencil 테스트는 제출 전에 별도로 수행한다.

## 2026-10-13 macOS 배포 연결

- 사용자 지정 팀: Sangyoung Woo (`36545XSWN8`). Mac 타깃의 Debug·Release 자동 서명에 연결했다.
- 사용자 확인 후 Apple Distribution 및 Mac Installer Distribution 인증서를 Xcode에서 생성했다. 개인 키는 Mac 키체인에 보관하며 저장소에 포함하지 않는다.
- 설치 인증서는 키체인에서 `3rd Party Mac Developer Installer: Sangyoung Woo (36545XSWN8)`로 표시된다.
- 명시적 Bundle ID `com.seolin.blogcovermaker`를 Apple Developer에 등록했다.
- [App Store Connect macOS 앱](https://appstoreconnect.apple.com/apps/6822050062/distribution/macos/version/inflight) 생성 완료. Apple ID `6822050062`, SKU `seolin-blog-cover-maker-macos`, 기본 언어 한국어. 사용자 액세스는 제한된 액세스로 생성했으며 추가 팀원을 지정하지 않았다.
- 스토어 버전 `1.0.0`, 저작권 `2026 SEOLIN`, 로그인 불필요 및 수동 출시로 저장했다.
- Xcode 27에서 `1.0.0 (1)` 범용 Release archive 생성과 Apple Distribution 서명 앱 검증에 성공했다. 샌드박스·파일 선택 읽기/쓰기·디버깅 권한 제외·개인정보 명세·촬영 전용 코드 제외를 확인했다.
- `Configuration/ExportOptions-macOS.plist`는 App Store Connect용 **로컬 내보내기** 설정이다. 자동 업로드하지 않는다.
- 설치 인증서로 서명한 최종 `.pkg`를 생성하고 `pkgutil --check-signature`로 Apple 인증서 체인을 확인했다. 패키지를 별도 경로에 풀어 실제 포함된 앱에도 `verify_release.py --platform mac --signed`를 실행했으며 `1.0.0 (1)`, 팀, 저작권, 두 아키텍처와 서명을 확인했다.
- 첫 내보내기에서는 키체인 응답 대기로 패키징이 완료되지 않아, 이미 검증된 배포 서명 앱을 유지한 채 `productbuild --component`로 설치 패키지만 다시 생성했다. 최종 패키지와 원본 `.xcarchive`를 함께 보관하며, 이전 내보내기의 요약 파일을 최종 패키지 검증 근거로 사용하지 않는다. dSYM은 원본 아카이브에 보존했다.
- 실제 앱 화면에 기능 설명을 조합한 한국어 macOS 소개 이미지 4장을 App Store Connect에 등록했다. iPad용 소개 이미지 4장도 함께 준비했다.

재현:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project BlogCoverMakerBySeolin.xcodeproj -scheme BlogCoverMakerMac \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath .build-output/Mac-1.0.0.xcarchive -allowProvisioningUpdates archive
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -exportArchive -archivePath .build-output/Mac-1.0.0.xcarchive \
  -exportOptionsPlist Configuration/ExportOptions-macOS.plist \
  -exportPath .build-output/AppStore-1.0.0 -allowProvisioningUpdates
pkgutil --check-signature .build-output/AppStore-1.0.0/BlogCoverMakerMac.pkg
```

## 2026-10-13 업로드·등록 완료 결과

- 같은 `Mac-1.0.0.xcarchive`를 Xcode의 `destination=upload`로 App Store Connect에 업로드했다. Xcode에서 `Upload succeeded`를 확인했고, Apple 처리 후 TestFlight의 `1.0.0 (1)` 상태가 `제출 준비 완료`로 표시됐다. 이 빌드를 macOS 1.0.0 출시 버전에 연결하고 저장했다.
- 한국어 홍보 문구·설명·키워드·심사 메모와 사용자가 지정한 심사 연락처를 저장했다. 개인 전화번호와 이메일은 저장소에 기록하지 않는다.
- 부제 `사진과 문구로 완성하는 블로그 표지`, 기본 카테고리 `그래픽 및 디자인`을 저장했다. 앱 자체에 콘텐츠 배포·채팅·웹 탐색·광고·유해 콘텐츠 기능이 없다는 구현 기준으로 연령 설문을 작성했고 글로벌 `4+`가 산정됐다. 지역별 등급은 Apple 기준을 따른다.
- 동봉된 Google Fonts 17개 글꼴군의 OFL 라이선스를 근거로 타사 콘텐츠 사용 권한이 있음을 설정했다.
- 앱은 개발자 서버·분석/광고 SDK·추적이 없고 사진·문서는 사용자의 파일로 처리한다. `데이터 수집 없음` 답변을 작성한 뒤 게시 시 준수·갱신 동의에 대한 사용자 확인을 받아 게시했다.
- 사용자 선택에 따라 무료 가격과 175개 국가·지역 전체 및 향후 추가 지역의 사용 가능 여부를 설정했다. 실제 출시는 수동으로 유지했다.
- 제출 전 `심사에 추가` 검사에서 미완료 항목은 **개인정보 처리방침 URL**과 **한국어 지원 URL** 두 가지였다. 두 웹사이트는 사용자가 이번 범위에서 제외했다. 심사 제출이나 앱 출시는 하지 않았다.

이 시점의 다음 단계는 두 URL 입력과 심사 요청이었다. iPad 첫 등록·후속 업로드 결과는 아래 기록을 따른다.

## 2026-10-13 두 플랫폼 첫 출시 갱신 — 이슈 #43

- 1.0.0이 아직 ‘제출 준비 중’이므로 1.1 업데이트를 만들지 않고 같은 출시 버전에 새 빌드 2를 준비한다.
- 사용자는 macOS와 iPadOS의 등록·업로드를 함께 요청했다. 기존 Apple ID `6822050062` 앱에 iOS 플랫폼을 추가하고 버전 `1.0.0`, 한국어 설명·홍보 문구·iPad 심사 경로와 수동 출시 설정을 저장했다. 심사 연락처는 기존 앱 기록에서 승계했다.
- 두 타깃의 Bundle ID를 `com.seolin.blogcovermaker`, 개발 팀을 Sangyoung Woo `36545XSWN8`로 통일했다. iPad의 이전 개발용 Bundle ID `.ipad`는 출시 앱의 식별자가 아니다. 기존 개발 앱 문서는 자동으로 새 앱의 로컬 저장 공간에 이전되지 않으므로 필요하면 파일 앱으로 저장한 `.seolincover`를 연다.
- 이슈 #41의 직접 튜토리얼 버튼 수정은 PR #42로 develop에 통합했다. 해당 커밋의 전체 CI와 두 플랫폼 `1.0.0 (2)` Release 아카이브·번들 검사를 통과했다.
- iPad용 내보내기 설정은 `Configuration/ExportOptions-iPadOS.plist`다. 저장소의 내보내기 설정은 자동 업로드하지 않으며, 명시적인 배포 요청에서만 `destination=upload`로 복제해 사용한다.
- 한국어 소개 이미지 8장의 크기·색상·투명도·무결성을 다시 확인했다. 지원 URL·개인정보 처리방침 URL의 제외 범위는 유지한다.
