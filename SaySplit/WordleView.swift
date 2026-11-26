import SwiftUI

struct WordleView: View {
    let selectedDate: Date

    @State private var difficulty: WordDifficulty = .easy
    @State private var answer: String
    @State private var guesses: [String] = []
    @State private var current: String = ""
    @State private var message: String = ""
    @State private var finished = false
    @State private var won = false

    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        _answer = State(initialValue: DailyWordProvider.dailyWord(difficulty: .easy, date: selectedDate))
    }

    private let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

    private var keyboardStates: [Character: LetterState] {
        var map: [Character: LetterState] = [:]
        for guess in guesses {
            let states = WordEvaluator.evaluate(guess: guess, answer: answer)
            for (ch, st) in zip(Array(guess), states) where st > (map[ch] ?? .unknown) {
                map[ch] = st
            }
        }
        return map
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(WordDifficulty.allCases) { d in Text(d.title).tag(d) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: difficulty) { _, _ in loadGame() }

                    Text("\(difficulty.title) word for \(GameCalendar.display(for: selectedDate))")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Played \(WordStats.played(difficulty)) · Won \(WordStats.won(difficulty)) · Streak \(WordStats.streak(difficulty))")
                        .font(.caption).foregroundStyle(.secondary)

                    grid

                    if finished {
                        Text(won ? "You got it in \(guesses.count)!" : "Out of guesses — the word was \(answer)")
                            .font(.headline)
                            .foregroundStyle(won ? .green : .red)
                    }
                    if !message.isEmpty {
                        Text(message).font(.subheadline).foregroundStyle(.orange)
                    }

                    keyboard
                }
                .padding()
            }
            .navigationTitle("Word Trio")
            .onAppear { loadGame() }
        }
    }

    private var grid: some View {
        VStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
    }

    private func cell(row: Int, col: Int) -> some View {
        let letter: String
        let state: LetterState
        if row < guesses.count {
            let g = Array(guesses[row])
            letter = col < g.count ? String(g[col]) : ""
            state = WordEvaluator.evaluate(guess: guesses[row], answer: answer)[col]
        } else if row == guesses.count {
            let c = Array(current)
            letter = col < c.count ? String(c[col]) : ""
            state = .unknown
        } else {
            letter = ""
            state = .unknown
        }
        return Text(letter)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .font(.system(size: 34, weight: .bold))
            .minimumScaleFactor(0.7)
            .background(color(for: state))
            .foregroundStyle(state == .unknown ? Color.primary : Color.white)
            .border(Color.secondary.opacity(0.4))
            .cornerRadius(6)
    }

    private func color(for state: LetterState) -> Color {
        switch state {
        case .unknown: return Color.clear
        case .absent: return Color.gray
        case .present: return Color.yellow.opacity(0.85)
        case .correct: return Color.green
        }
    }

    private var keyboard: some View {
        VStack(spacing: 7) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 5) {
                    if row == "ZXCVBNM" {
                        WordleSpecialKeyView(title: "ENTER", tint: Color.green) { submit() }
                    }
                    ForEach(Array(row), id: \.self) { ch in
                        WordleKeyView(letter: ch, state: keyboardStates[ch]) { tap(ch) }
                    }
                    if row == "ZXCVBNM" {
                        WordleSpecialKeyView(title: "⌫", tint: Color.green) { deleteLetter() }
                    }
                }
            }
        }
    }

    private func tap(_ ch: Character) {
        guard !finished, current.count < 5 else { return }
        current.append(ch)
        message = ""
    }
    private func deleteLetter() {
        guard !current.isEmpty else { return }
        current.removeLast()
    }
    private func submit() {
        guard !finished else { return }
        guard current.count == 5 else { message = "Enter a 5-letter word"; return }
        guard WordLists.isValidGuess(current) else { message = "Not in word list"; return }
        let guess = current
        guesses.append(guess)
        current = ""
        WordleProgress.save(guesses: guesses, date: selectedDate, difficulty: difficulty)
        if WordEvaluator.isWin(guess: guess, answer: answer) {
            won = true; finished = true; recordResultIfNeeded(won: true)
        } else if guesses.count >= 6 {
            won = false; finished = true; recordResultIfNeeded(won: false)
        }
    }

    /// Stats are recorded once per date + difficulty, so reopening a
    /// finished past-day board never double-counts it.
    private func recordResultIfNeeded(won: Bool) {
        let key = "acct.\(AuthManager.currentStorageKey).wordle.recorded.\(GameCalendar.key(for: selectedDate)).\(difficulty.rawValue)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        WordStats.record(difficulty: difficulty, won: won)
        GameHistory.record(dateKey: GameCalendar.key(for: selectedDate),
                           game: "Word Trio \(difficulty.title)",
                           detail: won ? "Won in \(guesses.count)" : "Lost — word was \(answer)",
                           won: won)
        // When the last unfinished Word Trio level is finished, today's
        // remaining Word Trio reminders are cancelled; either way re-sync
        // so later reminders name only the levels still unfinished.
        if ReminderCompletion.unfinishedWordTrioLevels(on: selectedDate).isEmpty {
            ReminderScheduler.cancelRemainingToday(for: .wordTrio)
        }
        ReminderScheduler.sync()
    }

    /// Loads the board for the selected date + difficulty, restoring any
    /// guesses already made on that date.
    private func loadGame() {
        answer = DailyWordProvider.dailyWord(difficulty: difficulty, date: selectedDate)
        guesses = WordleProgress.load(date: selectedDate, difficulty: difficulty)
        current = ""; message = ""
        if let last = guesses.last, WordEvaluator.isWin(guess: last, answer: answer) {
            won = true; finished = true
        } else if guesses.count >= 6 {
            won = false; finished = true
        } else {
            won = false; finished = false
        }
    }
}

/// Per-date Word Trio progress, keyed "wordle.<yyyy-MM-dd>.<difficulty>".
enum WordleProgress {
    private static func key(date: Date, difficulty: WordDifficulty) -> String {
        "acct.\(AuthManager.currentStorageKey).wordle.\(GameCalendar.key(for: date)).\(difficulty.rawValue)"
    }
    static func load(date: Date, difficulty: WordDifficulty) -> [String] {
        let raw = UserDefaults.standard.string(forKey: key(date: date, difficulty: difficulty)) ?? ""
        return raw.isEmpty ? [] : raw.components(separatedBy: ",")
    }
    static func save(guesses: [String], date: Date, difficulty: WordDifficulty) {
        UserDefaults.standard.set(guesses.joined(separator: ","), forKey: key(date: date, difficulty: difficulty))
    }
}

/// One keyboard key, extracted into its own View so the compiler does not
/// have to type-check the whole keyboard expression inline (CI fix).
struct WordleKeyView: View {
    let letter: Character
    let state: LetterState?
    let action: () -> Void

    private var backgroundColor: Color {
        switch state {
        case .correct: return Color.green
        case .present: return Color.yellow.opacity(0.85)
        case .absent: return Color.gray
        case nil, .unknown: return Color.gray.opacity(0.15)
        }
    }
    private var foregroundColor: Color {
        state == nil ? Color.primary : Color.white
    }

    var body: some View {
        let label = String(letter)
        Button(action: action) {
            Text(label)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .cornerRadius(6)
                .font(.title3.bold())
        }
    }
}

/// ENTER / delete keys: same height and style as the letter keys, wider.
struct WordleSpecialKeyView: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(width: 58, height: 54)
                .background(Color.gray.opacity(0.15))
                .foregroundStyle(tint)
                .cornerRadius(6)
                .font(.subheadline.bold())
        }
    }
}
