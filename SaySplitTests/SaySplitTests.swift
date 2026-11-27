import XCTest
@testable import SaySplit

final class SaySplitTests: XCTestCase {

    // MARK: - Word evaluation

    func testExactMatchAllCorrect() {
        let result = WordEvaluator.evaluate(guess: "CRANE", answer: "CRANE")
        XCTAssertEqual(result, [.correct, .correct, .correct, .correct, .correct])
    }

    func testAbsentLetters() {
        let result = WordEvaluator.evaluate(guess: "CRANE", answer: "MUSIC")
        XCTAssertEqual(result[2], .absent)
        XCTAssertEqual(result[3], .absent)
    }

    func testPresentLetter() {
        let result = WordEvaluator.evaluate(guess: "AUDIO", answer: "CRANE")
        XCTAssertEqual(result[0], .present)
    }

    func testDuplicateHandlingSpeedVsErase() {
        let result = WordEvaluator.evaluate(guess: "SPEED", answer: "ERASE")
        XCTAssertEqual(result, [.present, .absent, .present, .present, .absent])
    }

    func testDuplicateDoesNotOvercount() {
        let result = WordEvaluator.evaluate(guess: "EERIE", answer: "SPEED")
        let presentOrCorrect = result.filter { $0 == .present || $0 == .correct }.count
        XCTAssertEqual(presentOrCorrect, 2)
        XCTAssertEqual(result[3], .absent)
    }

    func testDailyWordsDeterministicAndValid() {
        for difficulty in WordDifficulty.allCases {
            let a = DailyWordProvider.dailyWord(difficulty: difficulty)
            let b = DailyWordProvider.dailyWord(difficulty: difficulty)
            XCTAssertEqual(a, b)
            XCTAssertEqual(a.count, 5, "\(difficulty) word \(a) must be 5 letters")
            XCTAssertTrue(WordLists.isValidGuess(a), "\(a) should be a valid guess")
            XCTAssertGreaterThanOrEqual(difficulty.answers.count, 30)
            for w in difficulty.answers { XCTAssertEqual(w.count, 5, "\(w) must be 5 letters") }
        }
    }

    // MARK: - Enriched word lists

    func testEarthIsAValidGuess() {
        // Regression: Build 91 rejected EARTH with "Not in word list".
        XCTAssertTrue(WordLists.isValidGuess("EARTH"))
        XCTAssertTrue(WordLists.isValidGuess("earth"))
    }

    func testCommonWordsAlwaysValid() {
        // Must-pass common words (EARTH and TREAD were both rejected by
        // Build 91's tiny hand-typed list). Cross-checked against the
        // google-10000-english frequency list and wordfreq's top 10,000:
        // every ordinary 5-letter English word in them validates; the
        // only non-validating entries in those lists are proper nouns,
        // brands and apostrophe-less contractions, which stay out.
        let mustPass = ["EARTH", "TREAD", "AUDIO", "HEART", "WORLD", "PLANT", "BRAVE",
                        "WATER", "HOUSE", "LIGHT", "SOUND", "POINT", "THING", "STORY",
                        "LEARN", "WRITE", "SPEAK", "WATCH", "YOUNG", "CLEAN", "DIRTY",
                        "HAPPY", "QUICK", "MOIST", "CRANE", "SLATE", "ADIEU"]
        for w in mustPass {
            XCTAssertTrue(WordLists.isValidGuess(w), "\(w) must be a valid guess")
        }
    }

    func testDictionarySampleWordsValidate() {
        for w in ["AUDIO", "CRANE", "SLATE", "HEART", "WORLD", "PLANT", "BRAVE", "MOIST", "FJORD", "JAZZY", "TRAIL", "STARE"] {
            XCTAssertTrue(WordLists.isValidGuess(w), "\(w) should validate")
        }
        XCTAssertFalse(WordLists.isValidGuess("XXXXX"))
        XCTAssertFalse(WordLists.isValidGuess("ZZZZZ"))
        XCTAssertGreaterThanOrEqual(WordDictionary.count, 8000)
    }

