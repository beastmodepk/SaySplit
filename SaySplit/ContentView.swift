import SwiftUI
import UniformTypeIdentifiers

/// Home screen: the group list, quick-start empty state, group creation,
/// the clearly-labelled demo button, and the Splitwise import entry point.
struct ContentView: View {
    @EnvironmentObject private var store: SaySplitStore

    @State private var showingCreateGroup = false
    @State private var newGroupName = ""
    @State private var errorMessage: String? = nil

    @State private var showingImporter = false
    @State private var importPreview: SplitwiseParseResult? = nil
    @State private var showingImportPreview = false
    @State private var importGroupName = "Imported from Splitwise"
    @State private var importError: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.groups.isEmpty {
                    emptyState
                } else {
                    groupList
                }
            }
            .navigationTitle("SaySplit")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newGroupName = ""
                        showingCreateGroup = true
                    } label: {
                        Label("New Group", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Splitwise CSV", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        store.loadDemoGroup()
                    } label: {
                        Label("Load demo group", systemImage: "play.circle")
                    }
                }
            }
            .alert("New Group", isPresented: $showingCreateGroup) {
                TextField("Group name, e.g. Lisbon Trip", text: $newGroupName)
                Button("Create") {
                    if store.createGroup(name: newGroupName) == nil {
                        errorMessage = "Group name cannot be empty."
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Something went wrong", isPresented: errorPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                handleImportFile(result)
            }
            .sheet(isPresented: $showingImportPreview) {
                if let preview = importPreview {
                    ImportPreviewView(result: preview,
                                      groupName: $importGroupName) {
                        if store.importGroup(name: importGroupName, result: preview) != nil {
                            showingImportPreview = false
                        } else {
                            importError = "Import failed — give the group a name and make sure at least one row is valid."
                        }
                    }
                }
            }
            .alert("Import problem", isPresented: importErrorPresented) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text("Say it. Split it.")
                    .font(.title2.bold())
                Text("Create a group, add the people in it, then say or type "
                     + "“Dinner, eighty dollars, split four ways”. "
                     + "You always check the parsed preview before anything is saved.")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick start").font(.headline)
                    Text("1.  Tap + to create your first group.")
                    Text("2.  Add members inside the group.")
                    Text("3.  Speak or type an expense in the command box.")
                    Text("4.  Confirm the preview — balances update automatically.")
                }
                .font(.subheadline)
                Button {
                    store.loadDemoGroup()
                } label: {
                    Label("Load demo group", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Text("Demo data is only created when you tap that button.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var groupList: some View {
        List {
            ForEach(store.groups) { group in
                NavigationLink {
                    GroupDetailView(groupID: group.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name).font(.headline)
                        Text("\(group.members.count) member(s) · \(group.expenses.count) expense(s)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func handleImportFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let url):
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    importError = "That file is not readable text CSV."
                    return
                }
                let parsed = SplitwiseCSV.parse(text)
                importPreview = parsed
                importGroupName = "Imported from Splitwise"
                showingImportPreview = true
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}
