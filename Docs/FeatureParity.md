# 원본 HTML → Swift 기능 대응표

기준: `Reference/original.html` (사용자가 제공한 2026-10-12 파일).

**macOS 우선**으로 이식한다. iPadOS는 같은 기능과 문서를 공유한다. ‘구현’은 접근 경로와 처리 코드가 존재한다는 뜻이며, 모든 기기의 모든 조작을 수동 검증했다는 뜻은 아니다. 검증 근거는 `Validation.md`를 참조한다.

## 편집 화면·선택

| 원본 기능 | Swift 구현 위치 / 접근 경로 |
| --- | --- |
| 1080×1080 실시간 표지 | CoverRenderer / 중앙 캔버스 |
| 사진·텍스트·사각형·타원·곡선·경로·아이콘 | CoverElement / CoverRenderer |
| 단일 선택·선택 테두리·모서리 핸들 | CanvasInteraction / CanvasSurface |
| 위치 이동·단일 요소 크기 변경 | CanvasInteraction.drag |
| 글씨 크기와 너비를 함께 조절 | CanvasInteraction.drag |
| Shift 비율 유지·북마크 비율 유지 | CanvasInteraction.drag |
| 방향키 1px·Shift 10px | MacCanvas.keyDown |
| 중앙 스냅·가이드 | CanvasInteraction.drag / drawOverlay |
| 회전된 요소의 선택·테두리 | CanvasInteraction.contains / drawOverlay |
| 빈 곳 선택 해제·범위 선택 | CanvasInteraction / EditorRoot |
| Shift·Command·Control 추가 선택 | MacCanvas / LayersPanel |
| 그룹 선택·Option 개별 선택 | EditorStore.select |
| 전체 선택·같은 종류 선택 | EditorStore.selectAll / selectSame |
| 터치 선택·드래그·두 번 탭 | PadCanvas |
| 다중 선택 후 동시 이동 | CanvasInteraction |

## 디자인·테마

| 원본 기능 | Swift 구현 위치 / 접근 경로 |
| --- | --- |
| 디자인 50종의 원본 좌표·속성·장식 | catalog.json / extract_catalog.mjs |
| 전체·사진 가득·액자/카드·화면 나누기 | 50종 모두 유지, 사용자 요청으로 분류 메뉴는 전체·즐겨찾기 버튼으로 단순화 |
| 즐겨찾기 등록·해제·필터·빈 상태 | DesignPanel / WorkspaceSettings |
| 기본 사진·문구·테마가 반영된 미리보기 | EditorStore.refreshThumbnails |
| 디자인 번호·이름·현재 선택 | DesignPanel |
| 미리보기 크기·설정 유지·초기화 | DesignPanel / WorkspaceSettings |
| 공통 사진·입력 문구를 유지한 디자인 전환 | CoverProject.applyTemplate |
| 현재 디자인·밝기 초기화 | EditorStore.resetDesign |
| 일반 15종·무지개 7종 테마 | catalog.json / DesignPanel |
| 테마 이름·밝기 조절 | DesignPanel |
| 테마 연동 색·사용자 고정 색 | CoverRenderer.color / SwatchPicker |
| 테마색·흑백·무지개 팔레트·직접 선택 | SwatchPicker |

## 사진

| 원본 기능 | Swift 구현 위치 / 접근 경로 |
| --- | --- |
| 기본 사진 불러오기·미리보기 반영 | EditorStore.importFiles / CoverEditing.replacePhoto |
| 선택 사진 교체·별도 사진/로고 추가 | PropertiesPanel / CoverEditing.addPhoto |
| 여러 사진 선택 추가 | 파일 선택 창 / EditorStore.importFiles |
| 파일 드래그 추가·사진 위 드롭 교체 | MacCanvas.performDragOperation / PadCanvas |
| 기본 사진과 개별 사진 틀 구분 | CoverProject.imageID / LayersPanel |
| 기본 사진/틀별 이전·다음 교체 기록 | PhotoHistory / CoverEditing.stepPhoto |
| 기록 위치·이전/다음 활성 상태 | PropertiesPanel |
| 이전 기록에서 새 사진 추가 시 이후 기록 분기 | PhotoHistory.push |
| 사진 틀 이동·크기·회전 | CanvasInteraction / PropertiesPanel |
| 틀 안의 사진 이동 모드·더블클릭 전환 | CanvasInteraction / PropertiesPanel |
| 20~300% 확대·휠 확대 | PropertiesPanel / CanvasInteraction.wheel |
| 처음 위치·크기·회전·내부 이동 복원 | CoverEditing.resetPhoto |
| 사각·둥근 사각·타원·아치·사선 마스크 | CoverRenderer.photoPath |
| 같은 사진을 이어 보여주는 분할 템플릿 | CoverRenderer.drawPhoto의 page 참조 |
| 듀오톤·유리 흐림 | CoverRenderer.drawPhoto |
| 기본 사진으로 복귀 (원본 처리 코드를 메뉴에 연결) | PropertiesPanel / EditorStore.useMainPhoto |
| 잘못된 이미지 오류 안내 | ImageAssets / 오류 대화상자 |

## 문구·폰트·스타일