    func testDictionaryExactTokenIntegrity() {
        // Build 111 bug: the dictionary's space-joined raw string is built
        // from many string literals joined by +. Swift inserts NOTHING
        // between literals, so any literal missing its trailing space
        // merged two words into a bogus 10-letter token (HEART + HEAST
        // became HEARTHEAST) and both real words vanished from the Set —
        // while substring checks still "found" them. Exact token
        // invariants catch any recurrence: one merge drops the count by
        // one AND creates a non-5-letter token.
        XCTAssertEqual(WordDictionary.count, 21664)
        XCTAssertTrue(WordDictionary.guessSet.allSatisfy { $0.count == 5 },
                      "every dictionary token must be exactly 5 letters")
        let aToZ = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        XCTAssertTrue(WordDictionary.guessSet.allSatisfy { word in word.allSatisfy { aToZ.contains($0) } },
                      "every dictionary token must be uppercase A-Z")
    }

    func testDictionaryBoundaryWordsSurvive() {
        // Words that sat at string-literal boundaries in Build 111 and
        // were destroyed by the merge bug, plus their merge partners.
        for w in ["HEART", "HEAST", "CLEAN", "CRANE", "ABATE", "ABAUE"] {
            XCTAssertTrue(WordLists.isValidGuess(w), "\(w) must be a valid guess (boundary regression)")
        }
        XCTAssertFalse(WordLists.isValidGuess("HEARTHEAST"))
        // Answer-bank boundary pairs from the same bug.
        XCTAssertTrue(WordLists.easyAnswers.contains("GRAPE"))
        XCTAssertTrue(WordLists.easyAnswers.contains("PLANT"))
        XCTAssertTrue(WordLists.mediumAnswers.contains("GUSTO"))
        XCTAssertTrue(WordLists.mediumAnswers.contains("HASTE"))
        XCTAssertTrue(WordLists.hardAnswers.contains("NYMPH"))
        XCTAssertTrue(WordLists.hardAnswers.contains("OXIDE"))
    }

    func testAnswerBanksEnrichedAndWellFormed() {
        XCTAssertEqual(WordLists.easyAnswers.count, 300)
        XCTAssertEqual(WordLists.mediumAnswers.count, 300)
        XCTAssertEqual(WordLists.hardAnswers.count, 200)
        for list in [WordLists.easyAnswers, WordLists.mediumAnswers, WordLists.hardAnswers] {
            XCTAssertEqual(list.count, Set(list).count, "answers must be unique within a bank")
            for w in list {
                XCTAssertEqual(w.count, 5, "\(w) must be 5 letters")
                XCTAssertTrue(WordLists.isValidGuess(w), "answer \(w) must be a valid guess")
            }
        }
        XCTAssertTrue(Set(WordLists.easyAnswers).isDisjoint(with: Set(WordLists.mediumAnswers)))
        XCTAssertTrue(Set(WordLists.easyAnswers).isDisjoint(with: Set(WordLists.hardAnswers)))
        XCTAssertTrue(Set(WordLists.mediumAnswers).isDisjoint(with: Set(WordLists.hardAnswers)))
    }

    func testDailyWordDeterminismWithNewBanks() {
        let today = GameCalendar.today
        let yesterday = GameCalendar.adding(days: -1, to: today)
        for difficulty in WordDifficulty.allCases {
            XCTAssertEqual(DailyWordProvider.dailyWord(difficulty: difficulty, date: yesterday),
                           DailyWordProvider.dailyWord(difficulty: difficulty, date: yesterday))
            XCTAssertTrue(difficulty.answers.contains(DailyWordProvider.dailyWord(difficulty: difficulty, date: today)),
                          "daily word must come from the \(difficulty) bank")
        }
    }

    // MARK: - Group Four

    func testConnectionsPuzzlesWellFormed() {
        XCTAssertGreaterThanOrEqual(ConnectionsPuzzles.all.count, 14)
        for puzzle in ConnectionsPuzzles.all {
            XCTAssertEqual(puzzle.groups.count, 4)
            XCTAssertEqual(puzzle.allWords.count, 16)
            XCTAssertEqual(Set(puzzle.allWords).count, 16, "words must be unique per puzzle")
            for group in puzzle.groups { XCTAssertEqual(group.words.count, 4) }
        }
    }

    func testConnectionsMatchingGroup() {
        let puzzle = ConnectionsPuzzles.all[0]
        let group = puzzle.groups[0]
        XCTAssertEqual(ConnectionsLogic.matchingGroup(selected: Set(group.words), in: puzzle), group)
    }

