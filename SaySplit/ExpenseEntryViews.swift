import SwiftUI
import PhotosUI
import UIKit

// MARK: - Shared bits

struct MemberChips: View {
    let members: [Member]
    @Binding var selectedIDs: Set<UUID>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(members) { member in
                    let selected = selectedIDs.contains(member.id)
                    Button {
                        if selected { selectedIDs.remove(member.id) }
                        else { selectedIDs.insert(member.id) }
                    } label: {
                        HStack(spacing: 4) {
                            if selected { Image(systemName: "checkmark") }
                            Text(member.name)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected ? Color.accentColor.opacity(0.25)
                                             : Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private func orderedIDs(group: SplitGroup, selected: Set<UUID>) -> [UUID] {
    group.members.map { $0.id }.filter { selected.contains($0) }
}

// MARK: - Parse preview (editable, confirm before saving — never auto-saves)

struct ParsePreviewView: View {
    @EnvironmentObject private var store: SaySplitStore
    let group: SplitGroup
    let parsed: ParsedCommand
    let onDone: () -> Void

    @State private var descriptionText: String
    @State private var amountText: String
    @State private var payerID: UUID?
    @State private var splitIDs: Set<UUID>
    @State private var date: Date
    @State private var errorMessage: String? = nil

    init(group: SplitGroup, parsed: ParsedCommand, onDone: @escaping () -> Void) {
        self.group = group
        self.parsed = parsed
        self.onDone = onDone
        _descriptionText = State(initialValue: parsed.descriptionText)
        _amountText = State(initialValue: parsed.amountCents.map {
            String(format: "%.2f", Double($0) / 100.0)
        } ?? "")
        let payer = group.members.first { $0.name == parsed.payerName } ?? group.members.first
        _payerID = State(initialValue: payer?.id)
        let names = Set(parsed.splitMemberNames)
        _splitIDs = State(initialValue: Set(group.members.filter { names.contains($0.name) }.map { $0.id }))
        _date = State(initialValue: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                if !parsed.warnings.isEmpty {
                    Section {
                        ForEach(parsed.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Check these")
                    }
                }
                Section {
                    Text("“\(parsed.raw)”")
                        .font(.footnote).foregroundStyle(.secondary)
                    TextField("Description", text: $descriptionText)
                    HStack {
                        Text("Amount $")
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Paid by", selection: $payerID) {
                        ForEach(group.members) { member in
                            Text(member.name).tag(Optional(member.id))
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Parsed expense — edit anything")
                }
                Section {
                    MemberChips(members: group.members, selectedIDs: $splitIDs)
                    Text("Split equally between the selected members.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: {
                    Text("Split between")
                }
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Confirm expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm & save") { save() }
                }
            }
        }
    }

    private func save() {
        guard let payerID = payerID else {
            errorMessage = "Pick who paid."
            return
        }
        guard let amount = Money.parse(amountText), amount > 0 else {
            errorMessage = "Amount must be more than zero."
            return
        }
        do {
            let shares = try SplitMath.computeSplits(
                amountCents: amount, mode: "equal",
                memberIDs: orderedIDs(group: group, selected: splitIDs))
            let expense = Expense(
                descriptionText: descriptionText, amountCents: amount, payerID: payerID,
                date: date, splitMode: "equal",
                splits: orderedIDs(group: group, selected: splitIDs).compactMap { id in
                    shares[id].map { ExpenseSplit(memberID: id, shareCents: $0) }
                })
            if let error = store.addExpense(groupID: group.id, expense: expense) {
                errorMessage = error
            } else {
                onDone()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Manual expense (equal / exact / shares)

struct ManualExpenseView: View {
    @EnvironmentObject private var store: SaySplitStore
    let group: SplitGroup
    let onDone: () -> Void

    @State private var descriptionText = ""
    @State private var amountText = ""
    @State private var payerID: UUID?
    @State private var date = Date()
    @State private var mode = "equal"
    @State private var splitIDs: Set<UUID>
    @State private var exactTexts: [UUID: String] = [:]
    @State private var shareTexts: [UUID: String] = [:]
    @State private var errorMessage: String? = nil

    init(group: SplitGroup, onDone: @escaping () -> Void) {
        self.group = group
        self.onDone = onDone
        _payerID = State(initialValue: group.members.first?.id)
        _splitIDs = State(initialValue: Set(group.members.map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description", text: $descriptionText)
                    HStack {
                        Text("Amount $")
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Paid by", selection: $payerID) {
                        ForEach(group.members) { member in
                            Text(member.name).tag(Optional(member.id))
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    Picker("Split mode", selection: $mode) {
                        Text("Equal").tag("equal")
                        Text("Exact $").tag("exact")
                        Text("Shares %").tag("shares")
                    }
                    .pickerStyle(.segmented)

                    if mode == "equal" {
                        MemberChips(members: group.members, selectedIDs: $splitIDs)
                    } else if mode == "exact" {
                        ForEach(group.members) { member in
                            HStack {
                                Text(member.name)
                                Spacer()
                                TextField("0.00", text: exactBinding(member.id))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                        }
                        Text("Exact amounts must add up to the total — the app checks.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ForEach(group.members) { member in
                            HStack {
                                Text(member.name)
                                Spacer()
                                TextField("0", text: shareBinding(member.id))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                        }
                        Text("Enter percentages or shares; they are applied proportionally.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Split")
                }
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Add expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func exactBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { exactTexts[id] ?? "" },
                set: { exactTexts[id] = $0 })
    }

    private func shareBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { shareTexts[id] ?? "" },
                set: { shareTexts[id] = $0 })
    }

    private func save() {
        guard let payerID = payerID else {
            errorMessage = "Pick who paid."
            return
        }
        guard let amount = Money.parse(amountText), amount > 0 else {
            errorMessage = "Amount must be more than zero."
            return
        }
        do {
            var exact: [UUID: Int] = [:]
            var shares: [UUID: Double] = [:]
            if mode == "exact" {
                for member in group.members {
                    if let cents = Money.parse(exactTexts[member.id] ?? ""), cents != 0 {
                        exact[member.id] = cents
                    }
                }
            } else if mode == "shares" {
                for member in group.members {
                    if let value = Double(shareTexts[member.id] ?? ""), value != 0 {
                        shares[member.id] = value
                    }
                }
            }
            let computed = try SplitMath.computeSplits(
                amountCents: amount, mode: mode,
                memberIDs: orderedIDs(group: group, selected: splitIDs),
                exact: exact, shares: shares)
            let ordered = group.members.map { $0.id }.filter { computed[$0] != nil }
            let expense = Expense(
                descriptionText: descriptionText, amountCents: amount, payerID: payerID,
                date: date, splitMode: mode,
                splits: ordered.compactMap { id in
                    computed[id].map { ExpenseSplit(memberID: id, shareCents: $0) }
                })
            if let error = store.addExpense(groupID: group.id, expense: expense) {
                errorMessage = error
            } else {
                onDone()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Receipt mode

struct ReceiptItemDraft: Identifiable {
    var id = UUID()
    var name: String = ""
    var priceText: String = ""
    var assigneeIDs: Set<UUID> = []
}

struct ReceiptExpenseView: View {
    @EnvironmentObject private var store: SaySplitStore
    let group: SplitGroup
    let onDone: () -> Void

    @State private var descriptionText = "Receipt"
    @State private var payerID: UUID?
    @State private var date = Date()
    @State private var items: [ReceiptItemDraft] = [ReceiptItemDraft()]
    @State private var taxText = ""
    @State private var tipText = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var errorMessage: String? = nil

    init(group: SplitGroup, onDone: @escaping () -> Void) {
        self.group = group
        self.onDone = onDone
        _payerID = State(initialValue: group.members.first?.id)
    }

    private var computedItems: [ReceiptItemInput] {
        items.map { draft in
            ReceiptItemInput(name: draft.name,
                             priceCents: Money.parse(draft.priceText) ?? 0,
                             assigneeIDs: orderedIDs(group: group, selected: draft.assigneeIDs))
        }
    }

    private var preview: (perMember: [UUID: Int], subtotal: Int, total: Int)? {
        try? ReceiptMath.splits(items: computedItems,
                                taxCents: Money.parse(taxText) ?? 0,
                                tipCents: Money.parse(tipText) ?? 0)
    }

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                receiptFormContent
            }
            .navigationTitle("Receipt expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var receiptFormContent: some View {
        Section {
            TextField("Description", text: $descriptionText)
            Picker("Paid by", selection: $payerID) {
                ForEach(group.members) { member in
                    Text(member.name).tag(Optional(member.id))
                }
            }
            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
        Section {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoData == nil ? "Attach receipt photo"
                                       : "Receipt photo attached — tap to change",
                      systemImage: "photo")
            }
            if let photoData = photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
            }
            Text("No OCR — enter items from the photo by hand below. "
                 + "The photo is kept only as a reference.")
                .font(.footnote).foregroundStyle(.secondary)
        } header: {
            Text("Receipt photo (reference only)")
        }
        ForEach($items) { $item in
            Section {
                TextField("Item name, e.g. Pancakes", text: $item.name)
                HStack {
                    Text("Price $")
                    TextField("0.00", text: $item.priceText)
                        .keyboardType(.decimalPad)
                }
                Text("Who had it? (shared items split between everyone ticked)")
                    .font(.footnote).foregroundStyle(.secondary)
                MemberChips(members: group.members, selectedIDs: $item.assigneeIDs)
                if items.count > 1 {
                    Button(role: .destructive) {
                        items.removeAll { $0.id == item.id }
                    } label: {
                        Text("Remove item")
                    }
                }
            }
        }
        Section {
            Button {
                items.append(ReceiptItemDraft())
            } label: {
                Label("Add another item", systemImage: "plus")
            }
        }
        Section {
            HStack {
                Text("Tax $")
                TextField("0.00", text: $taxText).keyboardType(.decimalPad)
            }
            HStack {
                Text("Tip $")
                TextField("0.00", text: $tipText).keyboardType(.decimalPad)
            }
            if let preview = preview {
                Text("Subtotal \(Money.format(preview.subtotal)) · "
                     + "Total \(Money.format(preview.total))")
                    .font(.subheadline.bold())
                ForEach(group.members) { member in
                    if let cents = preview.perMember[member.id] {
                        HStack {
                            Text(member.name)
                            Spacer()
                            Text(Money.format(cents))
                        }
                        .font(.subheadline)
                    }
                }
            } else {
                Text("Add priced items with people assigned and the "
                     + "reconciled per-person totals will appear here. "
                     + "Tax and tip are shared in proportion to what each person had.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Tax, tip & totals")
        }
        if let errorMessage = errorMessage {
            Section {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
        }
    }

    private func save() {
        guard let payerID = payerID else {
            errorMessage = "Pick who paid."
            return
        }
        do {
            let tax = Money.parse(taxText) ?? 0
            let tip = Money.parse(tipText) ?? 0
            let result = try ReceiptMath.splits(items: computedItems,
                                                taxCents: tax, tipCents: tip)
            var photoFilename: String? = nil
            if let photoData = photoData {
                photoFilename = store.saveReceiptPhoto(photoData)
            }
            let detail = "Receipt · Subtotal \(Money.format(result.subtotal)) · "
                + "Tax \(Money.format(tax)) · Tip \(Money.format(tip))"
            let ordered = group.members.map { $0.id }.filter { result.perMember[$0] != nil }
            let expense = Expense(
                descriptionText: descriptionText, amountCents: result.total, payerID: payerID,
                date: date, splitMode: "receipt", kind: "receipt",
                splits: ordered.compactMap { id in
                    result.perMember[id].map { ExpenseSplit(memberID: id, shareCents: $0) }
                },
                detail: detail, receiptPhotoFilename: photoFilename)
            if let error = store.addExpense(groupID: group.id, expense: expense) {
                errorMessage = error
            } else {
                onDone()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Settle up

struct SettleUpView: View {
    @EnvironmentObject private var store: SaySplitStore
    let group: SplitGroup
    let onDone: () -> Void

    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var amountText: String
    @State private var date = Date()
    @State private var errorMessage: String? = nil

    init(group: SplitGroup, prefill: DebtTransfer?, onDone: @escaping () -> Void) {
        self.group = group
        self.onDone = onDone
        _fromID = State(initialValue: prefill?.fromID ?? group.members.first?.id)
        _toID = State(initialValue: prefill?.toID
                        ?? group.members.dropFirst().first?.id
                        ?? group.members.first?.id)
        _amountText = State(initialValue: prefill.map {
            String(format: "%.2f", Double($0.amountCents) / 100.0)
        } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("From", selection: $fromID) {
                    ForEach(group.members) { member in
                        Text(member.name).tag(Optional(member.id))
                    }
                }
                Picker("Paid to", selection: $toID) {
                    ForEach(group.members) { member in
                        Text(member.name).tag(Optional(member.id))
                    }
                }
                HStack {
                    Text("Amount $")
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Text("This records a payment inside the app. No real money moves.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Record settle-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        guard let fromID = fromID, let toID = toID else {
            errorMessage = "Pick both members."
            return
        }
        guard let amount = Money.parse(amountText) else {
            errorMessage = "Enter an amount."
            return
        }
        if let error = store.addSettlement(groupID: group.id, fromID: fromID,
                                           toID: toID, amountCents: amount, date: date) {
            errorMessage = error
        } else {
            onDone()
        }
    }
}
