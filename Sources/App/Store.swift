import Foundation
import CoreServices

/// The list as the app shows it. Reloads whenever todos.json changes on disk (CLI, Claude Code, an editor…).
final class TodoStore: ObservableObject {
    @Published private(set) var todos: [Todo] = []
    @Published private(set) var error: String?
    /// Bumped each time the last open item gets checked off.
    @Published private(set) var celebration = 0

    var onChange: (() -> Void)?
    var onAllDone: (() -> Void)?

    var remaining: Int { todos.filter { !$0.done }.count }
    var allDone: Bool { !todos.isEmpty && remaining == 0 }
    var sorted: [Todo] { todos.filter { !$0.done } + todos.filter(\.done) }

    private var stream: FSEventStreamRef?
    private var timer: Timer?

    init() {
        reload()
        watch()
    }

    func reload() {
        do { apply(try TodoFile.load()); error = nil } catch { self.error = "\(error)" }
    }

    func add(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        mutate { $0.append(Todo(id: TodoFile.nextID($0), text: t)) }
    }
    func toggle(_ id: Int) {
        mutate { todos in
            guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
            todos[i].done.toggle()
            todos[i].doneAt = todos[i].done ? Date() : nil
        }
    }
    func remove(_ id: Int) { mutate { $0.removeAll { $0.id == id } } }
    func clearDone() { mutate { $0.removeAll(where: \.done) } }

    private func mutate(_ change: (inout [Todo]) -> Void) {
        do { apply(try TodoFile.update(change)); error = nil } catch { self.error = "\(error)" }
    }

    private func apply(_ new: [Todo]) {
        guard new != todos else { return }
        let old = todos
        let wasAllDone = allDone
        todos = new
        // Celebrate only when something was just checked off and nothing is left — not on launch, not on delete.
        let justChecked = new.contains { t in t.done && old.contains { $0.id == t.id && !$0.done } }
        if allDone && !wasAllDone && justChecked {
            celebration += 1
            onAllDone?()
        }
        onChange?()
    }

    /// FSEvents on the folder catches both in-place writes and atomic replace (temp file + rename).
    private func watch() {
        try? FileManager.default.createDirectory(at: TodoFile.dir, withIntermediateDirectories: true)
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<TodoStore>.fromOpaque(info).takeUnretainedValue().reload()
        }
        let flags = kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot
        if let s = FSEventStreamCreate(nil, callback, &ctx, [TodoFile.dir.path] as CFArray,
                                       FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.05, UInt32(flags)) {
            FSEventStreamSetDispatchQueue(s, .main)
            FSEventStreamStart(s)
            stream = s
        }
        // Safety net in case the folder is deleted and recreated under the stream.
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.reload() }
    }
}
