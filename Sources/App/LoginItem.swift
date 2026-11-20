import ServiceManagement

/// Start-at-login, through the system's Login Items (shows up in System Settings → General → Login Items).
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch { return false }
    }

    /// Turns it on the first time the app runs; after that the user's choice (the panel's toggle) wins.
    static func enableOnFirstRun() {
        let key = "loginItemAsked"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        set(true)
    }
}