| 원본 기능 | Swift 구현 위치 / 접근 경로 |
| --- | --- |
| 제목 2줄·강조 단어·태그·부제목·영문·인스타 | WordsPanel / CoverProject.words |
| 브랜드·독립 글씨 편집 | 캔버스 직접 편집 / 레이어 편집 |
| 쓰는 입력칸만 활성·나머지 값 기억 | WordsPanel / wordIDs |
| 바인딩된 글씨 함께 수정 | CoverProject.setText |
| 캔버스 더블클릭 직접 편집·완료·취소 | EditorRoot TextEditor / EditorStore |
| 레이어에서 글씨 수정·Enter 완료·Esc 취소 | LayersPanel |
| 여러 줄·자동 줄바꿈·폭/줄 수 자동 맞춤 | CoverTypography.layout |
| 강조 단어 색·첫 일치 구간·형광펜 | CoverRenderer.drawText |
| 자간·줄 간격·영문 대문자 | CoverTypography / CoverProject.text |
| 굵게·기울임·밑줄·취소선·그림자 | TextStyleControls / CoverRenderer |
| 크기·정렬·색·폰트 개별/다중 변경 | PropertiesPanel / QuickPalette / WordsPanel |
| 외곽선·글씨 배경·라벨·패딩 | CoverRenderer.drawText |
| 제목 빠른 선택 8개·개별 옵션 19개 | catalog.json / FontPicker |
| 디자인 기본 글씨체 복귀·제목 일괄 변경 | FontPicker / WordsPanel |
| TTF·OTF·WOFF·WOFF2 추가 | CoverTypography.importFont / 파일 선택 |
| 추가 폰트의 대상 글씨 적용 | fontImportTargets / EditorStore.importFiles |

## 레이어·그룹·정렬

| 원본 기능 | Swift 구현 위치 / 접근 경로 |
| --- | --- |
| 앞뒤 순서·선택·다중 선택 | LayersPanel |
| 드래그 순서 변경·여러 레이어 함께 이동 | CoverEditing.reorder / 삽입 가로선 표시 |
| 맨 앞/앞/뒤/맨 뒤 | CoverEditing.move |
| 표시/숨김·기본 사진·그룹 표기 | LayersPanel |
| 글씨 내용 일부 표시·다른 요소 이름 변경 | LayersPanel |
| 복제·삭제·바인딩 해제·복제 그룹 분리 | CoverEditing.duplicate / EditorStore |
| 그룹 묶기·풀기 | CoverEditing |
| 6방향 정렬·단일/그룹은 표지 기준 | CoverEditing.align / 사진 내부 편집 중 alignPhotoContent |
| 다중 정렬·3개 이상 가로/세로 균등 간격 | CoverEditing.align |
| 투명도 0~100%·흐림 0~60·회전 ±180° | PropertiesPanel / CoverRenderer |

## 빠른 편집·작업 화면·출력

| 원본 기능 | Swift 구현 위치 / 접근 경로 |
| --- | --- |
| 요소 옆 빠른 편집·글씨·색·그룹 | QuickPalette |
| 빠른 창 이동·너비·접기·닫기·위치 보관 | macOS FloatingPalette(NSPanel) / QuickPalette |
| iPad 빠른 편집 | popover |
| 사진·디자인·문구·레이어 접기·제목 더블클릭 | EditorRoot / WorkspaceSettings |
| 패널을 다른 열로 옮기기·순서 변경 | panelColumn / movePanel |
| 열 너비 변경·더블클릭 초기화 | EditorRoot.divider |
| 전체 배치 초기화·배치/접힘/너비 유지 | WorkspaceSettings |
| 화면 크기 대응·시스템 다크 모드 | SwiftUI / iPad 패널 화면 |
| 상태·오류 안내·키보드 포커스·접근성 레이블 | SwiftUI 컨트롤 / 상태줄 / 오류 대화상자 |
| 실행 취소 최대 60개 | EditorStore + UndoManager.levelsOfUndo |
| 원본 단축키 | MacCanvas / EditorCommands |
| 전체·배경·글씨/전경 장식 PNG | ExportMode / CoverRenderer.png |
| 투명 영역·1080×1080·디자인/날짜 파일명 | CoverRenderer / EditorStore.export |
| 서린 로고 링크 순환·다음 링크 기억 | EditorRoot / seolinLink |
| 인스타·스마트플레이스·블로그 개별 접근 | 보기 메뉴 |

## 앱 전환에서 추가·보완한 기능

- `.seolincover` 문서 저장·열기. Mac은 최근 문서·문서 기반 자동 저장, iPad는 편집기 내 불러오기·저장하기와 창별 초안 복구.
- 전체 프로젝트 상태를 대상으로 실행 취소·다시 실행.
- 사진과 사용자 폰트를 문서에 포함해 다른 기기에서도 복원.
- 기본 폰트의 오프라인 번들 제공.
- 새 글씨·도형 추가, 디자인 이름 검색.
- iPad 사진 핀치 확대.
- 원본에서 버튼이 연결되지 않았던 같은 종류 선택·기본 사진 복귀를 메뉴에 연결.

## 의도적으로 유지한 동작

- 디자인 변경은 선택한 템플릿을 새로 구성한다. 수동 배치와 추가 요소가 다른 템플릿으로 자동 이식되지 않는다. 실행 취소로 이전 상태를 복원할 수 있다.
- 배경과 전경 분리는 원본의 `type == text || layer == fg` 규칙을 따른다. 전경에는 글씨 외 장식도 포함된다.
- 강조 단어의 별도 꾸미기는 색상 중심이다. 원본에 없던 단어별 리치 텍스트 편집을 구현했다고 표시하지 않는다.
- 다중 이동과 그룹 정렬을 지원한다. 다중 요소의 통합 확대/회전은 원본 기능에 없으며 추가 구현 범위에 포함하지 않았다.
- 사진 데이터는 원본과 같이 최대 2200픽셀로 정규화한다. 출력은 1080픽셀이다.
