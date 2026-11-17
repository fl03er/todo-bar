// Shared by the app and the `todo` CLI: the to-do list lives in one JSON file that both read and write.
import Foundation

struct Todo: Codable, Equatable, Identifiable {
    var id: Int
    var text: String
    var done: Bool
    var createdAt: Date
    var doneAt: Date?

    init(id: Int, text: String) {
        self.id = id; self.text = text; done = false; createdAt = Date(); doneAt = nil
    }

    // Lenient so the file can be edited by hand: only "text" is required.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        text = try c.decode(String.self, forKey: .text)
        done = (try? c.decode(Bool.self, forKey: .done)) ?? false
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        doneAt = try? c.decode(Date.self, forKey: .doneAt)
    }
}

enum TodoFile {
    /// `~/.todo-bar`, or `$TODO_BAR_DIR` when set.
    static var dir: URL {
        if let p = ProcessInfo.processInfo.environment["TODO_BAR_DIR"], !p.isEmpty {
            return URL(fileURLWithPath: (p as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".todo-bar", isDirectory: true)
    }
    static var url: URL { dir.appendingPathComponent("todos.json") }

    enum Failure: Error, CustomStringConvertible {
        case unreadable(String)
        var description: String { switch self { case .unreadable(let m): return m } }
    }

    /// Missing file → empty list. A file that isn't valid JSON throws, so nobody overwrites it.
    static func load() throws -> [Todo] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        do {
            return fixIDs(try dec.decode([Todo].self, from: data))
        } catch {
            throw Failure.unreadable("\(url.path) 파일을 읽을 수 없어요 (JSON 형식 오류): \(error.localizedDescription)")
        }
    }

    static func save(_ todos: [Todo]) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try enc.encode(todos).write(to: url, options: .atomic) // temp file + rename: readers never see half a file
    }

    /// Read–modify–write under a lock so the app and the CLI don't lose each other's changes.
    @discardableResult
    static func update(_ change: (inout [Todo]) throws -> Void) throws -> [Todo] {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fd = open(dir.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o644)
        if fd >= 0 { flock(fd, LOCK_EX) }
        defer { if fd >= 0 { flock(fd, LOCK_UN); close(fd) } }
        var todos = try load()
        try change(&todos)
        try save(todos)
        return try load() // as stored (dates rounded to seconds), so it compares equal to later reloads
    }

    static func nextID(_ todos: [Todo]) -> Int { (todos.map(\.id).max() ?? 0) + 1 }

    /// Hand-added items may lack an id or reuse one: give those fresh ids.
    private static func fixIDs(_ todos: [Todo]) -> [Todo] {
        var seen = Set<Int>(), out = todos
        var next = nextID(todos)
        for i in out.indices {
            if out[i].id <= 0 || seen.contains(out[i].id) { out[i].id = next; next += 1 }
            seen.insert(out[i].id)
        }
        return out
    }
}
