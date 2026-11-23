import EventKit
import Foundation

/// Two-way sync between todos.json and a "TodoBar" list in Apple Reminders (iCloud carries that list to the iPhone).
/// `~/.todo-bar/sync.json` remembers, per to-do, which reminder it is and what both sides looked like at the last sync,
/// so each run can tell which side changed. todos.json itself keeps its format; the CLI never knows about any of this.
final class ReminderSync {
    private struct Entry: Codable { var rid: String; var text: String; var done: Bool; var created: Int }

    static let listName = "TodoBar"

    private let ek = EKEventStore()
    private var started = false
    private var running = false, again = false
    private var debounce: Timer?
    private var mapURL: URL { TodoFile.dir.appendingPathComponent("sync.json") }

    func start() {
        guard !started else { return }
        started = true
        let done: (Bool, Error?) -> Void = { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self, granted else { NSLog("TodoBar: 미리알림 접근이 허용되지 않아 동기화를 건너뜁니다"); return }
                NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: self.ek, queue: .main) { [weak self] _ in
                    self?.request()
                }
                self.request()
            }
        }
        if #available(macOS 14, *) { ek.requestFullAccessToReminders(completion: done) }
        else { ek.requestAccess(to: .reminder, completion: done) }
    }

    /// Coalesces bursts (our own saves also fire EKEventStoreChanged) into one run.
    func request() {
        guard started else { return }
        debounce?.invalidate()
        debounce = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in self?.run() }
    }

    private func run() {
        guard !running else { again = true; return }
        guard let cal = calendar() else { return }
        running = true
        ek.fetchReminders(matching: ek.predicateForReminders(in: [cal])) { [weak self] found in
            DispatchQueue.main.async {
                guard let self else { return }
                self.merge(found ?? [], cal)
                self.running = false
                if self.again { self.again = false; self.run() }
            }
        }
    }

    private func calendar() -> EKCalendar? {
        if let c = ek.calendars(for: .reminder).first(where: { $0.title == Self.listName }) { return c }
        let c = EKCalendar(for: .reminder, eventStore: ek)
        c.title = Self.listName
        // Prefer iCloud: a list in a local-only account would never reach the iPhone.
        guard let source = ek.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" })
                ?? ek.defaultCalendarForNewReminders()?.source else { return nil }
        c.source = source
        do { try ek.saveCalendar(c, commit: true); return c } catch { NSLog("TodoBar: 목록을 만들 수 없어요: \(error)"); return nil }
    }

    private func loadMap() -> [String: Entry] {
        guard let d = try? Data(contentsOf: mapURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: d)) ?? [:]
    }

    private func merge(_ reminders: [EKReminder], _ cal: EKCalendar) {
        let old = loadMap()
        var byRID = [String: EKReminder]()
        for r in reminders { byRID[r.calendarItemIdentifier] = r }
        var new = [String: Entry]()
        var seen = Set<String>()

        @discardableResult
        func push(_ t: Todo, to r: EKReminder) -> Bool {
            r.title = t.text
            r.isCompleted = t.done
            return (try? ek.save(r, commit: true)) != nil
        }

        do {
            try TodoFile.update { todos in
                var out = [Todo]()
                for var t in todos {
                    let key = String(t.id), created = Int(t.createdAt.timeIntervalSince1970)
                    if let e = old[key], e.created == created {
                        guard let r = byRID[e.rid] else { continue } // deleted on the phone → delete here too
                        seen.insert(e.rid)
                        let title = r.title ?? ""
                        let todoChanged = t.text != e.text || t.done != e.done
                        let remChanged = (!title.isEmpty && title != e.text) || r.isCompleted != e.done
                        if todoChanged {
                            push(t, to: r)
                        } else if remChanged {
                            if !title.isEmpty { t.text = title }
                            t.done = r.isCompleted
                            t.doneAt = t.done ? (r.completionDate ?? Date()) : nil
                        }
                        new[key] = Entry(rid: e.rid, text: t.text, done: t.done, created: created)
                    } else {
                        // New on the Mac side: create its reminder. Without a successful save it simply retries next time.
                        let r = EKReminder(eventStore: ek)
                        r.calendar = cal
                        if push(t, to: r) {
                            seen.insert(r.calendarItemIdentifier)
                            new[key] = Entry(rid: r.calendarItemIdentifier, text: t.text, done: t.done, created: created)
                        }
                    }
                    out.append(t)
                }
                // Reminders the Mac doesn't know yet were added on the phone. Ignore untitled ones (iOS makes an empty row while typing).
                let known = Set(old.values.map(\.rid))
                for r in reminders where !seen.contains(r.calendarItemIdentifier) && !known.contains(r.calendarItemIdentifier) {
                    let title = (r.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { continue }
                    var t = Todo(id: TodoFile.nextID(out), text: title)
                    t.createdAt = Date(timeIntervalSince1970: floor((r.creationDate ?? Date()).timeIntervalSince1970))
                    t.done = r.isCompleted
                    t.doneAt = t.done ? (r.completionDate ?? Date()) : nil
                    seen.insert(r.calendarItemIdentifier)
                    new[String(t.id)] = Entry(rid: r.calendarItemIdentifier, text: title, done: t.done, created: Int(t.createdAt.timeIntervalSince1970))
                    out.append(t)
                }
                // Removed from todos.json (CLI, panel) → remove from Reminders.
                let kept = Set(new.values.map(\.rid))
                for e in old.values where !kept.contains(e.rid) {
                    if let r = byRID[e.rid] { try? ek.remove(r, commit: true) }
                }
                todos = out
            }
            if let d = try? JSONEncoder().encode(new) { try? d.write(to: mapURL, options: .atomic) }
        } catch {
            NSLog("TodoBar: 동기화 실패: \(error)")
        }
    }
}
