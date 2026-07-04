import SwiftUI
import ColdCoachCore

struct PlaybookEditorView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let existing: Playbook?
    @State private var offer: String
    @State private var notes: String
    @State private var draft: Playbook?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    init(existing: Playbook?) {
        self.existing = existing
        _offer = State(initialValue: existing?.offerSentence ?? "")
        _notes = State(initialValue: existing?.contextNotes ?? "")
        _draft = State(initialValue: existing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(existing == nil ? "New Playbook" : "Edit Playbook").font(.title2.bold())
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your offer, in one sentence").font(.headline)
                        TextField("e.g. We help mid-market SaaS teams book more demos with AI live-call coaching.", text: $offer, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Context (optional)").font(.headline)
                        TextEditor(text: $notes)
                            .frame(height: 90)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                    }

                    HStack {
                        Button {
                            generate()
                        } label: {
                            if isGenerating { ProgressView().controlSize(.small) }
                            else { Label(draft == nil ? "Generate playbook" : "Regenerate", systemImage: "sparkles") }
                        }
                        .disabled(offer.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
                        Spacer()
                    }

                    if let error = errorMessage {
                        Text(error).font(.callout).foregroundStyle(.red)
                    }

                    if let draft {
                        generatedContent(draft)
                    }
                }
                .padding()
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft == nil)
            }
            .padding()
        }
        .frame(width: 560, height: 640)
    }

    @ViewBuilder
    private func generatedContent(_ playbook: Playbook) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            section("Openers") {
                ForEach(playbook.openers) { opener in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(opener.signal.uppercased()).font(.caption2).foregroundStyle(.secondary)
                        Text(opener.text)
                    }
                }
            }
            section("Discovery questions") {
                ForEach(playbook.discoveryQuestions) { q in Text("• \(q.text)") }
            }
            section("Objection responses") {
                ForEach(playbook.objectionCards) { card in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.trigger).font(.subheadline.weight(.semibold))
                        Text(card.response).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private func generate() {
        guard let provider = model.makeProvider() else {
            errorMessage = "Add an API key in Settings first."
            return
        }
        errorMessage = nil
        isGenerating = true
        let offerText = offer
        let notesText = notes
        let modelName = model.settings.playbookModel
        Task {
            do {
                let generated = try await PlaybookService().generate(
                    offerSentence: offerText, contextNotes: notesText, using: provider, model: modelName
                )
                await MainActor.run {
                    self.draft = Playbook(
                        id: existing?.id ?? generated.id,
                        offerSentence: offerText,
                        contextNotes: notesText,
                        openers: generated.openers,
                        discoveryQuestions: generated.discoveryQuestions,
                        objectionCards: generated.objectionCards
                    )
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }

    private func save() {
        guard let draft else { return }
        let final = Playbook(
            id: draft.id,
            offerSentence: offer,
            contextNotes: notes,
            openers: draft.openers,
            discoveryQuestions: draft.discoveryQuestions,
            objectionCards: draft.objectionCards
        )
        model.upsertPlaybook(final)
        dismiss()
    }
}
