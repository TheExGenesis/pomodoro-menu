import Foundation

final class PomodoroSettings {
    static let shared = PomodoroSettings()

    private enum Key {
        static let focusMinutes = "focusMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let longBreakEvery = "longBreakEvery"
        static let soundEnabled = "soundEnabled"
        static let notificationEnabled = "notificationEnabled"
        static let soundName = "soundName"
        static let showSecondsUnderMinute = "showSecondsUnderMinute"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let preset = PomodoroDefaults.defaultPreset
        defaults.register(defaults: [
            Key.focusMinutes: preset.focusMinutes,
            Key.shortBreakMinutes: preset.shortBreakMinutes,
            Key.longBreakMinutes: preset.longBreakMinutes,
            Key.longBreakEvery: preset.longBreakEvery,
            Key.soundEnabled: true,
            Key.notificationEnabled: false,
            Key.soundName: CompletionSound.options[0].name,
            Key.showSecondsUnderMinute: true
        ])
    }

    var focusMinutes: Int {
        get { clamped(defaults.integer(forKey: Key.focusMinutes), min: 1, max: 180) }
        set { setInteger(newValue, key: Key.focusMinutes, min: 1, max: 180) }
    }

    var shortBreakMinutes: Int {
        get { clamped(defaults.integer(forKey: Key.shortBreakMinutes), min: 1, max: 60) }
        set { setInteger(newValue, key: Key.shortBreakMinutes, min: 1, max: 60) }
    }

    var longBreakMinutes: Int {
        get { clamped(defaults.integer(forKey: Key.longBreakMinutes), min: 1, max: 90) }
        set { setInteger(newValue, key: Key.longBreakMinutes, min: 1, max: 90) }
    }

    var longBreakEvery: Int {
        get { clamped(defaults.integer(forKey: Key.longBreakEvery), min: 2, max: 12) }
        set { setInteger(newValue, key: Key.longBreakEvery, min: 2, max: 12) }
    }

    var soundEnabled: Bool {
        get { defaults.bool(forKey: Key.soundEnabled) }
        set { setBool(newValue, key: Key.soundEnabled) }
    }

    var notificationEnabled: Bool {
        get { defaults.bool(forKey: Key.notificationEnabled) }
        set { setBool(newValue, key: Key.notificationEnabled) }
    }

    var soundName: String {
        get {
            let name = defaults.string(forKey: Key.soundName) ?? CompletionSound.options[0].name
            return CompletionSound.options.contains(where: { $0.name == name }) ? name : CompletionSound.options[0].name
        }
        set {
            let acceptedName = CompletionSound.options.contains(where: { $0.name == newValue }) ? newValue : CompletionSound.options[0].name
            defaults.set(acceptedName, forKey: Key.soundName)
            notifyChanged()
        }
    }

    var showSecondsUnderMinute: Bool {
        get { defaults.bool(forKey: Key.showSecondsUnderMinute) }
        set { setBool(newValue, key: Key.showSecondsUnderMinute) }
    }

    func durationSeconds(for phase: TimerPhase) -> Int {
        minutes(for: phase) * 60
    }

    func minutes(for phase: TimerPhase) -> Int {
        switch phase {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    func apply(_ preset: DurationPreset) {
        defaults.set(preset.focusMinutes, forKey: Key.focusMinutes)
        defaults.set(preset.shortBreakMinutes, forKey: Key.shortBreakMinutes)
        defaults.set(preset.longBreakMinutes, forKey: Key.longBreakMinutes)
        defaults.set(preset.longBreakEvery, forKey: Key.longBreakEvery)
        notifyChanged()
    }

    func matchingPreset() -> DurationPreset? {
        PomodoroDefaults.presets.first {
            $0.focusMinutes == focusMinutes &&
            $0.shortBreakMinutes == shortBreakMinutes &&
            $0.longBreakMinutes == longBreakMinutes &&
            $0.longBreakEvery == longBreakEvery
        }
    }

    func resetToDefaults() {
        apply(PomodoroDefaults.defaultPreset)
        defaults.set(true, forKey: Key.soundEnabled)
        defaults.set(false, forKey: Key.notificationEnabled)
        defaults.set(CompletionSound.options[0].name, forKey: Key.soundName)
        defaults.set(true, forKey: Key.showSecondsUnderMinute)
        notifyChanged()
    }

    private func setInteger(_ value: Int, key: String, min: Int, max: Int) {
        defaults.set(clamped(value, min: min, max: max), forKey: key)
        notifyChanged()
    }

    private func setBool(_ value: Bool, key: String) {
        defaults.set(value, forKey: key)
        notifyChanged()
    }

    private func clamped(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .pomodoroSettingsChanged, object: self)
    }
}
