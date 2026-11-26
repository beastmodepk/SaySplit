import Foundation
import UserNotifications

// MARK: - Reminder games

/// The two remindable games. One simple on/off switch per game:
/// Word Trio covers all three of today's words (Easy / Medium / Hard)
/// under a single toggle; Group Four has its own.
enum ReminderGame: String, CaseIterable, Identifiable {
    case wordTrio, groupFour
    var id: String { rawValue }

    var toggleLabel: String {
        switch self {
        case .wordTrio: return "Word Trio"
        case .groupFour: return "Group Four"
        }
    }

    static func wordTrioBody(unfinished: [WordDifficulty]) -> String {
        let names = unfinished.map { $0.title }
        let list: String
        switch names.count {
        case 0: list = ""
        case 1: list = names[0]
        case 2: list = names.joined(separator: " and ")
        default: list = names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
        }
        let verb = names.count == 1 ? "is" : "are"
        return "Word Trio: \(list) \(verb) still unfinished today. 🟩"
    }

    static let groupFourBody = "Group Four is still unfinished today — sixteen words, four groups of four. 🧩"
}

// MARK: - Settings (opt-in, BOTH OFF by default)

/// One UserDefaults bool per game: "reminders.enabled.<game>".
/// A missing key reads as false, so on a fresh install both reminders
/// are OFF, nothing is scheduled, and no permission is ever requested
/// until the user deliberately turns a toggle on.
enum ReminderSettings {
    private static func key(_ game: ReminderGame) -> String {
        "reminders.enabled.\(game.rawValue)"
    }

    static func isEnabled(_ game: ReminderGame) -> Bool {
        UserDefaults.standard.bool(forKey: key(game))
    }

    static func setEnabled(_ game: ReminderGame, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: key(game))
    }

    static var enabledGames: Set<ReminderGame> {
        Set(ReminderGame.allCases.filter { isEnabled($0) })
    }

    static var anyEnabled: Bool { !enabledGames.isEmpty }
}

// MARK: - Completion (reads the EXISTING per-date progress stores)

/// Finished = the same state the games themselves restore from:
/// a Word Trio level is finished when a winning guess is saved or all
/// 6 guesses are used; Group Four when its saved progress is finished.
/// No progress keys are changed.
enum ReminderCompletion {
    static func isLevelFinished(_ difficulty: WordDifficulty, on date: Date) -> Bool {
        let guesses = WordleProgress.load(date: date, difficulty: difficulty)
        if guesses.count >= 6 { return true }
        let answer = DailyWordProvider.dailyWord(difficulty: difficulty, date: date)
        return guesses.contains { WordEvaluator.isWin(guess: $0, answer: answer) }
    }

    /// The Word Trio levels still unfinished on a date, in Easy→Hard order.
    static func unfinishedWordTrioLevels(on date: Date) -> [WordDifficulty] {
        WordDifficulty.allCases.filter { !isLevelFinished($0, on: date) }
    }

    static func isWordTrioFinished(on date: Date) -> Bool {
        unfinishedWordTrioLevels(on: date).isEmpty
    }

    static func isGroupFourFinished(on date: Date) -> Bool {
        let puzzle = ConnectionsPuzzles.daily(date: date)
        return ConnectionsProgress.load(date: date, puzzle: puzzle)?.finished ?? false
    }
}

// MARK: - Planner (pure, unit-tested)

struct PlannedReminder: Equatable {
    let game: ReminderGame
    let fireDate: Date
    let body: String
}

/// Decides what SHOULD be scheduled: for each enabled game, 3 times a
/// day (9:00 AM, 1:00 PM, 7:00 PM local) over a rolling 7-day window,
/// skipping times already past — and only while that game is unfinished
/// on that day. Word Trio gets ONE reminder per slot naming the levels
/// still unfinished that day; nothing is planned once all three are done.
enum ReminderPlanner {
    static let hours = [9, 13, 19]
    static let daysAhead = 7

    static func plan(now: Date,
                     calendar: Calendar = .current,
                     enabled: Set<ReminderGame>,
                     wordTrioUnfinished: (Date) -> [WordDifficulty],
                     isGroupFourFinished: (Date) -> Bool) -> [PlannedReminder] {
        guard !enabled.isEmpty else { return [] }
        var planned: [PlannedReminder] = []
        let start = calendar.startOfDay(for: now)
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            var bodies: [(ReminderGame, String)] = []
            if enabled.contains(.wordTrio) {
                let unfinished = wordTrioUnfinished(day)
                if !unfinished.isEmpty {
                    bodies.append((.wordTrio, ReminderGame.wordTrioBody(unfinished: unfinished)))
                }
            }
            if enabled.contains(.groupFour), !isGroupFourFinished(day) {
                bodies.append((.groupFour, ReminderGame.groupFourBody))
            }
            for (game, body) in bodies {
                for hour in hours {
                    var comps = calendar.dateComponents([.year, .month, .day], from: day)
                    comps.hour = hour
                    comps.minute = 0
                    guard let fire = calendar.date(from: comps), fire > now else { continue }
                    planned.append(PlannedReminder(game: game, fireDate: fire, body: body))
                }
            }
        }
        return planned
    }

    /// Live-data convenience used by the scheduler.
    static func plan(now: Date, enabled: Set<ReminderGame>) -> [PlannedReminder] {
        plan(now: now,
             enabled: enabled,
             wordTrioUnfinished: ReminderCompletion.unfinishedWordTrioLevels(on:),
             isGroupFourFinished: ReminderCompletion.isGroupFourFinished(on:))
    }

    static func identifier(game: ReminderGame, fireDate: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: fireDate)
        return "reminder.\(game.rawValue).\(GameCalendar.key(for: fireDate)).\(hour)"
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
                let planned = ReminderPlanner.plan(now: Date(), enabled: ReminderSettings.enabledGames)
                for reminder in planned {
                    let content = UNMutableNotificationContent()
                    content.title = "Word Games"
                    content.body = reminder.body
                    content.sound = .default
                    let comps = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: reminder.fireDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: ReminderPlanner.identifier(game: reminder.game, fireDate: reminder.fireDate),
                        content: content, trigger: trigger)
                    center.add(request)
                }
            }
        }
    }

    /// Immediately cancels today's remaining reminders for one game —
    /// called the moment that game is finished for today.
    static func cancelRemainingToday(for game: ReminderGame) {
        let prefix = "reminder.\(game.rawValue).\(GameCalendar.key(for: Date()))."
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
