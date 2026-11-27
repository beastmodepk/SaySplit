import SwiftUI

struct ConnectionsGroup: Equatable, Identifiable {
    var id: String { category }
    let category: String
    let words: [String]
    let level: Int // 0 yellow, 1 green, 2 blue, 3 purple
    var color: Color {
        switch level {
        case 0: return Color.yellow.opacity(0.85)
        case 1: return Color.green.opacity(0.75)
        case 2: return Color.blue.opacity(0.65)
        case 3: return Color.purple.opacity(0.65)
        default: return Color.gray
        }
    }
}

struct ConnectionsPuzzle: Equatable {
    let groups: [ConnectionsGroup]
    var allWords: [String] { groups.flatMap { $0.words } }
}

enum ConnectionsLogic {
    static func matchingGroup(selected: Set<String>, in puzzle: ConnectionsPuzzle) -> ConnectionsGroup? {
        puzzle.groups.first { Set($0.words) == selected }
    }
    static func isOneAway(selected: Set<String>, in puzzle: ConnectionsPuzzle) -> Bool {
        puzzle.groups.contains { group in
            Set(group.words).intersection(selected).count == 3
        }
    }
    static func isSolved(puzzle: ConnectionsPuzzle, solved: [ConnectionsGroup]) -> Bool {
        solved.count == puzzle.groups.count
    }
}

