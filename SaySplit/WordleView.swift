import SwiftUI

struct WordleView: View {
    @State private var difficulty: WordDifficulty = .easy
    @State private var isPractice = false
    @State private var answer: String = DailyWordProvider.dailyWord(difficulty: .easy)
    @State private var guesses: [String] = []
    @State private var current: String = ""
    @State private var message: String = ""
    @State private var finished = false
    @State private var won = false

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
                    .onChange(of: difficulty) { _, _ in startGame() }

                    Picker("Mode", selection: $isPractice) {
                        Text("Daily").tag(false)
                        Text("Practice").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isPractice) { _, _ in startGame() }

                    Text(isPractice ? "Unlimited practice" : "Today's \(difficulty.title) word")
                        .font(.subheadline).foregroundStyle(.secondary)
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

                    Button(isPractice ? "New Practice Game" : "Replay Today") { startGame() }
                        .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Wordle")
            .onAppear { startGame() }
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
            .frame(width: 52, height: 52)
            .font(.title2.bold())
            .background(color(for: state))
            .foregroundStyle(state == .unknown ? .primary : .white)
            .border(Color.secondary.opacity(0.4))
            .cornerRadius(4)
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
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 4) {
                    if row == "ZXCVBNM" {
                        Button("ENTER") { submit() }.buttonStyle(.bordered).font(.caption.bold())
                    }
                    ForEach(Array(row), id: \.self) { ch in
                        Button(String(ch)) { tap(ch) }
                            .frame(minWidth: 28, minHeight: 44)
                            .background(color(for: keyboardStates[ch] ?? .unknown).opacity(keyboardStates[ch] == nil ? 0.15 : 1))
                            .foregroundStyle(keyboardStates[ch] == nil ? .primary : .white)
                            .cornerRadius(4)
                            .font(.headline)
                    }
                    if row == "ZXCVBNM" {
                        Button("⌫") { deleteLetter() }.buttonStyle(.bordered)
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
        if WordEvaluator.isWin(guess: guess, answer: answer) {
            won = true; finished = true; WordStats.record(difficulty: difficulty, won: true)
        } else if guesses.count >= 6 {
            won = false; finished = true; WordStats.record(difficulty: difficulty, won: false)
        }
    }
    private func startGame() {
        answer = isPractice ? DailyWordProvider.practiceWord(difficulty: difficulty) : DailyWordProvider.dailyWord(difficulty: difficulty)
        guesses = []; current = ""; message = ""; finished = false; won = false
    }
}
