import XCTest
@testable import SaySplit

/// SaySplit unit tests — a Swift port of the web version's
/// `tests/test_all.py` cases (same phrases, same amounts, same
/// expected results).
///
/// STATUS: tests written but NOT run. This project was authored on a
/// Linux machine with no Swift/Xcode toolchain; the first run happens
/// on Parthey's Mac (Xcode → Product → Test) or in CI once pushed.
/// The logic design was cross-checked against the passing Python
/// tests with a trace table — see validation/TRACE.md in this repo.
final class SaySplitTests: XCTestCase {

    let memberNames = ["Parthey", "Shannon", "Het", "Maya"]

    // MARK: - Parser (ports ParserTests)

    func testDinnerEightyFourWays() {
        let r = CommandParser.parseCommand(
            "Dinner, eighty dollars, split four ways",
            memberNames: memberNames, currentUser: "Parthey")
        XCTAssertEqual(r.descriptionText, "Dinner")
        XCTAssertEqual(r.amountCents, 8000)
        XCTAssertEqual(r.splitCount, 4)
        XCTAssertEqual(r.splitMemberNames, memberNames)
    }

    func testTaxiPaidBy() {
        let r = CommandParser.parseCommand(
            "Taxi $24 paid by Shannon split between Parthey and Shannon",
            memberNames: memberNames, currentUser: "Parthey")
        XCTAssertEqual(r.descriptionText, "Taxi")
        XCTAssertEqual(r.amountCents, 2400)
        XCTAssertEqual(r.payerName, "Shannon")
        XCTAssertEqual(r.splitMemberNames, ["Parthey", "Shannon"])
    }

    func testGroceriesEqually() {
        let r = CommandParser.parseCommand(
            "Groceries 120 dollars split equally",
            memberNames: memberNames, currentUser: "Parthey")
        XCTAssertEqual(r.descriptionText, "Groceries")
        XCTAssertEqual(r.amountCents, 12000)
        XCTAssertEqual(r.splitMode, "equal")
        XCTAssertEqual(r.splitMemberNames, memberNames)
    }

    func testIPaidForPizza() {
        let r = CommandParser.parseCommand(
            "I paid 60 for pizza split with Shannon",
            memberNames: memberNames, currentUser: "Parthey")
        XCTAssertEqual(r.descriptionText, "Pizza")
        XCTAssertEqual(r.amountCents, 6000)
        XCTAssertEqual(r.payerName, "Parthey")
        XCTAssertEqual(r.splitMemberNames, ["Parthey", "Shannon"])
    }

    func testNumberWords() {
        XCTAssertEqual(CommandParser.wordsToNumber(["eighty"]), 80)
        XCTAssertEqual(CommandParser.wordsToNumber(
            ["one", "hundred", "and", "twenty", "five"]), 125)
        XCTAssertEqual(CommandParser.wordsToNumber(
            ["two", "thousand", "three", "hundred"]), 2300)
    }

    // MARK: - Split math (ports SplitMathTests)

    func testEqualSplitRemainder() throws {
        let a = UUID(), b = UUID(), c = UUID()
        let s = try SplitMath.distribute(amountCents: 10000, memberIDs: [a, b, c])
        XCTAssertEqual(s.values.reduce(0, +), 10000)
        XCTAssertEqual(s, [a: 3334, b: 3333, c: 3333])
    }

    func testExactSplitOKAndBad() throws {
        let a = UUID(), b = UUID()
        let ok = try SplitMath.computeSplits(
            amountCents: 5000, mode: "exact", memberIDs: [],
            exact: [a: 3000, b: 2000])
        XCTAssertEqual(ok, [a: 3000, b: 2000])

        XCTAssertThrowsError(try SplitMath.computeSplits(
            amountCents: 5000, mode: "exact", memberIDs: [],
            exact: [a: 3000, b: 1000])) { error in
            XCTAssertTrue(error.localizedDescription.contains("must match"),
                          "Got: \(error.localizedDescription)")
        }
    }

    func testPercentSplit() throws {
        let a = UUID(), b = UUID(), c = UUID()
        let s = try SplitMath.computeSplits(
            amountCents: 9000, mode: "shares", memberIDs: [],
            shares: [a: 50, b: 25, c: 25])
        XCTAssertEqual(s, [a: 4500, b: 2250, c: 2250])
    }

    func testReceiptTaxTipReconciles() throws {
        let a = UUID(), b = UUID()
        let items = [
            ReceiptItemInput(name: "Pancakes", priceCents: 2000, assigneeIDs: [a]),
            ReceiptItemInput(name: "Coffee", priceCents: 1000, assigneeIDs: [b]),
            ReceiptItemInput(name: "Fruit bowl (shared)", priceCents: 1200, assigneeIDs: [a, b])
        ]
        let result = try ReceiptMath.splits(items: items, taxCents: 420, tipCents: 840)
        XCTAssertEqual(result.subtotal, 4200)
        XCTAssertEqual(result.total, 4200 + 420 + 840)
        XCTAssertEqual(result.perMember.values.reduce(0, +), result.total)
        XCTAssertEqual(result.perMember[a], 3380)
        XCTAssertEqual(result.perMember[b], 2080)
    }

