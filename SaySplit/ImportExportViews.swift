import SwiftUI

/// Splitwise import preview: row counts, total, members, and every
/// per-row error — shown BEFORE anything is imported, mirroring the
/// web version. Confirming creates a new group from the good rows only.
struct ImportPreviewView: View {
    let result: SplitwiseParseResult
    @Binding var groupName: String
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("New group name", text: $groupName)
                    HStack {
                        Text("Rows ready to import")
                        Spacer()
                        Text("\(result.rows.count)")
                    }
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(Money.format(result.totalCents))
                    }
                    HStack {
                        Text("Members found")
                        Spacer()
                        Text(result.memberNames.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Import preview")
                }

                if !result.rows.isEmpty {
                    Section {
                        ForEach(Array(result.rows.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(row.descriptionText).font(.headline)
                                    Spacer()
                                    Text(Money.format(row.costCents))
                                }
                                Text("\(row.dateText) · \(row.payerName) paid")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Expenses")
                    }
                }

                if !result.errors.isEmpty {
                    Section {
                        ForEach(result.errors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        Text("These rows will be skipped — they are reported here, never silently dropped.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } header: {
                        Text("Rows with problems (\(result.errors.count))")
                    }
                }
            }
            .navigationTitle("Import Splitwise CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm import") { onConfirm() }
                        .disabled(result.rows.isEmpty)
                }
            }
        }
    }
}
