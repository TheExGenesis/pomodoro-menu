import Foundation

final class PomodoroHistoryStore {
    static let shared = PomodoroHistoryStore()

    private let fileManager: FileManager
    private let fileURL: URL

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = (applicationSupport ?? fileManager.homeDirectoryForCurrentUser)
            .appendingPathComponent("Pomodoro Menu", isDirectory: true)
        self.fileURL = directory.appendingPathComponent("sessions.json")
    }

    func sessions() -> [PomodoroSession] {
        loadSessions().sorted { lhs, rhs in
            lhs.startedAt > rhs.startedAt
        }
    }

    func add(_ session: PomodoroSession) {
        var sessions = loadSessions()
        sessions.append(session)
        save(sessions)
    }

    func update(_ session: PomodoroSession) {
        var sessions = loadSessions()
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            add(session)
            return
        }

        sessions[index] = session
        save(sessions)
    }

    private func loadSessions() -> [PomodoroSession] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PomodoroSession].self, from: data)
        } catch {
            NSLog("Pomodoro Menu could not load history: \(error.localizedDescription)")
            return []
        }
    }

    private func save(_ sessions: [PomodoroSession]) {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
            NotificationCenter.default.post(name: .pomodoroHistoryChanged, object: self)
        } catch {
            NSLog("Pomodoro Menu could not save history: \(error.localizedDescription)")
        }
    }
}
