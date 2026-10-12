# 앱 로고

블로그 표지 카드와 사진·글씨 편집을 나타내는 연필을 조합하고, 오른쪽 아래에 서린 박스형 브랜드 로고를 배치했다. 기존 서린 앱의 남색·흰색을 기준으로 파란색을 함께 사용한다.

- `blog-cover-maker-icon.png`: 선택한 고해상도 아이콘 원본, 1254×1254, 불투명 PNG.
- `References/`: 사용자가 제공한 서린 로고 원본 두 종류. 파일 내용은 변경하지 않았다.
- `GenerationPrompt.txt`: 제작에 사용한 전체 프롬프트. 내장 이미지 생성 도구로 제작했으며 CLI/API 대체 경로는 사용하지 않았다.
- `App/Resources/Assets.xcassets/AppIconMac.appiconset`: macOS 아이콘 크기별 파일.
- `App/Resources/Assets.xcassets/AppIconPad.appiconset`: iPadOS 아이콘 및 1024px 마케팅 아이콘.

아이콘 원본을 교체할 때는 `python3 Scripts/generate_app_icons.py`로 플랫폼별 크기만 다시 생성한다. 이 스크립트는 그림이나 서린 로고를 새로 그리지 않고 원본 전체를 축소한다. 이어 `python3 Scripts/generate_project.py`로 Xcode 참조를 갱신한다.

이 그림은 앱 아이콘이다. 사용자가 만드는 표지나 내보낸 PNG에 워터마크로 삽입하지 않는다.
