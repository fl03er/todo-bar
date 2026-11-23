# TodoBar

<img src="docs/character.png" width="88" align="right">

<video src="docs/sync-mechanism.mp4" controls muted width="100%"></video>

<sub>미리알림 동기화 원리 영상 ([mp4](docs/sync-mechanism.mp4), 영어)</sub>

macOS 메뉴바 투두리스트. 눈 달린 구름을 누르면 목록이 열리고, 옆 숫자는 남은 할 일 수.
터미널이나 Claude Code에서 `todo`로 추가·완료·삭제하면 바로 반영돼. 아이폰 미리알림과도 동기화돼.
전부 끝내면 컨페티가 터지고, 남은 게 없는 동안 구름은 눈을 감고 자 🎉💤

<p align="center"><img src="docs/celebrate.png" width="300"></p>

## 설치

### 릴리스
1. [Releases](../../releases)에서 `TodoBar-x.y.z.zip`을 풀어 `TodoBar.app`을 `~/Applications`로 옮겨.
2. 공증 안 된 앱이라 처음엔 우클릭 → **열기**. (또는 `xattr -dr com.apple.quarantine ~/Applications/TodoBar.app`)
3. CLI 연결 (`~/.local/bin`이 `PATH`에 있어야 해):
   ```bash
   mkdir -p ~/.local/bin && ln -sf ~/Applications/TodoBar.app/Contents/MacOS/todo ~/.local/bin/todo
   ```

### 소스 빌드
Xcode Command Line Tools(Swift 5.9+), macOS 13 이상.
```bash
git clone https://github.com/fl03er/todo-bar.git && cd todo-bar
./build.sh install     # 빌드 → ~/Applications, CLI 링크, 실행
./build.sh release     # 유니버설 zip → dist/
```
첫 실행 때 로그인 항목에 등록돼. 끄려면 패널 아래 「로그인 시 실행」.

## 메뉴바
- 추가: 입력칸에 쓰고 ⏎
- 완료: 동그라미나 글자 클릭 (다시 누르면 취소)
- 삭제: 항목에 마우스 올리고 ✕
- 완료 항목 지우기: 패널 아래

## `todo` CLI
```
todo [ls] [--json]          목록
todo add <할 일>             추가
todo done|undo|rm <번호|글자>...   완료 / 취소 / 삭제
todo edit <번호> <새 내용>    수정
todo clear [--all]          완료 항목(또는 전부) 지우기
todo path                   데이터 파일 경로
```
`<번호|글자>`는 `todo ls`의 번호이거나, 할 일에 들어 있는 글자(하나만 일치할 때).

Claude Code에서는 그냥 말하면 돼 ("장보기 추가해줘" → `todo add 장보기`). 매번 쓰게 하려면 `~/.claude/CLAUDE.md`에:
```markdown
- 할 일 목록은 `todo` CLI(TodoBar 메뉴바 앱)를 쓴다. 추가·완료·조회는 `todo ls / add / done / rm`.
```

## 아이폰 동기화
앱이 미리알림(EventKit)의 `TodoBar` 목록과 양방향으로 맞추고, iCloud가 그걸 아이폰에 전달해.
`~/.todo-bar/sync.json`에 마지막 동기화 상태를 기억해 두고, Mac·기준·미리알림을 비교해 바뀐 쪽을 반대편에 반영해. 둘 다 바뀌면 Mac 우선.
영상 소스는 [`promo/`](promo).

## 데이터 파일
- `~/.todo-bar/todos.json` (`TODO_BAR_DIR`로 폴더 변경). FSEvents로 감시해서 직접 고쳐도 바로 반영돼.
- `text`만 필수, 나머지는 자동으로 채워져:
  ```json
  [
    { "id": 1, "text": "보고서 초안 쓰기", "done": false, "createdAt": "2026-11-18T01:00:00Z" },
    { "text": "손으로 추가한 항목" }
  ]
  ```
- 앱과 CLI는 `.lock`을 걸고 원자적으로 저장해서 동시에 바꿔도 서로 안 덮어써. JSON이 깨져 있으면 아무도 덮어쓰지 않고 패널에 오류를 보여줘.

## 구조
```
Sources/Shared/TodoFile.swift   데이터 모델 + 파일 읽기/쓰기 (앱·CLI 공용)
Sources/App/                    메뉴바 앱 (AppKit + SwiftUI), ReminderSync.swift = 미리알림 동기화
Sources/CLI/main.swift          todo CLI
tools/make-icons.swift          assets/character.png로 앱 아이콘 생성
promo/                          동기화 영상 소스 (HTML + 병렬 렌더러)
```

## 라이선스
MIT
