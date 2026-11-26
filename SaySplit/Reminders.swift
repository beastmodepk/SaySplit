import Foundation
import UserNotifications

// MARK: - Reminder items

/// The four remindable things: Word Trio Easy / Medium / Hard, and Group Four.
enum ReminderItem: String, CaseIterable, Identifiable {
    case easy, medium, hard, groupFour
    var id: String { rawValue }

    var toggleLabel: String {
        switch self {
        case .easy: return "Word Trio — Easy"
        case .medium: return "Word Trio — Medium"
        case .hard: return "Word Trio — Hard"
        case .groupFour: return "Group Four"
        }
    }

    var body: String {
        switch self {
        case .easy: return "Your Easy word is waiting 🟩 — today's Word Trio Easy is still unfinished."
        case .medium: return "Your Medium word is waiting 🟨 — today's Word Trio Medium is still unfinished."
        case .hard: return "Your Hard word is waiting 🟥 — today's Word Trio Hard is still unfinished."
        case .groupFour: return "Today's Group Four is still unfinished — sixteen words, four groups of four. 🧩"
        }
    }

    var difficulty: WordDifficulty? {
        switch self {
        case .easy: return .easy
        case .medium: return .medium
        case .hard: return .hard
        case .groupFour: return nil
        }
    }

    init?(difficulty: WordDifficulty) {
        switch difficulty {
        case .easy: self = .easy
        case .medium: self = .medium
        case .hard: self = .hard
        }
    }
}

// MARK: - Settings (opt-in, ALL OFF by default)

/// One UserDefaults bool per item: "reminders.enabled.<item>".
/// A missing key reads as false, so on a fresh install every reminder is
/// OFF, nothing is scheduled, and no permission is ever requested until
/// the user deliberately turns a toggle on.
enum ReminderSettings {
    private static func key(_ item: ReminderItem) -> String {
        "reminders.enabled.\(item.rawValue)"
    }

    static func isEnabled(_ item: ReminderItem) -> Bool {
        UserDefaults.standard.bool(forKey: key(item))
    }

    static func setEnabled(_ item: ReminderItem, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: key(item))
    }

    static var enabledItems: Set<ReminderItem> {
        Set(ReminderItem.allCases.filter { isEnabled($0) })
    }

    static var anyEnabled: Bool { !enabledItems.isEmpty }
}

// MARK: - Completion (reads the EXISTING per-date progress stores)

/// Finished = the same state the games themselves restore from:
/// Word Trio — a winning guess in the saved guesses, or all 6 guesses used.
/// Group Four — the saved progress is marked finished. No keys are changed.
enum ReminderCompletion {
    static func isFinished(_ item: ReminderItem, on date: Date) -> Bool {
        if let difficulty = item.difficulty {
            let guesses = WordleProgress.load(date: date, difficulty: difficulty)
            if guesses.count >= 6 { return true }
            let answer = DailyWordProvider.dailyWord(difficulty: difficulty, date: date)
            return guesses.contains { WordEvaluator.isWin(guess: $0, answer: answer) }
        }
        let puzzle = ConnectionsPuzzles.daily(date: date)
        return ConnectionsProgress.load(date: date, puzzle: puzzle)?.finished ?? false
    }

    static func finishedItems(on date: Date) -> Set<ReminderItem> {
        Set(ReminderItem.allCases.filter { isFinished($0, on: date) })
    }
}

// MARK: - Planner (pure, unit-tested)

struct PlannedReminder: Equatable {
    let item: ReminderItem
    let fireDate: Date
}

/// Decides what SHOULD be scheduled: enabled AND unfinished items only,
/// 3 times a day (9:00 AM, 1:00 PM, 7:00 PM local), over a rolling
/// 7-day window, skipping times already past.
enum ReminderPlanner {
    static let hours = [9, 13, 19]
    static let daysAhead = 7

    static func itemsToRemind(enabled: Set<ReminderItem>, finished: Set<ReminderItem>) -> [ReminderItem] {
        ReminderItem.allCases.filter { enabled.contains($0) && !finished.contains($0) }
    }

    static func plan(now: Date,
                     calendar: Calendar = .current,
                     enabled: Set<ReminderItem>,
                     isFinished: (ReminderItem, Date) -> Bool) -> [PlannedReminder] {
        guard !enabled.isEmpty else { return [] }
        var planned: [PlannedReminder] = []
        let start = calendar.startOfDay(for: now)
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let finished = Set(ReminderItem.allCases.filter { isFinished($0, day) })
            for item in itemsToRemind(enabled: enabled, finished: finished) {
                for hour in hours {
                    var comps = calendar.dateComponents([.year, .month, .day], from: day)
                    comps.hour = hour
                    comps.minute = 0
                    guard let fire = calendar.date(from: comps), fire > now else { continue }
                    planned.append(PlannedReminder(item: item, fireDate: fire))
                }
            }
        }
        return planned
    }

    static func identifier(item: ReminderItem, fireDate: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: fireDate)
        return "reminder.\(item.rawValue).\(GameCalendar.key(for: fireDate)).\(hour)"
    }
}

// MARK: - Scheduler (UNUserNotificationCenter)

/// Re-syncs the pending notifications with the planner: clears our old
/// ones, then — only if at least one toggle is on AND the user has
/// authorized notifications — schedules the rolling 7-day plan.
/// Permission is requested ONLY from the settings toggle flow, never here.
enum ReminderScheduler {
    static let identifierPrefix = "reminder."

    static func sync() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            guard ReminderSettings.anyEnabled else { return }
            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized
                        || settings.authorizationStatus == .provisional else { return }
                let planned = ReminderPlanner.plan(
                    now: Date(),
                    enabled: ReminderSettings.enabledItems,
                    isFinished: ReminderCompletion.isFinished)
                for item in planned {
                    let content = UNMutableNotificationContent()
                    content.title = "Word Games"
                    content.body = item.item.body
                    content.sound = .default
                    let comps = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: item.fireDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: ReminderPlanner.identifier(item: item.item, fireDate: item.fireDate),
                        content: content, trigger: trigger)
                    center.add(request)
                }
            }
        }
    }

    /// Immediately cancels today's remaining reminders for one item —
    /// called the moment that item is finished.
    static func cancelRemainingToday(for item: ReminderItem) {
        let prefix = "reminder.\(item.rawValue).\(GameCalendar.key(for: Date()))."
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Asks for authorization (only ever called when the user turns a
    /// toggle ON), then syncs whatever the user decided.
    static func requestPermissionThenSync() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { sync() }
        }
    }
}
