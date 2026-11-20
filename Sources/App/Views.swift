import SwiftUI

enum Theme { // purple, like the character's background
    static let light = Color(red: 0xB0 / 255, green: 0x98 / 255, blue: 0xF8 / 255) // #B098F8
    static let deep = Color(red: 0x7C / 255, green: 0x55 / 255, blue: 0xF0 / 255)  // #7C55F0
    static let mist = Color(red: 0xF4 / 255, green: 0xF0 / 255, blue: 0xFF / 255)  // pale lilac surface
    static let ink = Color(red: 0x22 / 255, green: 0x1D / 255, blue: 0x33 / 255)
    static let faded = Color(red: 0x94 / 255, green: 0x8F / 255, blue: 0xA8 / 255)
    static let gradient = LinearGradient(colors: [light, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Character

/// The cloud with one eye (see CloudArt). At rest it blinks now and then and looks around;
/// `excited`: the eye goes wide and rolls while the cloud hops. `asleep`: eye shut, no beam (nothing left to do).
struct Buddy: View {
    var excited: Bool
    var asleep = false
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                ctx.withCGContext { cg in
                    CloudArt.draw(cg, in: CGRect(origin: .zero, size: size), t: tl.date.timeIntervalSinceReferenceDate, excited: excited, asleep: asleep)
                }
            }
        }
        .aspectRatio(CloudArt.aspect(), contentMode: .fit)
    }
}

// MARK: - Confetti

struct Confetti: View {
    struct Piece { var x, vx, vy, spin, size: Double; var color: Color; var round: Bool }
    let start = Date()
    let pieces: [Piece] = (0..<70).map { _ in
        Piece(x: .random(in: 0.3...0.7), vx: .random(in: -170...170), vy: .random(in: -430 ... -200),
              spin: .random(in: -9...9), size: .random(in: 5...9),
              color: [Theme.light, Theme.deep, Color(red: 1, green: 0.83, blue: 0.29), Color(red: 1, green: 0.56, blue: 0.69),
                      Color(red: 0.36, green: 0.86, blue: 0.7)].randomElement()!,
              round: .random())
    }
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                let fade = max(0, min(1, (3.0 - t) / 0.8))
                for p in pieces {
                    let x = p.x * size.width + p.vx * t
                    let y = size.height * 0.42 + p.vy * t + 0.5 * 520 * t * t
                    var c = ctx
                    c.opacity = fade
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.spin * t))
                    let r = CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.round ? p.size : p.size / 2)
                    c.fill(p.round ? Path(ellipseIn: r) : Path(r), with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Popover content

struct ContentView: View {
    @ObservedObject var store: TodoStore
    @State private var draft = ""
    @State private var confetti: UUID?
    @State private var bounce = false
    @State private var excited = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                header
                input
                if let e = store.error {
                    Text(e).font(.caption).foregroundStyle(.red).padding(.horizontal, 16).padding(.bottom, 8)
                }
                if store.allDone { cheer }
                list
                footer
            }
            if let id = confetti { Confetti().id(id) }
        }
        .frame(width: 320)
        .background(Color.white)
        .onReceive(store.$celebration.dropFirst()) { _ in celebrate() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Buddy(excited: excited, asleep: store.remaining == 0 && !excited)
                .frame(width: 44, height: 42)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .scaleEffect(bounce ? 1.18 : 1)
                .rotationEffect(.degrees(bounce ? -8 : 0))
            VStack(alignment: .leading, spacing: 2) {
                Text("할 일").font(.system(size: 17, weight: .bold, design: .rounded))
                Text(subtitle).font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.9)
            }
            Spacer()
            if !store.todos.isEmpty {
                Text("\(store.todos.count - store.remaining)/\(store.todos.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.white.opacity(0.22), in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.gradient)
    }

    private var subtitle: String {
        if store.todos.isEmpty { return "비어 있어요" }
        if store.allDone { return "전부 끝! 수고했어요" }
        return "\(store.remaining)개 남았어요"
    }

    private var input: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.deep)
            TextField("할 일 추가", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($inputFocused)
                .onSubmit { store.add(draft); draft = "" }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Theme.mist, in: RoundedRectangle(cornerRadius: 10))
        .padding(12)
    }

    private var cheer: some View {
        HStack(spacing: 8) {
            Text("🎉").font(.system(size: 18))
            Text("오늘 할 일을 전부 끝냈어요!").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.deep)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.mist, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12).padding(.bottom, 8)
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder private var list: some View {
        if store.todos.isEmpty {
            VStack(spacing: 6) {
                Text("할 일이 없어요").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.faded)
                Text("위에 적거나, 터미널에서 todo add …").font(.system(size: 11)).foregroundStyle(Theme.faded.opacity(0.8))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 26)
        } else {
            let rows = VStack(spacing: 0) {
                ForEach(store.sorted) { t in
                    TodoRow(todo: t, toggle: { withAnimation(.easeOut(duration: 0.2)) { store.toggle(t.id) } },
                            remove: { withAnimation { store.remove(t.id) } })
                }
            }
            if store.todos.count > 8 {
                ScrollView { rows }.frame(height: 340)
            } else {
                rows
            }
        }
    }

    private var footer: some View {
        HStack {
            if store.todos.contains(where: \.done) {
                Button("완료 항목 지우기") { withAnimation { store.clearDone() } }
            }
            Spacer()
            Button("종료") { NSApp.terminate(nil) }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Theme.faded)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Theme.mist).frame(height: 1) }
        .padding(.top, 6)
    }

    private func celebrate() {
        confetti = UUID()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.35)) { bounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { bounce = false }
        }
        excited = true
        let id = confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if confetti == id { confetti = nil; excited = false }
        }
    }
}

/// The card that pops under the menu bar icon when everything gets done from outside the panel.
struct CheerCard: View {
    let count: Int
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                Buddy(excited: true).frame(width: 60, height: 57)
                Text("전부 끝! 🎉").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("\(count)개 모두 완료했어요").font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Confetti()
        }
        .frame(width: 230, height: 150)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TodoRow: View {
    let todo: Todo
    let toggle: () -> Void
    let remove: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button(action: toggle) {
                ZStack {
                    Circle().strokeBorder(todo.done ? Color.clear : Theme.light, lineWidth: 1.6)
                    if todo.done {
                        Circle().fill(Theme.gradient)
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                    }
                }
                .frame(width: 18, height: 18)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
            }
            .buttonStyle(.plain)

            Text(todo.text)
                .font(.system(size: 13))
                .strikethrough(todo.done, color: Theme.faded)
                .foregroundStyle(todo.done ? Theme.faded : Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)

            if hover {
                Button(action: remove) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.faded)
                }
                .buttonStyle(.plain).help("삭제")
            } else {
                Text("#\(todo.id)").font(.system(size: 10, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.faded.opacity(0.6))
                    .help("CLI 번호: todo done \(todo.id)")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(hover ? Theme.mist.opacity(0.7) : .clear)
        .onHover { hover = $0 }
    }
}
