import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = PomodoroSettings.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let settingsWindowController = SettingsWindowController()
    private let historyWindowController = HistoryWindowController()
    private let historyStore = PomodoroHistoryStore.shared

    private var phase: TimerPhase = .focus
    private var queuedPhase: TimerPhase?
    private var state: TimerState = .idle
    private var focusCompletions = 0
    private var totalSeconds = PomodoroSettings.shared.durationSeconds(for: .focus)
    private var remainingSeconds = PomodoroSettings.shared.durationSeconds(for: .focus)
    private var endDate: Date?
    private var tickTimer: Timer?
    private var activityFrame = 0
    private var currentFocusSession: PomodoroSession?

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
            beginTimerFromReadyState()
        case .finished:
            if let nextPhase = queuedPhase {
                phase = nextPhase
                queuedPhase = nil
            }
            resetForCurrentPhase(markIdle: true)
            beginTimerFromReadyState()
        case .paused:
            startClock()
        case .running:
            pauseClock()
        }
    }

    @objc private func resetTimer() {
        queuedPhase = nil
        currentFocusSession = nil
        resetForCurrentPhase(markIdle: true)
    }

    @objc private func endPomoEarly() {
        guard canEndPomoEarly else { return }
        if state == .running {
            updateRemainingFromClock()
        }
        completeTimer(playCompletionAlerts: false, endedEarly: true)
    }

    @objc private func choosePhase(_ sender: NSMenuItem) {
        guard TimerPhase.allCases.indices.contains(sender.tag) else { return }
        startPhase(TimerPhase.allCases[sender.tag])
    }

    private func startPhase(_ selectedPhase: TimerPhase) {
        if state == .running || state == .paused {
            if phase == .focus {
                if state == .running {
                    updateRemainingFromClock()
                }
                completeTimer(playCompletionAlerts: false, endedEarly: true, allowAutoStart: false)
            } else {
                stopClock()
                currentFocusSession = nil
            }
        }

        phase = selectedPhase
        queuedPhase = nil
        resetForCurrentPhase(markIdle: true)
        beginTimerFromReadyState()
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

    @objc private func openHistory() {
        historyWindowController.show()
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

    private func beginTimerFromReadyState() {
        if phase == .focus {
            guard let intention = promptForFocusIntention() else { return }
            currentFocusSession = PomodoroSession(
                startedAt: Date(),
                plannedSeconds: totalSeconds,
                intention: intention
            )
        } else {
            currentFocusSession = nil
        }

        startClock()
    }

    private func startClock() {
        state = .running
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        tickTimer?.invalidate()
        activityFrame = 0
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
        refreshStatusItem()
    }

    private func pauseClock() {
        updateRemainingFromClock()
        state = .paused
        stopClock()
        refreshStatusItem()
    }

    private func stopClock() {
        tickTimer?.invalidate()
        tickTimer = nil
        endDate = nil
    }

    private func resetForCurrentPhase(markIdle: Bool) {
        stopClock()
        if markIdle {
            state = .idle
        }
        totalSeconds = settings.durationSeconds(for: phase)
        remainingSeconds = totalSeconds
        refreshStatusItem()
    }

    private func tick() {
        updateRemainingFromClock()
        activityFrame = (activityFrame + 1) % 3

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
        completeTimer(playCompletionAlerts: true, endedEarly: false)
    }

    private func completeTimer(playCompletionAlerts: Bool, endedEarly: Bool) {
        completeTimer(playCompletionAlerts: playCompletionAlerts, endedEarly: endedEarly, allowAutoStart: true)
    }

    private func completeTimer(playCompletionAlerts: Bool, endedEarly: Bool, allowAutoStart: Bool) {
        stopClock()
        remainingSeconds = 0
        state = .finished

        let completedPhase = phase
        if completedPhase == .focus {
            focusCompletions += 1
        }

        queuedPhase = nextPhase(after: completedPhase)
        refreshStatusItem()

        if playCompletionAlerts && settings.soundEnabled {
            CompletionNotifier.shared.playCompletionSound(named: settings.soundName)
        }

        if playCompletionAlerts && settings.notificationEnabled {
            CompletionNotifier.shared.notifyCompletion(of: completedPhase, nextPhase: queuedPhase)
        }

        if completedPhase == .focus {
            completeCurrentFocusSession(endedEarly: endedEarly)
        } else {
            currentFocusSession = nil
        }

        guard allowAutoStart, let nextPhase = queuedPhase else { return }
        phase = nextPhase
        queuedPhase = nil
        resetForCurrentPhase(markIdle: true)
        beginTimerFromReadyState()
    }

    private func nextPhase(after completedPhase: TimerPhase) -> TimerPhase? {
        switch completedPhase {
        case .focus:
            return focusCompletions.isMultiple(of: settings.longBreakEvery) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

    private func completeCurrentFocusSession(endedEarly: Bool) {
        var session = currentFocusSession ?? PomodoroSession(
            startedAt: Date().addingTimeInterval(-TimeInterval(totalSeconds)),
            plannedSeconds: totalSeconds,
            intention: ""
        )
        session.endedAt = Date()

        let review = promptForFocusReview(for: session, endedEarly: endedEarly)
        session.outcome = review.outcome
        session.review = review.text
        historyStore.add(session)
        currentFocusSession = nil
    }

    private func promptForFocusIntention() -> String? {
        let field = ShortcutTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.placeholderString = "e.g. Draft the launch notes"

        let alert = NSAlert()
        alert.messageText = "What are you doing?"
        alert.informativeText = "Name this focus session before the timer starts."
        alert.alertStyle = .informational
        alert.accessoryView = field
        let startButton = alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        field.commandEnterAction = { [weak startButton] in
            startButton?.performClick(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return normalizedText(field.stringValue)
    }

    private func promptForFocusReview(for session: PomodoroSession, endedEarly: Bool) -> (outcome: PomodoroOutcome, text: String) {
        let outcomePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for outcome in [PomodoroOutcome.done, .partial, .missed] {
            outcomePopup.addItem(withTitle: outcome.title)
            outcomePopup.lastItem?.representedObject = outcome.rawValue
        }

        let question = NSTextField(labelWithString: "Did you do it?")
        let questionRow = NSStackView(views: [question, outcomePopup])
        questionRow.orientation = .horizontal
        questionRow.alignment = .centerY
        questionRow.spacing = 10

        let textView = ShortcutTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 96))
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.string = ""
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.containerSize = NSSize(width: 420, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView(frame: .zero)
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.heightAnchor.constraint(equalToConstant: 104).isActive = true
        scrollView.widthAnchor.constraint(equalToConstant: 420).isActive = true

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 168))
        let stack = NSStackView(views: [questionRow, NSTextField(labelWithString: "What happened?"), scrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        accessory.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: accessory.trailingAnchor),
            stack.topAnchor.constraint(equalTo: accessory.topAnchor),
            stack.bottomAnchor.constraint(equalTo: accessory.bottomAnchor)
        ])

        let alert = NSAlert()
        alert.messageText = "Review"
        let intention = normalizedText(session.intention)
        let statusText = endedEarly ? "Your focus timer ended early." : "Your focus timer finished."
        alert.informativeText = intention.isEmpty ? statusText : "\(statusText) You planned to: \(intention)"
        alert.alertStyle = .informational
        alert.accessoryView = accessory
        let saveButton = alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Skip")
        textView.commandEnterAction = { [weak saveButton] in
            saveButton?.performClick(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = textView
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return (.notRecorded, "")
        }

        let rawOutcome = outcomePopup.selectedItem?.representedObject as? String
        let outcome = rawOutcome.flatMap(PomodoroOutcome.init(rawValue:)) ?? .notRecorded
        return (outcome, normalizedText(textView.string))
    }

    private func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let time = NSMenuItem(title: statusDetail, action: nil, keyEquivalent: "")
        time.isEnabled = false
        menu.addItem(time)

        if let intention = currentFocusIntention {
            let intentionItem = NSMenuItem(title: "Doing: \(intention)", action: nil, keyEquivalent: "")
            intentionItem.isEnabled = false
            menu.addItem(intentionItem)
        }

        if state == .finished, let queuedPhase {
            let next = NSMenuItem(title: "Next: \(queuedPhase.title)", action: nil, keyEquivalent: "")
            next.isEnabled = false
            menu.addItem(next)
        }

        menu.addItem(.separator())
        menu.addItem(commandItem(title: toggleTitle, symbol: toggleSymbol, action: #selector(toggleStartPause)))

        let endEarly = commandItem(title: "End Pomo Early...", symbol: "stop.circle.fill", action: #selector(endPomoEarly))
        endEarly.isEnabled = canEndPomoEarly
        menu.addItem(endEarly)

        let reset = commandItem(title: "Reset", symbol: "arrow.counterclockwise", action: #selector(resetTimer))
        reset.isEnabled = state != .idle || remainingSeconds != settings.durationSeconds(for: phase)
        menu.addItem(reset)
        menu.addItem(.separator())

        for (index, timerPhase) in TimerPhase.allCases.enumerated() {
            let item = commandItem(
                title: "Start \(timerPhase.title) \(settings.minutes(for: timerPhase)) min",
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

        menu.addItem(commandItem(title: "History...", symbol: "list.bullet.rectangle", action: #selector(openHistory)))
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

    private var canEndPomoEarly: Bool {
        phase == .focus && (state == .running || state == .paused)
    }

    private var currentFocusIntention: String? {
        guard phase == .focus, state == .running || state == .paused else { return nil }
        let intention = normalizedText(currentFocusSession?.intention ?? "")
        return intention.isEmpty ? nil : intention
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
            button.image = progressIcon(fractionRemaining: fractionRemaining, state: state, activityFrame: activityFrame)
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
        case .running:
            if let intention = currentFocusIntention {
                return "\(phase.title): \(clockText(remainingSeconds)) remaining - \(shortTooltipTitle(intention))"
            }
            return "\(phase.title): \(clockText(remainingSeconds)) remaining"
        default:
            return "\(phase.title): \(clockText(remainingSeconds)) remaining"
        }
    }

    private func shortTooltipTitle(_ title: String) -> String {
        let compactTitle = title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard compactTitle.count > 20 else { return compactTitle }
        return "\(compactTitle.prefix(20))..."
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

    private func progressIcon(fractionRemaining: CGFloat, state: TimerState, activityFrame: Int) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)

        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let ringRect = NSRect(x: 3.2, y: 3.2, width: 15.6, height: 15.6)
        let center = NSPoint(x: ringRect.midX, y: ringRect.midY)
        let radius = ringRect.width / 2.0

        let trackAlpha: CGFloat = state == .idle ? 0.42 : 0.24
        let background = NSBezierPath(ovalIn: ringRect)
        background.lineWidth = 2.2
        NSColor.black.withAlphaComponent(trackAlpha).setStroke()
        background.stroke()

        switch state {
        case .idle:
            drawPlayGlyph(in: ringRect)
        case .running:
            drawProgressArc(fractionRemaining: fractionRemaining, center: center, radius: radius, alpha: 1.0)
            drawActivityEllipsis(in: ringRect, frame: activityFrame)
        case .paused:
            drawProgressArc(fractionRemaining: fractionRemaining, center: center, radius: radius, alpha: 0.74)
            drawPauseGlyph(in: ringRect)
        case .finished:
            drawCheckGlyph(in: ringRect)
        }

        return image
    }

    private func drawProgressArc(fractionRemaining: CGFloat, center: NSPoint, radius: CGFloat, alpha: CGFloat) {
        guard fractionRemaining > 0.0001 else { return }

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
        NSColor.black.withAlphaComponent(alpha).setStroke()
        progress.stroke()
    }

    private func drawActivityEllipsis(in ringRect: NSRect, frame: Int) {
        let dotRadius: CGFloat = 0.85
        let spacing: CGFloat = 3.2
        let startX = ringRect.midX - spacing
        let y = ringRect.midY - dotRadius

        for index in 0..<3 {
            let alpha: CGFloat = index == frame % 3 ? 0.95 : 0.28
            let x = startX + CGFloat(index) * spacing - dotRadius
            NSColor.black.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dotRadius * 2, height: dotRadius * 2)).fill()
        }
    }

    private func drawPlayGlyph(in ringRect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: ringRect.midX - 1.8, y: ringRect.midY - 3.4))
        path.line(to: NSPoint(x: ringRect.midX - 1.8, y: ringRect.midY + 3.4))
        path.line(to: NSPoint(x: ringRect.midX + 3.5, y: ringRect.midY))
        path.close()
        NSColor.black.withAlphaComponent(0.82).setFill()
        path.fill()
    }

    private func drawPauseGlyph(in ringRect: NSRect) {
        let barSize = NSSize(width: 1.8, height: 6.8)
        let gap: CGFloat = 2.0
        let leftX = ringRect.midX - gap / 2.0 - barSize.width
        let rightX = ringRect.midX + gap / 2.0
        let y = ringRect.midY - barSize.height / 2.0

        NSColor.black.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: NSRect(x: leftX, y: y, width: barSize.width, height: barSize.height), xRadius: 0.8, yRadius: 0.8).fill()
        NSBezierPath(roundedRect: NSRect(x: rightX, y: y, width: barSize.width, height: barSize.height), xRadius: 0.8, yRadius: 0.8).fill()
    }

    private func drawCheckGlyph(in ringRect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: ringRect.midX - 4.4, y: ringRect.midY - 0.2))
        path.line(to: NSPoint(x: ringRect.midX - 1.2, y: ringRect.midY - 3.3))
        path.line(to: NSPoint(x: ringRect.midX + 4.8, y: ringRect.midY + 3.4))
        path.lineWidth = 2.2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor.black.withAlphaComponent(0.95).setStroke()
        path.stroke()
    }
}
