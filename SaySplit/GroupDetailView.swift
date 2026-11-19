import SwiftUI

/// One group: command box (voice + typed), balances & settle-up,
/// activity feed, members, rename and CSV export.
struct GroupDetailView: View {
    @EnvironmentObject private var store: SaySplitStore
    let groupID: UUID

    @StateObject private var speech = SpeechRecognizer()
    @State private var commandText = ""
    @State private var parsedPreview: ParsedCommand? = nil
    @State private var showingPreview = false

    @State private var showingManual = false
    @State private var showingReceipt = false
    @State private var settlePrefill: DebtTransfer? = nil
    @State private var showingSettle = false
    @State private var showingPayments = false

    @State private var showingAddMember = false
    @State private var newMemberName = ""
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var errorMessage: String? = nil
    @State private var exportURL: URL? = nil

    private var group: SplitGroup? { store.group(id: groupID) }

    var body: some View {
        Group {
            if let group = group {
                List {
                    commandSection(group: group)
                    balancesSection(group: group)
                    activitySection(group: group)
                    membersSection(group: group)
                    settingsSection(group: group)
                }
            } else {
                Text("This group no longer exists.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { exportURL = store.exportFileURL(groupID: groupID) }
        .onChange(of: group?.expenses.count) { _, _ in
            exportURL = store.exportFileURL(groupID: groupID)
        }
        .sheet(isPresented: $showingPreview) {
            if let parsed = parsedPreview, let group = group {
                ParsePreviewView(group: group, parsed: parsed) {
                    showingPreview = false
                }
            }
        }
        .sheet(isPresented: $showingManual) {
            if let group = group {
                ManualExpenseView(group: group) { showingManual = false }
            }
        }
        .sheet(isPresented: $showingReceipt) {
            if let group = group {
                ReceiptExpenseView(group: group) { showingReceipt = false }
            }
        }
        .sheet(isPresented: $showingSettle) {
            if let group = group {
                SettleUpView(group: group, prefill: settlePrefill) { showingSettle = false }
            }
        }
        .sheet(isPresented: $showingPayments) {
            if let group = group {
                NavigationStack {
                    PaymentsComingSoonView(group: group,
                                           transfers: store.simplifiedDebts(groupID: groupID))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingPayments = false }
                            }
                        }
                }
            }
        }
        .alert("Add Member", isPresented: $showingAddMember) {
            TextField("Name", text: $newMemberName)
            Button("Add") {
                if let error = store.addMember(groupID: groupID, name: newMemberName) {
                    errorMessage = error
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Rename Group", isPresented: $showingRename) {
            TextField("Group name", text: $renameText)
            Button("Save") {
                if let error = store.renameGroup(id: groupID, name: renameText) {
                    errorMessage = error
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Heads up", isPresented: errorPresented) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Command box

    private func commandSection(group: SplitGroup) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        speech.toggleRecording()
                    } label: {
                        Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(speech.isRecording ? .red : .accentColor)
                    }
                    .buttonStyle(.plain)
                    TextField("Say or type: “Dinner, eighty dollars, split four ways”",
                              text: $commandText, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                }
                if speech.isRecording {
                    Text("Listening… tap the mic again to stop.")
                        .font(.footnote).foregroundStyle(.red)
                }
                if let message = speech.statusMessage {
                    Text(message)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button {
                    let names = group.members.map { $0.name }
                    parsedPreview = CommandParser.parseCommand(commandText, memberNames: names)
                    showingPreview = true
                } label: {
                    Text("Parse & preview")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(commandText.trimmingCharacters(in: .whitespaces).isEmpty
                          || group.members.isEmpty)
                if group.members.isEmpty {
                    Text("Add at least one member below before adding expenses.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                HStack {
                    Button {
                        showingManual = true
                    } label: {
                        Label("Add manually", systemImage: "square.and.pencil")
                    }
                    Spacer()
                    Button {
                        showingReceipt = true
                    } label: {
                        Label("Receipt mode", systemImage: "receipt")
                    }
                }
                .font(.subheadline)
            }
            .padding(.vertical, 4)
            .onChange(of: speech.transcript) { _, newValue in
                if speech.isRecording { commandText = newValue }
            }
        } header: {
            Text("Add an expense by voice")
        } footer: {
            Text("Nothing is saved from a parse until you confirm the preview.")
        }
    }

    // MARK: - Balances

    private func balancesSection(group: SplitGroup) -> some View {
        let balances = store.balances(groupID: groupID)
        let transfers = store.simplifiedDebts(groupID: groupID)
        return Section {
            if group.members.isEmpty {
                Text("No members yet.").foregroundStyle(.secondary)
            } else {
                ForEach(group.members) { member in
                    let balance = balances[member.id] ?? 0
                    HStack {
                        Text(member.name)
                        Spacer()
                        if balance > 0 {
                            Text("is owed \(Money.format(balance))")
                                .foregroundStyle(.green)
                        } else if balance < 0 {
                            Text("owes \(Money.format(-balance))")
                                .foregroundStyle(.red)
                        } else {
                            Text("settled up").foregroundStyle(.secondary)
                        }
                    }
                }
                if !transfers.isEmpty {
                    Divider()
                    Text("Simplified debts").font(.subheadline.bold())
                    ForEach(Array(transfers.enumerated()), id: \.offset) { _, transfer in
                        HStack {
                            Text("\(group.memberName(id: transfer.fromID)) pays "
                                 + "\(group.memberName(id: transfer.toID)) "
                                 + Money.format(transfer.amountCents))
                                .font(.subheadline)
                            Spacer()
                            Button("Record") {
                                settlePrefill = transfer
                                showingSettle = true
                            }
                            .font(.subheadline)
                        }
                    }
                }
                Button {
                    settlePrefill = nil
                    showingSettle = true
                } label: {
                    Label("Record a settle-up", systemImage: "checkmark.circle")
                }
                Button {
                    showingPayments = true
                } label: {
                    HStack {
                        Label("Pay & get paid", systemImage: "banknote")
                        Spacer()
                        ComingSoonBadge()
                    }
                }
            }
        } header: {
            Text("Balances & settle up")
        } footer: {
            Text("Balances always add up to $0.00. A settle-up is a record in the app — no real money moves.")
        }
    }

    // MARK: - Activity

    private func activitySection(group: SplitGroup) -> some View {
        let items = store.activity(groupID: groupID)
        return Section {
            if items.isEmpty {
                Text("No expenses yet.").foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    switch item {
                    case .expense(let expense):
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(expense.descriptionText).font(.headline)
                                Spacer()
                                Text(Money.format(expense.amountCents))
                            }
                            Text("\(group.memberName(id: expense.payerID)) paid · "
                                 + expense.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(expense.splits.map { split in
                                "\(group.memberName(id: split.memberID)) \(Money.format(split.shareCents))"
                            }.joined(separator: " · "))
                                .font(.footnote).foregroundStyle(.secondary)
                            if let detail = expense.detail {
                                Text(detail).font(.footnote).foregroundStyle(.secondary)
                            }
                            if expense.receiptPhotoFilename != nil {
                                Label("Receipt photo attached (reference only — no OCR)",
                                      systemImage: "photo")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    case .settlement(let settlement):
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(.green)
                            Text("\(group.memberName(id: settlement.fromID)) paid "
                                 + "\(group.memberName(id: settlement.toID))")
                            Spacer()
                            Text(Money.format(settlement.amountCents))
                        }
                        .font(.subheadline)
                    }
                }
            }
        } header: {
            Text("Activity")
        }
    }

    // MARK: - Members

    private func membersSection(group: SplitGroup) -> some View {
        Section {
            ForEach(group.members) { member in
                HStack {
                    Text(member.name)
                    Spacer()
                    Button(role: .destructive) {
                        if let error = store.removeMember(groupID: groupID, memberID: member.id) {
                            errorMessage = error
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                newMemberName = ""
                showingAddMember = true
            } label: {
                Label("Add member", systemImage: "person.badge.plus")
            }
        } header: {
            Text("Members")
        } footer: {
            Text("A member who is on existing expenses can't be removed — the app will tell you why.")
        }
    }

    // MARK: - Settings / export

    private func settingsSection(group: SplitGroup) -> some View {
        Section {
            Button {
                renameText = group.name
                showingRename = true
            } label: {
                Label("Rename group", systemImage: "pencil")
            }
            if let exportURL = exportURL {
                ShareLink(item: exportURL) {
                    Label("Export Splitwise CSV", systemImage: "square.and.arrow.up")
                }
            }
        } header: {
            Text("Group")
        }
    }
}
