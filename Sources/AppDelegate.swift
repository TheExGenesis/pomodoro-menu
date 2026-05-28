import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = PomodoroSettings.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let settingsWindowController = SettingsWindowController()

    private var phase: TimerPhase = .focus
    private var queuedPhase: TimerPhase?
    private var state: TimerState = .idle
    private var focusCompletions = 0
    private var totalSeconds = PomodoroSettings.shared.durationSeconds(for: .focus)
    private var remainingSeconds = PomodoroSettings.shared.durationSeconds(for: .focus)
    private var endDate: Date?
    private var tickTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menu.delegate = self
        menu.autoenablesItems = false

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.toolTip = "Pomodoro Menu"
        }

        statusItem.menu = menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .pomodoroSettingsChanged,
            object: nil
        )
        refreshStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func toggleStartPause() {
        switch state {
        case .idle:
            startClock()
        case .finished:
            if let nextPhase = queuedPhase {
                phase = nextPhase
                queuedPhase = nil
            }
            resetForCurrentPhase(markIdle: true)
            startClock()
        case .paused:
            startClock()
        case .running:
            pauseClock()
        }
    }

    @objc private func resetTimer() {
        queuedPhase = nil
        resetForCurrentPhase(markIdle: true)
    }

    @objc private func choosePhase(_ sender: NSMenuItem) {
        guard TimerPhase.allCases.indices.contains(sender.tag) else { return }
        phase = TimerPhase.allCases[sender.tag]
        queuedPhase = nil
        resetForCurrentPhase(markIdle: true)
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard PomodoroDefaults.presets.indices.contains(sender.tag) else { return }
        settings.apply(PomodoroDefaults.presets[sender.tag])
    }

    @objc private func toggleSound() {
        settings.soundEnabled.toggle()
    }

    @objc private func toggleNotifications() {
        guard !settings.notificationEnabled else {
            settings.notificationEnabled = false
            return
        }

        CompletionNotifier.shared.requestAuthorization { [weak self] allowed in
            self?.settings.notificationEnabled = allowed
        }
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func settingsChanged() {
        if state == .idle || state == .finished {
            totalSeconds = settings.durationSeconds(for: displayPhase)
            if state == .idle {
                remainingSeconds = totalSeconds
            }
        }
        refreshStatusItem()
    }

    private func startClock() {
        state = .running
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
        refreshStatusItem()
    }

    private func pauseClock() {
        updateRemainingFromClock()
        state = .paused
        tickTimer?.invalidate()
        tickTimer = nil
        endDate = nil
        refreshStatusItem()
    }

    private func resetForCurrentPhase(markIdle: Bool) {
        tickTimer?.invalidate()
        tickTimer = nil
        endDate = nil
        if markIdle {
            state = .idle
        }
        totalSeconds = settings.durationSeconds(for: phase)
        remainingSeconds = totalSeconds
        refreshStatusItem()
    }

    private func tick() {
        updateRemainingFromClock()

        if remainingSeconds <= 0 {
            finishTimer()
        } else {
            refreshStatusItem()
        }
    }

    private func updateRemainingFromClock() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    private func finishTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
        endDate = nil
        remainingSeconds = 0
        state = .finished

        let completedPhase = phase
        if completedPhase == .focus {
            focusCompletions += 1
        }

        queuedPhase = nextPhase(after: completedPhase)
        refreshStatusItem()

        if settings.soundEnabled {
            CompletionNotifier.shared.playCompletionSound(named: settings.soundName)
        }

        if settings.notificationEnabled {
            CompletionNotifier.shared.notifyCompletion(of: completedPhase, nextPhase: queuedPhase)
        }

        guard settings.autoStartNextPhase, let nextPhase = queuedPhase else { return }
        phase = nextPhase
        queuedPhase = nil
        resetForCurrentPhase(markIdle: true)
        startClock()
    }

    private func nextPhase(after completedPhase: TimerPhase) -> TimerPhase? {
        switch completedPhase {
        case .focus:
            return focusCompletions.isMultiple(of: settings.longBreakEvery) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let time = NSMenuItem(title: statusDetail, action: nil, keyEquivalent: "")
        time.isEnabled = false
        menu.addItem(time)

        if state == .finished, let queuedPhase {
            let next = NSMenuItem(title: "Next: \(queuedPhase.title)", action: nil, keyEquivalent: "")
            next.isEnabled = false
            menu.addItem(next)
        }

        menu.addItem(.separator())
        menu.addItem(commandItem(title: toggleTitle, symbol: toggleSymbol, action: #selector(toggleStartPause)))

        let reset = commandItem(title: "Reset", symbol: "arrow.counterclockwise", action: #selector(resetTimer))
        reset.isEnabled = state != .idle || remainingSeconds != settings.durationSeconds(for: phase)
        menu.addItem(reset)
        menu.addItem(.separator())

        for (index, timerPhase) in TimerPhase.allCases.enumerated() {
            let item = commandItem(
                title: "\(timerPhase.title) \(settings.minutes(for: timerPhase)) min",
                symbol: timerPhase.symbolName,
                action: #selector(choosePhase)
            )
            item.tag = index
            item.state = displayPhase == timerPhase ? .on : .off
            menu.addItem(item)
        }

        let presetMenu = NSMenu()
        for (index, preset) in PomodoroDefaults.presets.enumerated() {
            let item = NSMenuItem(title: preset.menuTitle, action: #selector(applyPreset), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = settings.matchingPreset() == preset ? .on : .off
            presetMenu.addItem(item)
        }
        let presetRoot = NSMenuItem(title: "Regime", action: nil, keyEquivalent: "")
        menu.setSubmenu(presetMenu, for: presetRoot)
        menu.addItem(presetRoot)
        menu.addItem(.separator())

        let sound = commandItem(title: "Ring Sound", symbol: "speaker.wave.2.fill", action: #selector(toggleSound))
        sound.state = settings.soundEnabled ? .on : .off
        menu.addItem(sound)

        let notifications = commandItem(title: "Notifications", symbol: "bell.badge.fill", action: #selector(toggleNotifications))
        notifications.state = settings.notificationEnabled ? .on : .off
        menu.addItem(notifications)

        menu.addItem(commandItem(title: "Settings...", symbol: "gearshape.fill", action: #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(commandItem(title: "Quit Pomodoro", symbol: "xmark.circle", action: #selector(quitApp)))
    }

    private func commandItem(title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    private var displayPhase: TimerPhase {
        if state == .finished {
            return queuedPhase ?? phase
        }
        return phase
    }

    private var statusTitle: String {
        switch state {
        case .idle:
            return "\(phase.title) Ready"
        case .running:
            return "\(phase.title) Running"
        case .paused:
            return "\(phase.title) Paused"
        case .finished:
            return "\(phase.title) Done"
        }
    }

    private var statusDetail: String {
        switch state {
        case .finished:
            return "Complete"
        default:
            return "\(clockText(remainingSeconds)) remaining"
        }
    }

    private var toggleTitle: String {
        switch state {
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .finished:
            return "Start \((queuedPhase ?? phase).title)"
        case .idle:
            return "Start \(phase.title)"
        }
    }

    private var toggleSymbol: String {
        switch state {
        case .running:
            return "pause.fill"
        case .idle, .paused, .finished:
            return "play.fill"
        }
    }

    private func refreshStatusItem() {
        let clampedTotal = max(totalSeconds, 1)
        let fractionRemaining = CGFloat(max(0, min(remainingSeconds, clampedTotal))) / CGFloat(clampedTotal)
        if let button = statusItem.button {
            button.image = progressIcon(fractionRemaining: fractionRemaining)
            button.title = displayText(for: remainingSeconds)
            button.toolTip = toolTipText
        }
    }

    private var toolTipText: String {
        switch state {
        case .finished:
            if let queuedPhase {
                return "\(phase.title) complete. Next: \(queuedPhase.title)"
            }
            return "\(phase.title) complete"
        default:
            return "\(phase.title): \(clockText(remainingSeconds)) remaining"
        }
    }

    private func displayText(for seconds: Int) -> String {
        if settings.showSecondsUnderMinute && seconds > 0 && seconds < 60 {
            return "\(seconds)s"
        }
        return "\(displayMinutes(seconds))m"
    }

    private func displayMinutes(_ seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return Int(ceil(Double(seconds) / 60.0))
    }

    private func clockText(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        return String(format: "%02d:%02d", safeSeconds / 60, safeSeconds % 60)
    }

    private func progressIcon(fractionRemaining: CGFloat) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)

        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = false
        }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let ringRect = NSRect(x: 3.2, y: 3.2, width: 15.6, height: 15.6)
        let center = NSPoint(x: ringRect.midX, y: ringRect.midY)
        let radius = ringRect.width / 2.0

        let background = NSBezierPath(ovalIn: ringRect)
        background.lineWidth = 2.2
        NSColor.secondaryLabelColor.withAlphaComponent(0.34).setStroke()
        background.stroke()

        let progress = NSBezierPath()
        progress.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - 360 * fractionRemaining,
            clockwise: true
        )
        progress.lineWidth = 2.4
        progress.lineCapStyle = .round
        accentColor(for: fractionRemaining).setStroke()
        progress.stroke()

        return image
    }

    private func accentColor(for fractionRemaining: CGFloat) -> NSColor {
        if state == .finished || fractionRemaining <= 0.0001 {
            return NSColor.systemGreen
        }

        switch phase {
        case .focus:
            return NSColor.controlAccentColor
        case .shortBreak:
            return NSColor.systemTeal
        case .longBreak:
            return NSColor.systemIndigo
        }
    }
}
