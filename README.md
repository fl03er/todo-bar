# TodoBar

<img src="docs/character.png" width="88" align="right">

macOS 메뉴바에 상주하는 간단한 투두리스트.
메뉴바의 파란 캐릭터를 누르면 할 일 목록이 열리고, 옆 숫자는 남은 할 일 개수예요.
터미널(또는 Claude Code)에서 `todo` 명령으로 추가·완료·삭제하면 앱에 바로 반영됩니다.
할 일을 전부 끝내면 캐릭터 눈이 통통 뛰고 컨페티가 터져요 🎉

<p align="center"><img src="docs/celebrate.png" width="300"></p>

## 설치

### 릴리스 받기
1. [Releases](../../releases)에서 `TodoBar-x.y.z.zip`을 받아 풀고 `TodoBar.app`을 `~/Applications`(또는 `/Applications`)로 옮깁니다.
2. 공증(notarize)되지 않은 앱이라 처음엔 우클릭 → **열기**로 실행하세요. (또는 터미널에서 `xattr -dr com.apple.quarantine ~/Applications/TodoBar.app`)
3. CLI 연결:
   ```bash
   mkdir -p ~/.local/bin && ln -sf ~/Applications/TodoBar.app/Contents/MacOS/todo ~/.local/bin/todo
   ```
   (`~/.local/bin`이 `PATH`에 있어야 합니다.)

### 소스로 빌드
Xcode Command Line Tools(Swift 5.9+), macOS 13 이상.
```bash
git clone https://github.com/<you>/todo-bar.git && cd todo-bar
./build.sh install     # 빌드 → ~/Applications/TodoBar.app, ~/.local/bin/todo 링크, 실행
```
`./build.sh`는 이 폴더에 앱만 만들고, `./build.sh release`는 유니버설(Apple Silicon + Intel) zip을 `dist/`에 만듭니다.

로그인 시 자동 실행: 시스템 설정 → 일반 → 로그인 항목 → TodoBar 추가.

## 메뉴바에서
- **추가**: 맨 위 입력칸에 적고 ⏎
- **완료**: 동그라미(또는 글자)를 클릭. 다시 누르면 취소
- **삭제**: 항목에 마우스를 올리고 ✕
- **완료 항목 지우기**: 패널 아래쪽
- 항목 오른쪽의 작은 `#3`이 CLI에서 쓰는 번호예요.

## `todo` CLI
```
todo                       목록 (= todo ls)
todo ls [--json]           목록 보기 (--json: 원본 JSON)
todo add <할 일>            추가          예) todo add 보고서 초안 쓰기
todo done <번호|글자>...     완료 표시      예) todo done 2 3  /  todo done 보고서
todo undo <번호|글자>...     완료 취소
todo rm <번호|글자>...       삭제
todo edit <번호> <새 내용>   내용 바꾸기
todo clear [--all]         완료한 항목 지우기 (--all: 전부 지우기)
todo path                  데이터 파일 경로
```
`<번호|글자>`는 `todo ls`의 번호이거나, 할 일에 들어 있는 글자(하나만 일치할 때)입니다.

```
$ todo add 보고서 초안 쓰기
추가:   1  ○  보고서 초안 쓰기
$ todo done 보고서
완료:   1  ✓  보고서 초안 쓰기
🎉 전부 끝! 수고했어요.
```

## Claude Code에서 쓰기
Claude Code는 셸 명령을 실행할 수 있어서 그냥 말하면 됩니다.

> "할 일에 '장보기' 추가해줘" → `todo add 장보기`
> "오늘 할 일 보여줘" → `todo ls`
> "보고서 건 완료 처리해줘" → `todo done 보고서`

매번 `todo`를 쓰게 하려면 `~/.claude/CLAUDE.md`에 한 줄 넣어두세요.
```markdown
- 할 일 목록은 `todo` CLI(TodoBar 메뉴바 앱)를 쓴다. 할 일 추가·완료·조회는 `todo ls / add / done / rm`으로.
```

## 데이터 파일
- 위치: `~/.todo-bar/todos.json` (`TODO_BAR_DIR` 환경변수로 폴더 변경)
- 앱이 FSEvents로 폴더를 지켜보고 있어서, 파일이 바뀌는 즉시 반영돼요. 에디터로 직접 고쳐도 됩니다.
- 형식 — `text`만 필수이고, 나머지는 비워두면 자동으로 채워집니다.
  ```json
  [
    { "id": 1, "text": "보고서 초안 쓰기", "done": false, "createdAt": "2026-11-18T01:00:00Z" },
    { "text": "손으로 추가한 항목" }
  ]
  ```
- 앱과 CLI는 잠금(`.lock`)을 걸고 원자적으로 저장하므로 동시에 바꿔도 서로의 변경을 잃지 않아요. JSON이 깨져 있으면 아무도 덮어쓰지 않고, 앱은 패널에 오류를 보여줍니다.

## 구조
```
Sources/Shared/TodoFile.swift   데이터 모델 + 파일 읽기/쓰기 (앱·CLI 공용)
Sources/App/                    메뉴바 앱 (AppKit + SwiftUI)
Sources/CLI/main.swift          todo CLI
tools/make-icons.swift          assets/character.png로 메뉴바·앱 아이콘 생성
```

## 라이선스
MIT
