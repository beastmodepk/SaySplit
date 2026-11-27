import Foundation

// Word Games — Word Trio logic and data.
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


/// Shared date handling for the top date pager: puzzles are seeded by the
/// selected date, progress is keyed by it, and navigation never goes future.
enum GameCalendar {
    static var today: Date { Calendar.current.startOfDay(for: Date()) }
    static func startOfDay(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }
    static func adding(days: Int, to date: Date) -> Date {
        let d = Calendar.current.date(byAdding: .day, value: days, to: startOfDay(date)) ?? date
        return min(startOfDay(d), today)
    }
    static func isToday(_ date: Date) -> Bool { startOfDay(date) == today }
    static func canGoForward(from date: Date) -> Bool { startOfDay(date) < today }
    /// Stable per-date storage key, e.g. "2026-11-26".
    static func key(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    /// Header label, e.g. "Thursday, November 26, 2026".
    static func display(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: date)
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
    // Answer banks, curated by real word frequency (wordfreq Zipf scale):
    // Easy = most frequent everyday words, Medium = common but trickier,
    // Hard = uncommon words with rare or double letters (existing
    // favourites kept first in each bank; proper nouns, brands and
    // adult words are blocklisted out). Stored as space-joined strings,
    // split once — no giant array literals for the type-checker.
    // INVARIANT: every literal below ends with a trailing space (except
    // each bank's last one) — Swift's + inserts nothing between literals,
    // and a missing space merges two answers into one 10-letter token
    // (the Build 111 dictionary bug). validate_structure.py audits this.
    private static let easyAnswersRaw: String =
                "APPLE HOUSE WATER LIGHT MUSIC HAPPY SMILE BEACH CHAIR TABLE BREAD HEART WORLD DREAM GREEN PIZZA TIGER LEMON PEACH GRAPE " +
        "PLANT RIVER OCEAN CLOUD RAINY SUNNY PARTY CANDY LUCKY SMART BOOKS GAMES MOVIE DANCE SWEET QUICK BRAVE LEARN PLAYS CLASS " +
        "ABOUT THEIR THERE WHICH WOULD OTHER AFTER FIRST THINK COULD THESE WHERE RIGHT BEING GOING STILL NEVER THOSE GREAT WHILE " +
        "EVERY STATE THREE SINCE UNDER THING PLACE AGAIN FOUND MIGHT MONEY NIGHT UNTIL DOING GROUP WOMEN START TODAY POINT POWER " +
        "BASED SMALL WHITE LATER ORDER THANK USING BLACK WHOLE MAYBE STORY LEAST EARLY LOCAL VIDEO YOUNG COURT GIVEN LEVEL OFTEN " +
        "DEATH SOUTH KNOWN LARGE WRONG ALONG CLOSE CAUSE HUMAN WOMAN LEAVE NORTH WATCH SHORT TAKEN THIRD AMONG CHECK ASKED CHILD " +
        "MEDIA PHONE FINAL FRONT READY BRING HEARD MARCH STUDY CLEAR MONTH BOARD FIELD FIGHT FORCE ISSUE PRICE SPACE TOTAL ABOVE " +
        "SHARE SENSE BREAK EVENT SORRY ADDED ALONE TRIED WORTH SOUND VALUE ROUND STAND STUFF DRIVE MATCH MODEL TRUST RANGE TRADE " +
        "CHIEF LOWER STYLE BLOOD STAGE TITLE COVER LEGAL SEVEN STAFF SUPER UNION BEGAN BUILT DAILY PAPER VOICE WHOSE EARTH BELOW " +
        "OFFER SLEEP TRUTH BUILD PIECE VISIT WANNA WROTE SHALL SPEAK WRITE ALBUM EIGHT FUNNY PEACE SPENT STORE TRACK AHEAD ALLOW " +
        "BROWN MOVED RADIO LOVED SPEED AGREE CLEAN PHOTO SCENE SPEND COACH HEAVY TRAIN CLAIM GOTTA HOTEL NAMED BRAIN FLOOR IMAGE " +
        "MEANT REACH CIVIL STOCK TRUMP WORST ENDED OLDER COLOR GRAND TOUCH DOUBT DRINK SHOWN BASIC CARRY CRIME FULLY WORSE AWARD " +
        "BLOCK LIVED AVOID CATCH COAST TRIAL TRULY BROKE PRIOR ROYAL SERVE BEGIN TWICE WORRY BRAND COUNT FRESH MOUTH OWNER SCALE " +
        "SCORE THROW CLICK FAITH METAL AGENT APPLY ENTER PRIME WASTE WEIRD ADULT GRADE STONE APART AWARE FIFTH PROUD BIRTH LABOR " +
        "PROVE TOUGH ALIVE HORSE LIKED MAGIC OWNED STICK GUIDE RAISE TREAT YOUTH GUARD SHOOT SOLID SPORT TASTE HELLO PLANE SHAPE"
    static let easyAnswers: [String] = easyAnswersRaw.split(separator: " ").map { String($0) }
    private static let mediumAnswersRaw: String =
                "CRANE SLATE AUDIO ROATE ADIEU STARE TEARS RINSE OPERA ARISE IRATE PIVOT VIVID BLEND BRISK CIDER DWELL EPOCH FLINT GUSTO " +
        "HASTE INDEX JOLLY KNEEL LUNGE MIRTH NOBLE ONSET PLUMB QUILT RIDGE SCOUT TRAIL ALIEN BEAST CITED DATED FIFTY RELAX ACTED " +
        "ALARM GLOBE HOPED SPARE QUEST SIZED ANIME LOVER PANIC SCOPE AIMED ALPHA BRICK MERCY OUTER SCREW VENUE HABIT NAVAL ROBOT " +
        "TOXIC WIDER WOUND ASSET BAKER BRUSH ESSAY MAKER SNAKE ULTRA USAGE CANAL CLIMB FEVER FLUID NASTY TWIST UNITY BLOWN FENCE " +
        "STOLE BORED DEALT FLESH FORTY HATED LASER LOYAL PATCH RADAR VILLA ADOPT BLADE CARGO CRIED HUMOR NERVE SANDY SHEEP TRACE " +
        "CHILL GRAIN LIVER METRO RIFLE RIVAL SADLY SLEPT SPRAY SUITE VERSE CHUCK COUCH CRUSH GENRE LEASE SHINE TWEET TYLER INTER " +
        "REACT ROCKY SHADE TOMMY VOCAL YIELD BACON BURST SALAD STAKE SWIFT WELSH AWAKE BLANK CURVE HARSH HURRY MASON NANCY ORGAN " +
        "PEARL SWEAT ALIKE ARROW CABIN EAGLE EATEN GUILT HAVEN THEFT VALVE CHARM CRUEL DELTA JULIA TRIBE CANON CARED STAMP VOTER " +
        "WITCH ARRAY BELLY BOOTH CLIFF DERBY FATAL RALPH SHARK COLIN DAIRY DIARY DRILL METER OLIVE SAFER SETUP SKULL SMASH BASIN " +
        "BREED BRIDE CHICK FAIRY FREAK GRIEF LINED LODGE MERIT MICRO RAPED REBEL TOOTH VIRAL WIDOW BEARD CURSE DRAIN FLAME INTEL " +
        "NINTH PENNY PETTY REIGN SCARE CHEAT CHEER DEMON ELDER FIBER FRIED PULSE REALM SHOUT ALTER GRAPH SHOOK STACK AGING AUDIT " +
        "DRIED JESSE LOGAN SPITE BURNT BUYER CEASE CLOTH EAGER ELECT LOBBY ORBIT RANCH TRUNK BADGE CAROL DIANA FERRY GAUGE RIDER " +
        "SHELF WIDTH LEGIT LOSER SHEER STARK THUMB URGED WHEAT WRIST ACUTE CIVIC CLERK CRUDE DRONE FLOUR PAUSE PUPPY SLICE VINYL " +
        "PROBE REMIX SNEAK SPARK STEEP STRAW WEIGH ADAPT COHEN CYBER DENSE KITTY WHALE AMBER ANKLE ARMOR BERRY CLASH GRASP HANDY " +
        "MANGA POKER SALLY STEAK SWEEP TUMOR CHEEK CURRY DRAKE POLAR SKIRT SPIKE TOAST WAIST WRECK BRAKE COUGH DEPOT DRANK FEAST"
    static let mediumAnswers: [String] = mediumAnswersRaw.split(separator: " ").map { String($0) }
    private static let hardAnswersRaw: String =
                "JAZZY QUIRK ZILCH FUZZY JUMBO QUAFF VEXED WALTZ XYLEM YACHT ZESTY FJORD GLYPH VYING IVORY JUNTA KAPPA LYMPH MYRRH NYMPH " +
        "OXIDE PIXEL QUELL SLYLY TRYST UNZIP VODKA WRYLY XENON QUEEN ABYSS CRYPT GYPSY JIFFY QUOTA ARBOR FELLA ICING MIMIC NASAL " +
        "QUASI DETER SQUAT FANNY RODEO TABOO ANNOY QUAKE RACER STOUT MANIA PARRY SNIFF SQUID TERRA ABBOT DIZZY TUMMY BROOM EATER " +
        "FROZE HITCH NYLON OZONE ROTOR CROOK GENIE HUBBY LEDGE MOMMA NATAL TORSO BASAL ETHER GORGE LATEX MODEM PAPAL SNOOP ZEBRA " +
        "COCKY EVADE MAXIM DITTO OTTER REUSE AVANT EXERT AZURE CRAZE GEESE BOXED FOLLY LIBEL MAIZE SHEEN SLEEK DOGGY EERIE GEMMA " +
        "BUGGY DODGY MAMMA GLOOM BEIGE BUBBA EMERY OLLIE PIGGY TOXIN ASSAM CELLO LIPID UNDUE VERDE ASSAY GLAZE JOKED BANJO BEECH " +
        "COMMA EVOKE LOWLY PETIT POLIO EXPEL HELIX KNACK MAGNA MISSY POTTY BROOD DANDY DONNY EASED SAUNA SUEDE TIMID TWEED UNCUT " +
        "KAYAK VIGIL ANNUM AROMA LOTTO PROTO SISSY GIDDY KIDDO MELEE SERGE TEMPT WHIFF CHICO IONIC LORRY MATTY SASSY TONNE DEFER " +
        "FLUFF LOTTA MAHAL REPEL SWOOP TELLY WHOOP AMAZE DERRY DRIER FEMME FOGGY MAGMA NUTTY PLUMP BRITT CODEX PLAYA POSSE SAMBA " +
        "HILLY LEECH SALLE SEINE BAGGY GABBY NELLY STRUT THETA ZONED AXIAL CARAT FILLY FOOTY HALAL MASSE PIXIE SEVER SNUFF AVIAN"
    static let hardAnswers: [String] = hardAnswersRaw.split(separator: " ").map { String($0) }
    static var allAnswers: [String] {
        (easyAnswers + mediumAnswers + hardAnswers).map { $0.uppercased() }
    }
    static var validGuesses: Set<String> {
        // The full guess dictionary (WordDictionary.swift) already
        // includes every answer-bank word, so an answer is always legal.
        WordDictionary.guessSet
    }
    static func isValidGuess(_ word: String) -> Bool {
        validGuesses.contains(word.uppercased())
    }
}

enum WordStats {
    private static func key(_ difficulty: WordDifficulty, _ field: String) -> String {
        "acct.\(AuthManager.currentStorageKey).wordstats.\(difficulty.rawValue).\(field)"
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
