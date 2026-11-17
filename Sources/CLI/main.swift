// `todo` — edits the same file the menu bar app shows. The app picks up every change instantly.
import Foundation

let usage = """
사용법: todo <명령> [인자]

  todo                     할 일 목록 (= todo ls)
  todo ls [--json]         목록 보기 (--json: 원본 JSON)
  todo add <할 일>          추가  (예: todo add 보고서 초안 쓰기)
  todo done <번호|글자>...   완료 표시
  todo undo <번호|글자>...   완료 취소
  todo rm <번호|글자>...     삭제
  todo edit <번호> <새 내용>  내용 바꾸기
  todo clear [--all]       완료한 항목 지우기 (--all: 전부 지우기)
  todo path                데이터 파일 경로

<번호|글자>: `todo ls`의 번호, 또는 할 일에 들어 있는 글자(하나만 일치할 때).
데이터 파일: ~/.todo-bar/todos.json (TODO_BAR_DIR 환경변수로 폴더 변경 가능)
"""

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

func line(_ t: Todo) -> String { "\(String(format: "%3d", t.id))  \(t.done ? "✓" : "○")  \(t.text)" }

func printList(_ todos: [Todo]) {
    if todos.isEmpty { print("할 일이 없어요. `todo add <할 일>`로 추가하세요."); return }
    let open = todos.filter { !$0.done }, done = todos.filter(\.done)
    (open + done).forEach { print(line($0)) }
    print(open.isEmpty ? "\n🎉 전부 끝! (\(done.count)개 완료)" : "\n남은 일 \(open.count)개 / 전체 \(todos.count)개")
}

/// Finds the index for "3" (id) or "보고서" (unique substring match).
func find(_ key: String, in todos: [Todo]) throws -> Int {
    if let id = Int(key.trimmingCharacters(in: CharacterSet(charactersIn: "#"))) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { throw TodoFile.Failure.unreadable("\(id)번 할 일이 없어요.") }
        return i
    }
    let hits = todos.indices.filter { todos[$0].text.localizedCaseInsensitiveContains(key) }
    if hits.count == 1 { return hits[0] }
    if hits.isEmpty { throw TodoFile.Failure.unreadable("'\(key)'가 들어간 할 일이 없어요.") }
    throw TodoFile.Failure.unreadable("'\(key)'가 여러 개와 일치해요: " + hits.map { "#\(todos[$0].id)" }.joined(separator: ", ") + " — 번호로 지정하세요.")
}

var args = Array(CommandLine.arguments.dropFirst())
let cmd = args.isEmpty ? "ls" : args.removeFirst()

do {
    switch cmd {
    case "ls", "list":
        let todos = try TodoFile.load()
        if args.contains("--json") {
            print(FileManager.default.fileExists(atPath: TodoFile.url.path)
                  ? (try String(contentsOf: TodoFile.url, encoding: .utf8)) : "[]")
        } else { printList(todos) }

    case "add", "a":
        let text = args.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { fail("추가할 내용을 적어주세요: todo add <할 일>") }
        var added: Todo!
        try TodoFile.update { todos in
            added = Todo(id: TodoFile.nextID(todos), text: text)
            todos.append(added)
        }
        print("추가: \(line(added))")

    case "done", "do", "check", "undo", "uncheck":
        guard !args.isEmpty else { fail("번호를 적어주세요: todo \(cmd) <번호>") }
        let mark = !["undo", "uncheck"].contains(cmd)
        let todos = try TodoFile.update { todos in
            for key in args {
                let i = try find(key, in: todos)
                todos[i].done = mark
                todos[i].doneAt = mark ? Date() : nil
                print("\(mark ? "완료" : "완료 취소"): \(line(todos[i]))")
            }
        }
        if mark, todos.allSatisfy(\.done) { print("🎉 전부 끝! 수고했어요.") }

    case "rm", "remove", "del", "delete":
        guard !args.isEmpty else { fail("번호를 적어주세요: todo rm <번호>") }
        try TodoFile.update { todos in
            let idx = try args.map { try find($0, in: todos) }
            for i in Set(idx).sorted(by: >) { print("삭제: \(line(todos[i]))"); todos.remove(at: i) }
        }

    case "edit":
        guard args.count >= 2 else { fail("todo edit <번호> <새 내용>") }
        let key = args.removeFirst()
        try TodoFile.update { todos in
            let i = try find(key, in: todos)
            todos[i].text = args.joined(separator: " ")
            print("수정: \(line(todos[i]))")
        }

    case "clear":
        let all = args.contains("--all")
        var n = 0
        try TodoFile.update { todos in
            let before = todos.count
            todos.removeAll { all || $0.done }
            n = before - todos.count
        }
        print("\(n)개 지웠어요.")

    case "path":
        print(TodoFile.url.path)

    case "help", "-h", "--help":
        print(usage)

    default:
        fail("알 수 없는 명령: \(cmd)\n\n" + usage)
    }
} catch {
    fail("\(error)")
}
