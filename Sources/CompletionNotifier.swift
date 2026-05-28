import AppKit
import UserNotifications

final class CompletionNotifier {
    static let shared = CompletionNotifier()

    private init() {}

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { allowed, _ in
            DispatchQueue.main.async {
                completion?(allowed)
            }
        }
    }

    func notifyCompletion(of phase: TimerPhase, nextPhase: TimerPhase?) {
        let content = UNMutableNotificationContent()
        content.title = "\(phase.title) complete"
        if let nextPhase {
            content.body = "Ready for \(nextPhase.title.lowercased())."
        } else {
            content.body = "Nice work."
        }
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "pomodoro-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func playCompletionSound(named soundName: String) {
        if let sound = NSSound(named: soundName) {
            sound.play()
        } else if let fallback = NSSound(named: "Glass") {
            fallback.play()
        } else {
            NSSound.beep()
        }
    }
}
