import AudioToolbox
import Foundation
import UIKit
import UserNotifications

/// Countdown for one infusion. Tracks an end date rather than counting ticks,
/// so it stays accurate when the app is backgrounded.
@MainActor
final class SteepTimer: ObservableObject {
    enum State: Equatable {
        case idle
        case running(end: Date)
        case paused(remaining: TimeInterval)
        case finished
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var duration: TimeInterval = 0

    private var ticker: Timer?
    private let notificationID = "steep-finished"

    var isRunning: Bool { if case .running = state { true } else { false } }

    func remaining(at now: Date = .now) -> TimeInterval {
        switch state {
        case .idle: duration
        case .running(let end): max(0, end.timeIntervalSince(now))
        case .paused(let remaining): remaining
        case .finished: 0
        }
    }

    func progress(at now: Date = .now) -> Double {
        guard duration > 0 else { return 0 }
        return 1 - remaining(at: now) / duration
    }

    func prepare(seconds: Int) {
        stopTicker()
        cancelNotification()
        duration = TimeInterval(seconds)
        state = .idle
        setScreenAwake(false)
    }

    func start(teaName: String, label: String) {
        let remaining: TimeInterval
        switch state {
        case .idle, .finished: remaining = duration
        case .paused(let r): remaining = r
        case .running: return
        }
        guard remaining > 0 else { return }
        state = .running(end: .now.addingTimeInterval(remaining))
        scheduleNotification(after: remaining, teaName: teaName, label: label)
        startTicker()
        setScreenAwake(true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func pause() {
        guard case .running(let end) = state else { return }
        state = .paused(remaining: max(0, end.timeIntervalSinceNow))
        stopTicker()
        cancelNotification()
        setScreenAwake(false)
    }

    private func finish() {
        guard case .running(let end) = state else { return }
        state = .finished
        stopTicker()
        setScreenAwake(false)
        // Only chime if we're on time; if the app was in the background the
        // notification already did the job.
        if Date.now.timeIntervalSince(end) < 2 {
            AudioServicesPlayAlertSound(SystemSoundID(1005))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, case .running(let end) = self.state else { return }
                if Date.now >= end { self.finish() }
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func setScreenAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }

    // MARK: Notifications

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(after seconds: TimeInterval, teaName: String, label: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(teaName) is ready"
        content.body = "\(label) done. Pour it out now."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
