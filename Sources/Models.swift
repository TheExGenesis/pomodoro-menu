import Foundation

enum TimerPhase: String, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var symbolName: String {
        switch self {
        case .focus: return "timer"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "moon.zzz.fill"
        }
    }
}

enum TimerState {
    case idle
    case running
    case paused
    case finished
}

enum PomodoroOutcome: String, Codable, CaseIterable {
    case done
    case partial
    case missed
    case notRecorded

    var title: String {
        switch self {
        case .done: return "Yes"
        case .partial: return "Partly"
        case .missed: return "No"
        case .notRecorded: return "-"
        }
    }
}

struct PomodoroSession: Codable, Equatable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var plannedSeconds: Int
    var intention: String
    var outcome: PomodoroOutcome
    var review: String

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        plannedSeconds: Int,
        intention: String,
        outcome: PomodoroOutcome = .notRecorded,
        review: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.intention = intention
        self.outcome = outcome
        self.review = review
    }
}

struct DurationPreset: Equatable {
    let name: String
    let detail: String
    let focusMinutes: Int
    let shortBreakMinutes: Int
    let longBreakMinutes: Int
    let longBreakEvery: Int

    var menuTitle: String {
        "\(name) (\(focusMinutes)/\(shortBreakMinutes))"
    }
}

enum PomodoroDefaults {
    static let presets: [DurationPreset] = [
        DurationPreset(name: "Classic", detail: "25 min focus, 5 min break", focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 4),
        DurationPreset(name: "Balanced", detail: "35 min focus, 5 min break", focusMinutes: 35, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 4),
        DurationPreset(name: "Deep Work", detail: "50 min focus, 10 min break", focusMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 25, longBreakEvery: 3),
        DurationPreset(name: "Long Arc", detail: "75 min focus, 15 min break", focusMinutes: 75, shortBreakMinutes: 15, longBreakMinutes: 30, longBreakEvery: 2)
    ]

    static let defaultPreset = presets[0]
}

struct CompletionSound: Equatable {
    let name: String
    let label: String

    static let options: [CompletionSound] = [
        CompletionSound(name: "Glass", label: "Glass (gentle)"),
        CompletionSound(name: "Tink", label: "Tink (soft)"),
        CompletionSound(name: "Pop", label: "Pop (light)"),
        CompletionSound(name: "Ping", label: "Ping (clear)")
    ]
}

extension Notification.Name {
    static let pomodoroSettingsChanged = Notification.Name("PomodoroSettingsChanged")
    static let pomodoroHistoryChanged = Notification.Name("PomodoroHistoryChanged")
}