enum ConnectionsPuzzles {
    static let all: [ConnectionsPuzzle] = [
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Fruits", words: ["APPLE","BANANA","GRAPE","PEACH"], level: 0),
            ConnectionsGroup(category: "Animals", words: ["TIGER","LION","BEAR","WOLF"], level: 1),
            ConnectionsGroup(category: "In the sky", words: ["SUN","MOON","STAR","CLOUD"], level: 2),
            ConnectionsGroup(category: "___ cake", words: ["PAN","CUP","CHEESE","CARROT"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Kitchen items", words: ["SPOON","FORK","KNIFE","PLATE"], level: 0),
            ConnectionsGroup(category: "Sports", words: ["SOCCER","TENNIS","GOLF","RUGBY"], level: 1),
            ConnectionsGroup(category: "Weather", words: ["RAIN","SNOW","WIND","HAIL"], level: 2),
            ConnectionsGroup(category: "___ board", words: ["CARD","SKATE","SURF","KEY"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Colors", words: ["RED","BLUE","GREEN","BLACK"], level: 0),
            ConnectionsGroup(category: "Body parts", words: ["HAND","FOOT","HEAD","NOSE"], level: 1),
            ConnectionsGroup(category: "In a classroom", words: ["DESK","BOOK","PEN","RULER"], level: 2),
            ConnectionsGroup(category: "___ fish", words: ["GOLD","JELLY","STAR","CAT"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Trees", words: ["OAK","PINE","MAPLE","PALM"], level: 0),
            ConnectionsGroup(category: "Planets", words: ["MARS","VENUS","EARTH","SATURN"], level: 1),
            ConnectionsGroup(category: "Drinks", words: ["COFFEE","TEA","JUICE","MILK"], level: 2),
            ConnectionsGroup(category: "___ berry", words: ["BLUE","STRAW","CRAN","BLACK"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Metals", words: ["GOLD","SILVER","IRON","COPPER"], level: 0),
            ConnectionsGroup(category: "Instruments", words: ["PIANO","GUITAR","DRUM","FLUTE"], level: 1),
            ConnectionsGroup(category: "Seasons", words: ["SPRING","SUMMER","AUTUMN","WINTER"], level: 2),
            ConnectionsGroup(category: "___ dog", words: ["HOT","CORN","BULL","WATCH"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Flowers", words: ["ROSE","TULIP","DAISY","LILY"], level: 0),
            ConnectionsGroup(category: "Birds", words: ["EAGLE","ROBIN","OWL","CROW"], level: 1),
            ConnectionsGroup(category: "Jobs", words: ["DOCTOR","TEACHER","CHEF","PILOT"], level: 2),
            ConnectionsGroup(category: "___ light", words: ["SUN","MOON","TRAFFIC","SPOT"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Vegetables", words: ["CARROT","POTATO","ONION","CORN"], level: 0),
            ConnectionsGroup(category: "Shapes", words: ["CIRCLE","SQUARE","OVAL","HEART"], level: 1),
            ConnectionsGroup(category: "Gems", words: ["RUBY","PEARL","OPAL","JADE"], level: 2),
            ConnectionsGroup(category: "___ room", words: ["BED","BATH","CLASS","MUSH"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Ocean animals", words: ["SHARK","WHALE","CRAB","SHRIMP"], level: 0),
            ConnectionsGroup(category: "Desserts", words: ["CAKE","PIE","COOKIE","BROWNIE"], level: 1),
            ConnectionsGroup(category: "Countries", words: ["FRANCE","SPAIN","ITALY","JAPAN"], level: 2),
            ConnectionsGroup(category: "___ ball", words: ["BASE","FOOT","BASKET","SNOW"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Furniture", words: ["CHAIR","TABLE","SOFA","LAMP"], level: 0),
            ConnectionsGroup(category: "Feelings", words: ["HAPPY","SAD","ANGRY","CALM"], level: 1),
            ConnectionsGroup(category: "Transport", words: ["CAR","BUS","TRAIN","PLANE"], level: 2),
            ConnectionsGroup(category: "___ print", words: ["BLUE","FOOT","FINGER","NEWS"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Insects", words: ["ANT","BEE","WASP","MOTH"], level: 0),
            ConnectionsGroup(category: "In the kitchen cupboard", words: ["SALT","PEPPER","CUMIN","BASIL"], level: 1),
            ConnectionsGroup(category: "Tools", words: ["HAMMER","DRILL","SAW","WRENCH"], level: 2),
            ConnectionsGroup(category: "___ fly", words: ["BUTTER","DRAGON","HOUSE","FIRE"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Breakfast foods", words: ["EGG","BACON","TOAST","WAFFLE"], level: 0),
            ConnectionsGroup(category: "School subjects", words: ["MATH","ART","HISTORY","MUSIC"], level: 1),
            ConnectionsGroup(category: "Pets", words: ["DOG","CAT","FISH","BIRD"], level: 2),
            ConnectionsGroup(category: "___ man", words: ["BAT","SPIDER","SUPER","IRON"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Bodies of water", words: ["RIVER","LAKE","OCEAN","POND"], level: 0),
            ConnectionsGroup(category: "Clothing", words: ["SHIRT","PANTS","DRESS","HAT"], level: 1),
            ConnectionsGroup(category: "Music genres", words: ["ROCK","JAZZ","POP","BLUES"], level: 2),
            ConnectionsGroup(category: "___ top", words: ["TABLE","LAP","COUNTER","MOUNTAIN"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Games", words: ["CHESS","CLUE","RISK","LIFE"], level: 0),
            ConnectionsGroup(category: "Card suits", words: ["HEART","SPADE","CLUB","DIAMOND"], level: 1),
            ConnectionsGroup(category: "Citrus fruits", words: ["LEMON","LIME","ORANGE","GRAPEFRUIT"], level: 2),
            ConnectionsGroup(category: "___ stick", words: ["CHOP","LIP","GLOW","YARD"], level: 3),
        ]),
        ConnectionsPuzzle(groups: [
            ConnectionsGroup(category: "Holidays", words: ["CHRISTMAS","DIWALI","EASTER","HANUKKAH"], level: 0),
            ConnectionsGroup(category: "Classic elements", words: ["FIRE","WATER","EARTH","AIR"], level: 1),
            ConnectionsGroup(category: "Directions", words: ["NORTH","SOUTH","EAST","WEST"], level: 2),
            ConnectionsGroup(category: "___ phone", words: ["SMART","CELL","HEAD","EAR"], level: 3),
        ]),
    ]

    static func daily(date: Date = Date()) -> ConnectionsPuzzle {
        let day = Int(date.timeIntervalSince1970 / 86400)
        return all[abs(day) % all.count]
    }
}

struct ConnectionsView: View {
    @Binding var selectedDate: Date

    @State private var puzzle: ConnectionsPuzzle
    @State private var remaining: [String] = []
    @State private var selected: Set<String> = []
    @State private var solved: [ConnectionsGroup] = []
    @State private var mistakes = 0
    @State private var message = ""
    @State private var finished = false
    @State private var won = false
    @State private var access: PremiumSnapshot

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        _puzzle = State(initialValue: ConnectionsPuzzles.daily(date: selectedDate.wrappedValue))
        _access = State(initialValue: PremiumAccess.snapshot(game: .groupFour, date: selectedDate.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            DatePagerView(selectedDate: $selectedDate)

            Text(access.counterText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Tile grid + controls sit as ONE group, centred vertically
            // in the space left under the header (same arrangement as
            // Word Trio). The ScrollView + minHeight frame centres the
            // group when it is shorter than the space and lets it
            // scroll when it isn't. Once the free days are used up,
            // the lock screen takes the board's place.
            GeometryReader { geo in
                ScrollView {
                    Group {
                        if access.canPlay {
                            gameGroup
                        } else {
                            PremiumLockView(game: .groupFour) {
                                PremiumAccess.buyTestPurchase(.groupFour)
                                refreshAccess()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 8)
        .onAppear { loadGame(); refreshAccess() }
    }

    private func refreshAccess() {
        access = PremiumAccess.snapshot(game: .groupFour, on: selectedDate)
    }

    /// Title at the very top (where the date used to be).
    private var header: some View {
        Text("Group Four")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }

    private var gameGroup: some View {
        VStack(spacing: 12) {
            Text("Create four groups of four · Mistakes left: \(max(0, 4 - mistakes))")
                .font(.subheadline).foregroundStyle(.secondary)

            ForEach(solved) { group in
                VStack(spacing: 2) {
                    Text(group.category).font(.headline)
                    Text(group.words.joined(separator: ", ")).font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(group.color)
                .cornerRadius(8)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(remaining, id: \.self) { word in
                    Button(word) { toggle(word) }
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(selected.contains(word) ? Color.gray.opacity(0.7) : Color.gray.opacity(0.18))
                        .foregroundStyle(selected.contains(word) ? Color.white : Color.primary)
                        .cornerRadius(8)
                }
            }

            if !message.isEmpty { Text(message).font(.subheadline).foregroundStyle(.orange) }
            if finished {
                Text(won ? "You solved it!" : "Out of mistakes — groups revealed above.")
                    .font(.headline).foregroundStyle(won ? .green : .red)
            }

            HStack {
                Button("Shuffle") { remaining.shuffle(); saveProgress() }.buttonStyle(.bordered)
                Button("Deselect") { selected.removeAll() }.buttonStyle(.bordered)
                Button("Submit") { submit() }.buttonStyle(.borderedProminent).disabled(selected.count != 4 || finished)
            }
        }
    }

    private func toggle(_ word: String) {
        guard !finished else { return }
        if selected.contains(word) { selected.remove(word) }
        else if selected.count < 4 { selected.insert(word) }
    }

    private func submit() {
        guard selected.count == 4 else { return }
        guard !finished else { return }
        guard access.canPlay else { message = "Premium required"; return }
        // A submission is this game's accepted guess: it counts this
        // board date toward the 15 free played days (once — the store
        // is idempotent per date) and refreshes the counter at once.
        PremiumAccess.recordPlayed(date: selectedDate)
        refreshAccess()
        if let group = ConnectionsLogic.matchingGroup(selected: selected, in: puzzle) {
            solved.append(group)
            solved.sort { $0.level < $1.level }
            remaining.removeAll { group.words.contains($0) }
            selected.removeAll()
            message = ""
            if solved.count == 4 { won = true; finished = true }
        } else {
            let oneAway = ConnectionsLogic.isOneAway(selected: selected, in: puzzle)
            mistakes += 1
            message = oneAway ? "One away!" : "Not a group"
            if mistakes >= 4 {
                finished = true; won = false
                // Reveal remaining groups
                for group in puzzle.groups where !solved.contains(group) { solved.append(group) }
                solved.sort { $0.level < $1.level }
                remaining = []
                selected.removeAll()
            }
        }
        saveProgress()
        if finished {
            GameHistory.record(dateKey: GameCalendar.key(for: selectedDate),
                               game: "Group Four",
                               detail: won ? "Solved" : "Out of mistakes",
                               won: won)
            // Finished: today's remaining Group Four reminders are cancelled.
            ReminderScheduler.cancelRemainingToday(for: .groupFour)
            ReminderScheduler.sync()
        }
    }

    /// Loads the puzzle for the selected date, restoring that date's
    /// solved groups / mistakes if it was already played.
    private func loadGame() {
        puzzle = ConnectionsPuzzles.daily(date: selectedDate)
        if let saved = ConnectionsProgress.load(date: selectedDate, puzzle: puzzle) {
            solved = saved.solved
            remaining = saved.remaining
            mistakes = saved.mistakes
            finished = saved.finished
            won = saved.won
        } else {
            remaining = puzzle.allWords.shuffled()
            selected = []; solved = []; mistakes = 0; finished = false; won = false
        }
        selected = []
        message = ""
    }

    private func saveProgress() {
        ConnectionsProgress.save(date: selectedDate, solved: solved, remaining: remaining,
                                 mistakes: mistakes, finished: finished, won: won)
    }
}

/// Per-date Group Four progress, keyed "connections.<yyyy-MM-dd>.*".
/// Solved groups are stored by category name and re-matched to the date's puzzle.
enum ConnectionsProgress {
    struct Saved {
        let solved: [ConnectionsGroup]
        let remaining: [String]
        let mistakes: Int
        let finished: Bool
        let won: Bool
    }
    private static func key(_ field: String, date: Date) -> String {
        "acct.\(AuthManager.currentStorageKey).connections.\(GameCalendar.key(for: date)).\(field)"
    }
    static func load(date: Date, puzzle: ConnectionsPuzzle) -> Saved? {
        let d = UserDefaults.standard
        guard d.object(forKey: key("mistakes", date: date)) != nil else { return nil }
        let categories = (d.string(forKey: key("solved", date: date)) ?? "")
            .components(separatedBy: "|").filter { !$0.isEmpty }
        let solved = puzzle.groups.filter { categories.contains($0.category) }
            .sorted { $0.level < $1.level }
        let remainingRaw = d.string(forKey: key("remaining", date: date)) ?? ""
        let remaining = remainingRaw.isEmpty ? [] : remainingRaw.components(separatedBy: ",")
        return Saved(solved: solved, remaining: remaining,
                     mistakes: d.integer(forKey: key("mistakes", date: date)),
                     finished: d.bool(forKey: key("finished", date: date)),
                     won: d.bool(forKey: key("won", date: date)))
    }
    static func save(date: Date, solved: [ConnectionsGroup], remaining: [String],
                     mistakes: Int, finished: Bool, won: Bool) {
        let d = UserDefaults.standard
        d.set(solved.map { $0.category }.joined(separator: "|"), forKey: key("solved", date: date))
        d.set(remaining.joined(separator: ","), forKey: key("remaining", date: date))
        d.set(mistakes, forKey: key("mistakes", date: date))
        d.set(finished, forKey: key("finished", date: date))
        d.set(won, forKey: key("won", date: date))
    }
}
