import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var tap: KeyTap?
    private var permissionTimer: Timer?
    private var settings: SettingsWindowController?
    private var toggleItem: NSMenuItem!
    private var hotkey = Hotkey.load()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Cài đặt…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Thoát", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        startWhenTrusted(prompt: true)
        updateTitle()
    }

    private func startWhenTrusted(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            // Chờ người dùng cấp quyền trong System Settings rồi tự khởi động hook
            permissionTimer?.invalidate()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.startWhenTrusted(prompt: false)
            }
            return
        }

        permissionTimer?.invalidate()
        permissionTimer = nil
        guard tap == nil else { return }

        let keyTap = KeyTap()
        keyTap.hotkey = hotkey
        keyTap.onToggle = { [weak self] in
            DispatchQueue.main.async { self?.toggle() }
        }
        if keyTap.start() {
            tap = keyTap
        } else {
            let alert = NSAlert()
            alert.messageText = "Không tạo được event tap"
            alert.informativeText = "Hãy kiểm tra quyền Accessibility trong System Settings."
            alert.runModal()
        }
        updateTitle()
    }

    /// Trạng thái người dùng chọn, tách khỏi việc tạm ngắt lúc ghi phím tắt.
    private var isEnabled = true

    @objc private func toggle() {
        isEnabled.toggle()
        tap?.enabled = isEnabled
        updateTitle()
    }

    @objc private func openSettings() {
        if settings == nil {
            let controller = SettingsWindowController(hotkey: hotkey)
            controller.onHotkeyChange = { [weak self] new in
                self?.hotkey = new
                self?.tap?.hotkey = new
                self?.updateTitle()
            }
            // Tạm ngắt bộ gõ khi đang ghi phím tắt để phím không bị biến đổi
            controller.onRecordingChange = { [weak self] recording in
                guard let tap = self?.tap else { return }
                tap.enabled = recording ? false : (self?.isEnabled ?? true)
            }
            settings = controller
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.showWindow(nil)
        settings?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateTitle() {
        toggleItem.title = "Bật/tắt tiếng Việt  (\(hotkey.display))"
        guard tap != nil else {
            statusItem.button?.title = "⚠️"
            return
        }
        statusItem.button?.title = isEnabled ? "VI" : "EN"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
