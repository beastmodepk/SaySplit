import SwiftUI

/// Payments preview — COMING SOON, no real money moves.
///
/// Shows the whole future settle-up experience so it can be reviewed in
/// TestFlight: connect a bank with Plaid, pay a group member by bank
/// transfer (ACH) or via Venmo / Cash App / Zelle / Apple Cash, and
/// auto-settle new expenses. Every action on this screen is disabled;
/// settle-ups in the app today are records only.
struct PaymentsComingSoonView: View {
    let group: SplitGroup
    let transfers: [DebtTransfer]

    var body: some View {
        List {
            headerSection
            bankSection
            methodsSection
            autoSettleSection
            if !transfers.isEmpty {
                readyToSettleSection
            }
        }
        .navigationTitle("Payments")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "banknote")
                        .font(.system(size: 30))
                        .foregroundStyle(.tint)
                    Spacer()
                    ComingSoonBadge()
                }
                Text("Pay & get paid, right here")
                    .font(.title3.bold())
                Text("Soon you will settle up without leaving SaySplit — "
                     + "no more recording a payment here and then going to "
                     + "another app to actually send it. Connect your bank "
                     + "once, then one tap pays exactly what the group owes.")
                    .foregroundStyle(.secondary)
                Text("Nothing on this screen moves real money yet. "
                     + "Settle-ups today are still records in the app only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Bank (Plaid)

    private var bankSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "building.columns")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect your bank with Plaid")
                    Text("Secure bank link — account verified, balance checked "
                         + "before a payment is sent. SaySplit never sees or "
                         + "stores your bank login.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
            } label: {
                Text("Connect bank")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)
        } header: {
            Text("Your bank")
        } footer: {
            Text("Bank connection is the first payments feature to launch.")
        }
    }

    // MARK: - Payment methods

    private var methodsSection: some View {
        Section {
            methodRow(icon: "arrow.left.arrow.right",
                      title: "Bank transfer (ACH)",
                      detail: "Pay a group member bank-to-bank from your connected account.")
            methodRow(icon: "v.circle",
                      title: "Venmo",
                      detail: "Open Venmo pre-filled with the right person and amount.")
            methodRow(icon: "dollarsign.circle",
                      title: "Cash App",
                      detail: "Open Cash App pre-filled with the right person and amount.")
            methodRow(icon: "z.circle",
                      title: "Zelle",
                      detail: "Send through your own bank's Zelle, then confirm here.")
            methodRow(icon: "apple.logo",
                      title: "Apple Cash",
                      detail: "Pay with Apple Cash in Messages, then confirm here.")
        } header: {
            Text("Payment methods")
        } footer: {
            Text("Every method ends the same way: the settle-up records itself, "
                 + "so balances are right without manual entry.")
        }
    }

    private func methodRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ComingSoonBadge()
        }
        .opacity(0.75)
    }

    // MARK: - Auto-settle

    private var autoSettleSection: some View {
        Section {
            Toggle(isOn: .constant(false)) {
                Label("Auto-settle new expenses", systemImage: "bolt")
            }
            .disabled(true)
            Toggle(isOn: .constant(false)) {
                Label("Round-up settle weekly", systemImage: "calendar.badge.clock")
            }
            .disabled(true)
        } header: {
            Text("Automation")
        } footer: {
            Text("With a bank connected, SaySplit will be able to settle small "
                 + "balances automatically — weekly, or the moment an expense "
                 + "is added — so nobody has to chase anyone for $6.40.")
        }
    }

    // MARK: - Ready to settle (this group's real debts, preview only)

    private var readyToSettleSection: some View {
        Section {
            ForEach(Array(transfers.enumerated()), id: \.offset) { _, transfer in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(group.memberName(id: transfer.fromID)) pays "
                             + "\(group.memberName(id: transfer.toID))")
                            .font(.subheadline)
                        Text("Will be payable in one tap when payments launch.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Money.format(transfer.amountCents))
                        .font(.subheadline.bold())
                }
                Button {
                } label: {
                    Text("Pay")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
        } header: {
            Text("Ready to settle in \(group.name)")
        }
    }
}

/// Small pill shown next to every not-yet-live payments action.
struct ComingSoonBadge: View {
    var body: some View {
        Text("COMING SOON")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.2))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }
}