    func testConnectionsOneAway() {
        let puzzle = ConnectionsPuzzles.all[0]
        var selected = Set(puzzle.groups[0].words.prefix(3))
        selected.insert(puzzle.groups[1].words[0])
        XCTAssertTrue(ConnectionsLogic.isOneAway(selected: selected, in: puzzle))
        XCTAssertNil(ConnectionsLogic.matchingGroup(selected: selected, in: puzzle))
    }

    func testConnectionsSolved() {
        let puzzle = ConnectionsPuzzles.all[0]
        XCTAssertTrue(ConnectionsLogic.isSolved(puzzle: puzzle, solved: puzzle.groups))
        XCTAssertFalse(ConnectionsLogic.isSolved(puzzle: puzzle, solved: []))
    }

    func testConnectionsDailyDeterministic() {
        XCTAssertEqual(ConnectionsPuzzles.daily(), ConnectionsPuzzles.daily())
    }

    // MARK: - Date navigation

    func testGameCalendarKeyAndDisplay() {
        var comps = DateComponents(); comps.year = 2026; comps.month = 11; comps.day = 26
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(GameCalendar.key(for: date), "2026-11-26")
        XCTAssertEqual(GameCalendar.display(for: date), "Thursday, November 26, 2026")
    }

    func testGameCalendarNeverGoesFuture() {
        XCTAssertFalse(GameCalendar.canGoForward(from: GameCalendar.today))
        let yesterday = GameCalendar.adding(days: -1, to: GameCalendar.today)
        XCTAssertTrue(GameCalendar.canGoForward(from: yesterday))
        XCTAssertEqual(GameCalendar.adding(days: 1, to: yesterday), GameCalendar.today)
        XCTAssertEqual(GameCalendar.adding(days: 1, to: GameCalendar.today), GameCalendar.today)
        XCTAssertTrue(GameCalendar.isToday(GameCalendar.today))
        XCTAssertFalse(GameCalendar.isToday(yesterday))
    }

    func testDailyPuzzlesAreForSelectedDate() {
        let today = GameCalendar.today
        let yesterday = GameCalendar.adding(days: -1, to: today)
        for difficulty in WordDifficulty.allCases {
            XCTAssertEqual(DailyWordProvider.dailyWord(difficulty: difficulty, date: yesterday),
                           DailyWordProvider.dailyWord(difficulty: difficulty, date: yesterday))
            XCTAssertEqual(DailyWordProvider.dailyWord(difficulty: difficulty, date: yesterday).count, 5)
        }
        XCTAssertEqual(ConnectionsPuzzles.daily(date: yesterday), ConnectionsPuzzles.daily(date: yesterday))
        XCTAssertEqual(ConnectionsPuzzles.daily(date: yesterday).allWords.count, 16)
    }

    func testPerDateProgressRoundTrip() {
        let date = GameCalendar.adding(days: -2, to: GameCalendar.today)
        WordleProgress.save(guesses: ["CRANE", "SLATE"], date: date, difficulty: .medium)
        XCTAssertEqual(WordleProgress.load(date: date, difficulty: .medium), ["CRANE", "SLATE"])
        XCTAssertEqual(WordleProgress.load(date: date, difficulty: .easy), [])
        let puzzle = ConnectionsPuzzles.daily(date: date)
        ConnectionsProgress.save(date: date, solved: [puzzle.groups[0]], remaining: ["APPLE"],
                                 mistakes: 2, finished: false, won: false)
        let saved = ConnectionsProgress.load(date: date, puzzle: puzzle)
        XCTAssertEqual(saved?.solved, [puzzle.groups[0]])
        XCTAssertEqual(saved?.mistakes, 2)
        XCTAssertEqual(saved?.remaining, ["APPLE"])
    }

    // MARK: - Auth & history

    func testAuthProvidersConfiguration() {
        XCTAssertTrue(AuthProviders.isConfigured(.apple))
        XCTAssertFalse(AuthProviders.isConfigured(.google))
        XCTAssertFalse(AuthProviders.isConfigured(.email))
    }

    func testGuestStorageKeyAndHistoryRoundTrip() {
        XCTAssertEqual(AuthManager.currentStorageKey, "guest")
        GameHistory.record(dateKey: "2026-11-25", game: "Word Trio Easy", detail: "Won in 3", won: true)
        let entries = GameHistory.entries()
        XCTAssertTrue(entries.contains { $0.dateKey == "2026-11-25" && $0.game == "Word Trio Easy" && $0.won })
    }

