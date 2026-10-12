# App Store 배포 점검

macOS가 주력이며 iPadOS를 함께 지원한다. 개인정보보호 웹사이트 제작·내용 점검은 요청에 따라 제외한다. 개인정보 명세 파일과 앱의 실제 데이터 처리는 포함한다.

## 코드와 번들 설정

- Mac App Sandbox와 사용자가 선택한 파일의 읽기·쓰기를 활성화했다. 사진·폰트는 선택한 파일을 프로젝트에 내장하며 원본에 지속 접근하는 별도 권한은 요청하지 않는다.
- 두 앱에 `PrivacyInfo.xcprivacy`를 포함한다. 자체 설정과 튜토리얼 진행 상황을 저장하는 UserDefaults에 `CA92.1`을 선언했다. 분석·광고 SDK, 앱 서버, 추적, 계정은 없다.
- 사진 보관함 전체, 카메라, 마이크에 직접 접근하지 않는다. 시스템 파일 선택기를 이용하므로 불필요한 권한 설명은 추가하지 않았다.
- iPad는 문서 브라우저 및 파일 원본 열기를 지원하도록 선언했다. 사용자가 선택한 파일 제공자에 저장하며 앱 자체 동기화 서버는 없다.
- 자체 암호화 구현이 없어 `ITSAppUsesNonExemptEncryption = NO`를 선언했다.
- macOS 14+, iPadOS 17+, iPad 전용. Mac은 arm64/x86_64 두 아키텍처를 검증한다.
- 출시 버전은 기존 `0.1.0 (1)`을 보존했다. 실제 제출 전에 버전과 빌드 번호를 확정하고, 동일 버전 재업로드 시 빌드 번호를 올린다.
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
- 각 Bundle ID를 App Store Connect 앱에 연결. 현재 Mac과 iPad는 별도 ID이므로 하나의 유니버설 구입 앱으로 등록하려면 최초 등록 전에 동일 Bundle ID 전략을 결정
- 앱 이름, 카테고리, 지원 URL과 연락처, 저작권, 국가·가격, 연령 등급 설문 입력
- 앱 개인정보 설문에 현재 코드의 수집 없음 상태 반영. 향후 분석 SDK나 서버 추가 시 다시 검토
- 유료 판매 시 계약·세금·은행 정보 및 해당 판매 지역의 사업자 정보 확인
- 한국어 스크린샷 등록, 리뷰 담당자에게 문서 생성→편집→저장·내보내기 경로 제공
- 실제 Mac/iPad에서 배포 서명 빌드로 파일 제공자 저장·재열기, 여러 창, 회전·작은 창 사용 확인

이 점검은 Apple 심사 승인이나 App Store Connect 업로드 성공을 보장하지 않는다. 계정에 접근해 업로드하거나 앱을 출시하지 않았다.

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
- Apple 배포 인증서 검증·업로드·실기기 배포 테스트는 아직 수행하지 않음.

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
