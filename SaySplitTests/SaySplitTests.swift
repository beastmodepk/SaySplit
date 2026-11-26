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

    // MARK: - Connections

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
}
