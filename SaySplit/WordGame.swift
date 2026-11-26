import Foundation

// Word Games — Wordle-style logic and data.
// Test access: demo mode, no login/account needed.

enum WordDifficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var answers: [String] {
        switch self {
        case .easy: return WordLists.easyAnswers
        case .medium: return WordLists.mediumAnswers
        case .hard: return WordLists.hardAnswers
        }
    }
    var seedOffset: Int {
        switch self { case .easy: return 0; case .medium: return 101; case .hard: return 202 }
    }
}

enum LetterState: Int, Comparable {
    case unknown = 0, absent = 1, present = 2, correct = 3
    static func < (lhs: LetterState, rhs: LetterState) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum WordEvaluator {
    /// Correct duplicate-letter handling: exact matches consume letters first,
    /// then present matches consume from what remains.
    static func evaluate(guess: String, answer: String) -> [LetterState] {
        let g = Array(guess.uppercased())
        let a = Array(answer.uppercased())
        guard g.count == 5, a.count == 5 else { return [] }
        var result = [LetterState](repeating: .absent, count: 5)
        var remaining: [Character: Int] = [:]
        for i in 0..<5 {
            if g[i] == a[i] { result[i] = .correct } else { remaining[a[i], default: 0] += 1 }
        }
        for i in 0..<5 where result[i] != .correct {
            if let count = remaining[g[i]], count > 0 {
                result[i] = .present
                remaining[g[i]] = count - 1
            }
        }
        return result
    }

    static func isWin(guess: String, answer: String) -> Bool {
        guess.uppercased() == answer.uppercased()
    }
}

enum DailyWordProvider {
    static func dayNumber(for date: Date = Date()) -> Int {
        Int(date.timeIntervalSince1970 / 86400)
    }
    static func dailyWord(difficulty: WordDifficulty, date: Date = Date()) -> String {
        let list = difficulty.answers
        let idx = abs(dayNumber(for: date) * 31 + difficulty.seedOffset) % list.count
        return list[idx]
    }
}

enum WordLists {
    static let easyAnswers: [String] = [
        "APPLE","HOUSE","WATER","LIGHT","MUSIC","HAPPY","SMILE","BEACH","CHAIR","TABLE",
        "BREAD","HEART","WORLD","DREAM","GREEN","PIZZA","TIGER","LEMON","PEACH","GRAPE",
        "PLANT","RIVER","OCEAN","CLOUD","RAINY","SUNNY","PARTY","CANDY","LUCKY","SMART",
        "BOOKS","GAMES","MOVIE","DANCE","SWEET","QUICK","BRAVE","LEARN","PLAYS","CLASS"
    ]
    static let mediumAnswers: [String] = [
        "CRANE","SLATE","AUDIO","ROATE","ADIEU","STARE","TEARS","RINSE","OPERA","ARISE",
        "RAISE","IRATE","ALONE","ROUND","ABOUT","THINK","PRICE","COURT","PIVOT","VIVID",
        "BLEND","BRISK","CIDER","DWELL","EPOCH","FLINT","GUSTO","HASTE","INDEX","JOLLY",
        "KNEEL","LUNGE","MIRTH","NOBLE","ONSET","PLUMB","QUILT","RIDGE","SCOUT","TRAIL"
    ]
    static let hardAnswers: [String] = [
        "JAZZY","QUIRK","ZILCH","FUZZY","JUMBO","QUAFF","VEXED","WALTZ","XYLEM","YACHT",
        "ZESTY","FJORD","GLYPH","VYING","IVORY","JUNTA","KAPPA","LYMPH","MYRRH","NYMPH",
        "OXIDE","PIXEL","QUELL","SLYLY","TRYST","UNZIP","VODKA","WRYLY","XENON","QUEEN",
        "YIELD","ABYSS","CRYPT","GYPSY","JIFFY","QUOTA"
    ]
    static var allAnswers: [String] {
        (easyAnswers + mediumAnswers + hardAnswers).map { $0.uppercased() }
    }
    static var validGuesses: Set<String> {
        var set = Set(allAnswers)
        let extra = [
            "ABOUT","ABOVE","ACTOR","ACUTE","ADMIT","ADOPT","ADORE","ADULT","AFTER","AGAIN",
            "AGENT","AGREE","AHEAD","ALARM","ALBUM","ALERT","ALIKE","ALIVE","ALLOW","ALLY",
            "ALOUD","ALPHA","ALSO","ALTER","ALWAYS","AMBER","AMEND","AMONG","ANGEL","ANGER",
            "ANGLE","ANGRY","ANIMAL","ANKLE","ANOTHER","ANSWER","ANTIC","ANVIL","APART","APPLE",
            "APPLY","ARENA","ARGUE","ARISE","ARMOR","AROMA","ARROW","ASIDE","ASSET","AUDIO",
            "AUDIT","AVOID","AWAKE","AWARD","AWARE","AWFUL","AXIOM","AZURE","BACON","BADGE",
            "BADLY","BAGEL","BAKER","BALMY","BANAL","BANJO","BARGE","BARON","BASAL","BASIC",
            "BASIL","BASIN","BASIS","BASKET","BATCH","BATHS","BATON","BATTY","BAWDY","BAYOU"
        ]
        for w in extra { set.insert(w) }
        // Remove any non-5-letter entries from extras (defensive)
        return Set(set.filter { $0.count == 5 })
    }
    static func isValidGuess(_ word: String) -> Bool {
        validGuesses.contains(word.uppercased())
    }
}

enum WordStats {
    private static func key(_ difficulty: WordDifficulty, _ field: String) -> String {
        "wordstats.\(difficulty.rawValue).\(field)"
    }
    static func record(difficulty: WordDifficulty, won: Bool) {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: key(difficulty, "played")) + 1, forKey: key(difficulty, "played"))
        if won {
            d.set(d.integer(forKey: key(difficulty, "won")) + 1, forKey: key(difficulty, "won"))
            d.set(d.integer(forKey: key(difficulty, "streak")) + 1, forKey: key(difficulty, "streak"))
        } else {
            d.set(0, forKey: key(difficulty, "streak"))
        }
    }
    static func played(_ difficulty: WordDifficulty) -> Int { UserDefaults.standard.integer(forKey: key(difficulty, "played")) }
    static func won(_ difficulty: WordDifficulty) -> Int { UserDefaults.standard.integer(forKey: key(difficulty, "won")) }
    static func streak(_ difficulty: WordDifficulty) -> Int { UserDefaults.standard.integer(forKey: key(difficulty, "streak")) }
}
