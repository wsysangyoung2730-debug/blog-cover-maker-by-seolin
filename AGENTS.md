# 개발 원칙

- macOS가 주력 플랫폼이다. iPadOS는 공통 엔진을 공유하되 맥의 편집 기능을 축소하는 이유가 되어서는 안 된다.
- 원본은 Reference/original.html에 보존하며 기능·템플릿·결과를 비교한다.
- SwiftUI 화면, 공통 CoverCore, 플랫폼별 입력 처리를 분리한다.
- 커밋 제목은 `[소문자 태그] 한글 명령조`이며 50자 이내로 작성한다.
- 태그: init, feat, fix, docs, setting, add, refactor, chore.
- init은 최초 커밋에만 사용한다.
- 작업 브랜치는 `태그/#이슈번호-작업범위` 형식으로 만든다.
- main은 출시용, develop은 통합 개발용이다.
- 작업 브랜치에 최신 develop을 먼저 병합하고 확인한 뒤 develop 대상 PR을 생성한다.
- 기능 범위별 이슈와 브랜치, 커밋을 분리한다. 빌드·검증 근거와 미완료 항목을 기록한다.
- GitHub 이슈에 브랜치, 작업 목적, 주요 작업 내용, 완료 기준을 포함한다.

## 파일 배치

- 공통 기능 UI는 `App/Features`, 재사용 UI는 `App/Shared`에 둔다.
- 맥 전용 코드는 `App/Platforms/macOS`, iPad 전용 코드는 `App/Platforms/iPadOS`에 둔다.
- 화면에 의존하지 않는 문서·편집·출력 코드는 `Sources/CoverCore`에 둔다.
- 파일 추가·이동 후 `python3 Scripts/generate_project.py`를 실행하고 생성 결과도 커밋한다.