    // MARK: - Reminders (one toggle per game, both OFF by default)

    private func reminderCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// Fresh-install state: no keys present = both toggles off, nothing
    /// enabled, and the planner schedules nothing.
    func testRemindersDefaultOff() {
        for game in ReminderGame.allCases {
            UserDefaults.standard.removeObject(forKey: "reminders.enabled.\(game.rawValue)")
        }
        for game in ReminderGame.allCases {
            XCTAssertFalse(ReminderSettings.isEnabled(game), "\(game) must default to OFF")
        }
        XCTAssertTrue(ReminderSettings.enabledGames.isEmpty)
        XCTAssertFalse(ReminderSettings.anyEnabled)
        let planned = ReminderPlanner.plan(
            now: Date(), enabled: ReminderSettings.enabledGames,
            wordTrioUnfinished: { _ in [.easy, .medium, .hard] },
            isGroupFourFinished: { _ in false })
        XCTAssertTrue(planned.isEmpty)
    }

    /// Word Trio with every level finished → no Word Trio reminders.
    func testPlannerWordTrioAllFinishedGetsNone() {
        let cal = reminderCalendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 8))!
        let planned = ReminderPlanner.plan(
            now: now, calendar: cal, enabled: [.wordTrio],
            wordTrioUnfinished: { _ in [] },
            isGroupFourFinished: { _ in false })
        XCTAssertTrue(planned.isEmpty)
    }

    /// Word Trio with any level unfinished + toggle on → ONE reminder per
    /// slot (3/day) naming the unfinished levels.
    func testPlannerWordTrioAnyUnfinishedGetsThreePerDay() {
        let cal = reminderCalendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 8))!
        let planned = ReminderPlanner.plan(
            now: now, calendar: cal, enabled: [.wordTrio],
            wordTrioUnfinished: { _ in [.easy, .hard] },
            isGroupFourFinished: { _ in true })
        XCTAssertEqual(planned.count, 3 * 7)
        XCTAssertTrue(planned.allSatisfy { $0.game == .wordTrio })
        XCTAssertTrue(planned.allSatisfy { $0.body.contains("Easy and Hard") })
        let hours = Set(planned.map { cal.component(.hour, from: $0.fireDate) })
        XCTAssertEqual(hours, Set([9, 13, 19]))
    }

    /// Word Trio toggle OFF → no Word Trio reminders, even when unfinished.
    func testPlannerWordTrioOffGetsNone() {
        let cal = reminderCalendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 8))!
        let planned = ReminderPlanner.plan(
            now: now, calendar: cal, enabled: [.groupFour],
            wordTrioUnfinished: { _ in [.easy, .medium, .hard] },
            isGroupFourFinished: { _ in false })
        XCTAssertFalse(planned.contains { $0.game == .wordTrio })
        XCTAssertEqual(planned.count, 3 * 7)
    }

    /// Group Four: finished → none; unfinished + on → 3 per day.
    func testPlannerGroupFourFinishedAndUnfinished() {
        let cal = reminderCalendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 8))!
        let finished = ReminderPlanner.plan(
            now: now, calendar: cal, enabled: [.groupFour],
            wordTrioUnfinished: { _ in [] },
            isGroupFourFinished: { _ in true })
        XCTAssertTrue(finished.isEmpty)
        let unfinished = ReminderPlanner.plan(
            now: now, calendar: cal, enabled: [.groupFour],
            wordTrioUnfinished: { _ in [] },
            isGroupFourFinished: { _ in false })
        XCTAssertEqual(unfinished.count, 3 * 7)
        XCTAssertTrue(unfinished.allSatisfy { $0.game == .groupFour })
    }

    /// Times already past today are skipped; later days keep all 3.
    func testPlannerSkipsPastTimesToday() {
        let cal = reminderCalendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 14))!
        let planned = ReminderPlanner.plan(
            now: now, calendar: cal, enabled: Set(ReminderGame.allCases),
            wordTrioUnfinished: { _ in [.medium] },
            isGroupFourFinished: { _ in false })
        // Per game: today only 19:00 remains (1) + six more days × 3 = 19.
        XCTAssertEqual(planned.count, 19 * 2)
        XCTAssertTrue(planned.allSatisfy { $0.fireDate > now })
    }
}
