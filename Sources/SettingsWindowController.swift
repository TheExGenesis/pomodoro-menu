import AppKit

final class SettingsWindowController: NSWindowController {
    private let settings = PomodoroSettings.shared

    private let presetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let focusField = NSTextField(frame: .zero)
    private let shortBreakField = NSTextField(frame: .zero)
    private let longBreakField = NSTextField(frame: .zero)
    private let longBreakEveryField = NSTextField(frame: .zero)
    private let focusStepper = NSStepper(frame: .zero)
    private let shortBreakStepper = NSStepper(frame: .zero)
    private let longBreakStepper = NSStepper(frame: .zero)
    private let longBreakEveryStepper = NSStepper(frame: .zero)
    private let soundEnabledButton = NSButton(checkboxWithTitle: "Ring a neutral completion sound", target: nil, action: nil)
    private let notificationEnabledButton = NSButton(checkboxWithTitle: "Send a notification when a phase ends", target: nil, action: nil)
    private let autoStartButton = NSButton(checkboxWithTitle: "Automatically start the next phase", target: nil, action: nil)
    private let showSecondsButton = NSButton(checkboxWithTitle: "Show seconds when under 1 minute", target: nil, action: nil)
    private let soundPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let testSoundButton = NSButton(title: "Test", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pomodoro Settings"
        window.center()
        super.init(window: window)
        buildContent()
        refreshControls()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .pomodoroSettingsChanged,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        refreshControls()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            root.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -22)
        ])

        root.addArrangedSubview(sectionTitle("Regime"))
        root.addArrangedSubview(regimeView())
        root.addArrangedSubview(sectionTitle("Durations"))
        root.addArrangedSubview(durationGrid())
        root.addArrangedSubview(sectionTitle("Completion"))
        root.addArrangedSubview(completionGrid())
        root.addArrangedSubview(optionsStack())
        root.addArrangedSubview(buttonRow())
    }

    private func regimeView() -> NSView {
        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
        presetPopup.addItem(withTitle: "Custom")
        for preset in PomodoroDefaults.presets {
            presetPopup.addItem(withTitle: "\(preset.name) - \(preset.detail)")
        }

        let stack = NSStackView(views: [label("Preset:"), presetPopup])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        presetPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        return stack
    }

    private func durationGrid() -> NSGridView {
        configureDuration(field: focusField, stepper: focusStepper, min: 1, max: 180, action: #selector(focusDurationChanged))
        configureDuration(field: shortBreakField, stepper: shortBreakStepper, min: 1, max: 60, action: #selector(shortBreakDurationChanged))
        configureDuration(field: longBreakField, stepper: longBreakStepper, min: 1, max: 90, action: #selector(longBreakDurationChanged))
        configureDuration(field: longBreakEveryField, stepper: longBreakEveryStepper, min: 2, max: 12, action: #selector(longBreakEveryChanged))

        let grid = NSGridView(views: [
            [label("Focus:"), numberControl(field: focusField, stepper: focusStepper), label("min")],
            [label("Short break:"), numberControl(field: shortBreakField, stepper: shortBreakStepper), label("min")],
            [label("Long break:"), numberControl(field: longBreakField, stepper: longBreakStepper), label("min")],
            [label("Long break every:"), numberControl(field: longBreakEveryField, stepper: longBreakEveryStepper), label("focus rounds")]
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        grid.columnSpacing = 10
        grid.rowSpacing = 8
        return grid
    }

    private func completionGrid() -> NSGridView {
        soundEnabledButton.target = self
        soundEnabledButton.action = #selector(soundEnabledChanged)
        notificationEnabledButton.target = self
        notificationEnabledButton.action = #selector(notificationEnabledChanged)

        soundPopup.target = self
        soundPopup.action = #selector(soundChanged)
        for sound in CompletionSound.options {
            soundPopup.addItem(withTitle: sound.label)
        }

        testSoundButton.target = self
        testSoundButton.action = #selector(testSound)

        let soundControls = NSStackView(views: [soundPopup, testSoundButton])
        soundControls.orientation = .horizontal
        soundControls.alignment = .centerY
        soundControls.spacing = 8

        let grid = NSGridView(views: [
            [soundEnabledButton],
            [soundControls],
            [notificationEnabledButton]
        ])
        grid.rowSpacing = 8
        return grid
    }

    private func optionsStack() -> NSStackView {
        autoStartButton.target = self
        autoStartButton.action = #selector(autoStartChanged)
        showSecondsButton.target = self
        showSecondsButton.action = #selector(showSecondsChanged)

        let stack = NSStackView(views: [autoStartButton, showSecondsButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func buttonRow() -> NSStackView {
        let reset = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults))
        let done = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        done.keyEquivalent = "\r"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [reset, spacer, done])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: 392).isActive = true
        return row
    }

    private func configureDuration(field: NSTextField, stepper: NSStepper, min: Double, max: Double, action: Selector) {
        field.alignment = .right
        field.formatter = integerFormatter(min: min, max: max)
        field.target = self
        field.action = action
        field.widthAnchor.constraint(equalToConstant: 52).isActive = true

        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = 1
        stepper.target = self
        stepper.action = action
    }

    private func numberControl(field: NSTextField, stepper: NSStepper) -> NSStackView {
        let stack = NSStackView(views: [field, stepper])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        return stack
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let field = label(title)
        field.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return field
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.systemFont(ofSize: 13)
        return field
    }

    private func integerFormatter(min: Double, max: Double) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: min)
        formatter.maximum = NSNumber(value: max)
        formatter.allowsFloats = false
        return formatter
    }

    @objc private func settingsChanged() {
        refreshControls()
    }

    private func refreshControls() {
        if let preset = settings.matchingPreset(),
           let index = PomodoroDefaults.presets.firstIndex(of: preset) {
            presetPopup.selectItem(at: index + 1)
        } else {
            presetPopup.selectItem(at: 0)
        }

        set(field: focusField, stepper: focusStepper, value: settings.focusMinutes)
        set(field: shortBreakField, stepper: shortBreakStepper, value: settings.shortBreakMinutes)
        set(field: longBreakField, stepper: longBreakStepper, value: settings.longBreakMinutes)
        set(field: longBreakEveryField, stepper: longBreakEveryStepper, value: settings.longBreakEvery)

        soundEnabledButton.state = settings.soundEnabled ? .on : .off
        notificationEnabledButton.state = settings.notificationEnabled ? .on : .off
        autoStartButton.state = settings.autoStartNextPhase ? .on : .off
        showSecondsButton.state = settings.showSecondsUnderMinute ? .on : .off

        if let soundIndex = CompletionSound.options.firstIndex(where: { $0.name == settings.soundName }) {
            soundPopup.selectItem(at: soundIndex)
        }

        soundPopup.isEnabled = settings.soundEnabled
        testSoundButton.isEnabled = settings.soundEnabled
    }

    private func set(field: NSTextField, stepper: NSStepper, value: Int) {
        field.integerValue = value
        stepper.integerValue = value
    }

    @objc private func presetChanged() {
        let index = presetPopup.indexOfSelectedItem - 1
        guard PomodoroDefaults.presets.indices.contains(index) else { return }
        settings.apply(PomodoroDefaults.presets[index])
    }

    @objc private func focusDurationChanged(_ sender: Any) {
        settings.focusMinutes = integerValue(from: sender, fallback: settings.focusMinutes)
    }

    @objc private func shortBreakDurationChanged(_ sender: Any) {
        settings.shortBreakMinutes = integerValue(from: sender, fallback: settings.shortBreakMinutes)
    }

    @objc private func longBreakDurationChanged(_ sender: Any) {
        settings.longBreakMinutes = integerValue(from: sender, fallback: settings.longBreakMinutes)
    }

    @objc private func longBreakEveryChanged(_ sender: Any) {
        settings.longBreakEvery = integerValue(from: sender, fallback: settings.longBreakEvery)
    }

    private func integerValue(from sender: Any, fallback: Int) -> Int {
        if let field = sender as? NSTextField {
            return field.integerValue
        }
        if let stepper = sender as? NSStepper {
            return stepper.integerValue
        }
        return fallback
    }

    @objc private func soundEnabledChanged() {
        settings.soundEnabled = soundEnabledButton.state == .on
    }

    @objc private func notificationEnabledChanged() {
        let enabled = notificationEnabledButton.state == .on
        guard enabled else {
            settings.notificationEnabled = false
            return
        }

        CompletionNotifier.shared.requestAuthorization { [weak self] allowed in
            self?.settings.notificationEnabled = allowed
            if !allowed {
                self?.showNotificationPermissionAlert()
            }
        }
    }

    @objc private func autoStartChanged() {
        settings.autoStartNextPhase = autoStartButton.state == .on
    }

    @objc private func showSecondsChanged() {
        settings.showSecondsUnderMinute = showSecondsButton.state == .on
    }

    @objc private func soundChanged() {
        let index = soundPopup.indexOfSelectedItem
        guard CompletionSound.options.indices.contains(index) else { return }
        settings.soundName = CompletionSound.options[index].name
    }

    @objc private func testSound() {
        CompletionNotifier.shared.playCompletionSound(named: settings.soundName)
    }

    @objc private func resetDefaults() {
        settings.resetToDefaults()
    }

    @objc private func closeWindow() {
        close()
    }

    private func showNotificationPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Notifications are disabled"
        alert.informativeText = "Enable notifications for Pomodoro Menu in System Settings to use completion notifications."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