    // MARK: - Balances (ports BalanceTests)

    func testBalancesSumZeroAndSimplify() throws {
        let asha = Member(name: "Asha")
        let ben = Member(name: "Ben")
        let cara = Member(name: "Cara")
        var group = SplitGroup(name: "Test", members: [asha, ben, cara])
        let today = Date()

        let dinnerShares = try SplitMath.distribute(
            amountCents: 9000, memberIDs: [asha.id, ben.id, cara.id])
        group.expenses.append(Expense(
            descriptionText: "Dinner", amountCents: 9000, payerID: asha.id,
            date: today, splitMode: "equal",
            splits: [asha.id, ben.id, cara.id].map {
                ExpenseSplit(memberID: $0, shareCents: dinnerShares[$0]!)
            }))
        let taxiShares = try SplitMath.distribute(
            amountCents: 3000, memberIDs: [ben.id, cara.id])
        group.expenses.append(Expense(
            descriptionText: "Taxi", amountCents: 3000, payerID: ben.id,
            date: today, splitMode: "equal",
            splits: [ben.id, cara.id].map {
                ExpenseSplit(memberID: $0, shareCents: taxiShares[$0]!)
            }))

        let bal = BalanceMath.balances(group: group)
        XCTAssertEqual(bal.values.reduce(0, +), 0)
        XCTAssertEqual(bal, [asha.id: 6000, ben.id: -1500, cara.id: -4500])

        let transfers = BalanceMath.simplifyDebts(balances: bal)
        XCTAssertEqual(transfers.count, 2)
        XCTAssertEqual(Set(transfers.map { "\($0.fromID)-\($0.toID)-\($0.amountCents)" }),
                       ["\(ben.id)-\(asha.id)-1500", "\(cara.id)-\(asha.id)-4500"])

        group.settlements.append(Settlement(fromID: cara.id, toID: asha.id,
                                            amountCents: 4500, date: today))
        let bal2 = BalanceMath.balances(group: group)
        XCTAssertEqual(bal2.values.reduce(0, +), 0)
        XCTAssertEqual(bal2[cara.id], 0)
    }

    // MARK: - Splitwise CSV (ports CsvTests)

    static let sampleCSV = """
    Date,Description,Category,Cost,Currency,Parthey,Shannon,Het
    2026-10-01,Dinner,Food,80.00,USD,40.00,-40.00,0.00
    2026-10-02,Taxi,Transport,24.00,USD,-12.00,12.00,0.00
    2026-10-03,Broken row,Food,not-a-number,USD,0.00,0.00,0.00
    2026-10-04,Groceries,Food,90.00,USD,60.00,-30.00,-30.00
    """

    func testImportPreviewAndErrors() {
        let parsed = SplitwiseCSV.parse(Self.sampleCSV)
        XCTAssertEqual(parsed.memberNames, ["Parthey", "Shannon", "Het"])
        XCTAssertEqual(parsed.rows.count, 3)
        XCTAssertEqual(parsed.errors.count, 1)
        XCTAssertTrue(parsed.errors.first?.contains("Row 4") ?? false,
                      "Errors: \(parsed.errors)")
        let dinner = parsed.rows[0]
        XCTAssertEqual(dinner.payerName, "Parthey")
        XCTAssertEqual(dinner.splitsByName, ["Parthey": 4000, "Shannon": 4000])
    }

    func testImportExportRoundTrip() {
        let parsed = SplitwiseCSV.parse(Self.sampleCSV)
        var group = SplitGroup(name: "Imported")
        var idsByName: [String: UUID] = [:]
        for name in parsed.memberNames {
            let member = Member(name: name)
            group.members.append(member)
            idsByName[name] = member.id
        }
        for row in parsed.rows {
            group.expenses.append(Expense(
                descriptionText: row.descriptionText, amountCents: row.costCents,
                payerID: idsByName[row.payerName]!, date: row.date,
                splitMode: "import", kind: "import",
                splits: row.splitsByName.map {
                    ExpenseSplit(memberID: idsByName[$0.key]!, shareCents: $0.value)
                }))
        }
        let bal = BalanceMath.balances(group: group)
        XCTAssertEqual(bal.values.reduce(0, +), 0)

        let out = SplitwiseCSV.export(group: group)
        XCTAssertTrue(out.contains("Dinner"))
        XCTAssertTrue(out.contains("Groceries"))
        let reparsed = SplitwiseCSV.parse(out)
        XCTAssertEqual(reparsed.rows.count, 3)
        XCTAssertEqual(reparsed.errors, [])
    }
}
