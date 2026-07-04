import SwiftUI
import ColdCoachCore

struct PlaybookListView: View {
    @EnvironmentObject var model: AppModel
    @State private var editing: Playbook?
    @State private var creatingNew = false

    var body: some View {
        Group {
            if model.playbooks.isEmpty {
                ContentUnavailableView {
                    Label("No playbooks yet", systemImage: "book.closed")
                } description: {
                    Text("Describe your offer in one sentence and generate signal-based openers, discovery questions, and objection responses.")
                } actions: {
                    Button("Create playbook") { creatingNew = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(model.playbooks) { playbook in
                        Button { editing = playbook } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(playbook.title).font(.headline)
                                Text("\(playbook.openers.count) openers · \(playbook.objectionCards.count) objections · \(playbook.discoveryQuestions.count) questions")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        indexSet.map { model.playbooks[$0].id }.forEach(model.deletePlaybook)
                    }
                }
            }
        }
        .navigationTitle("Playbooks")
        .toolbar {
            Button { creatingNew = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $creatingNew) { PlaybookEditorView(existing: nil) }
        .sheet(item: $editing) { PlaybookEditorView(existing: $0) }
    }
}
