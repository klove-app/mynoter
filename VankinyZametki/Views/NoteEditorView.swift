import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @Environment(\.dismiss) private var dismiss

    @State private var note: Note
    @State private var title: String
    @State private var htmlContent: String
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isNewNote: Bool
    @State private var isSaving = false
    @State private var textViewRef: UITextView?
    @State private var saveTask: Task<Void, Never>?

    init(note: Note) {
        _note = State(initialValue: note)
        _title = State(initialValue: note.title)
        _htmlContent = State(initialValue: note.content)
        _isNewNote = State(initialValue: note.createdAt == note.updatedAt && note.content.isEmpty && note.title.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            titleField

            if note.isVoiceNote, let audioUrl = note.audioUrl {
                AudioPlayerView(urlString: audioUrl)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            RichTextEditor(
                htmlContent: $htmlContent,
                selectedRange: $selectedRange,
                onTextChange: { scheduleAutoSave() }
            )
            .overlay(alignment: .bottom) {
                FormattingToolbar { action in
                    findTextView()?.applyFormat(action)
                }
            }
        }
        .navigationTitle(isNewNote ? "Новая заметка" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    saveTask?.cancel()
                    Task {
                        await saveNote()
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Сохранить") {
                        Task {
                            await saveNote()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var titleField: some View {
        TextField("Заголовок", text: $title)
            .font(.title2.bold())
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .onChange(of: title) { _, _ in
                scheduleAutoSave()
            }
    }

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await saveNote()
        }
    }

    private func saveNote() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        note.title = title
        note.content = htmlContent
        note.updatedAt = Date()

        if isNewNote {
            if let created = await noteStore.createNote(
                title: note.title,
                content: note.content,
                folderId: note.folderId
            ) {
                note = created
                isNewNote = false
            }
        } else {
            await noteStore.updateNote(note)
        }
    }

    private func findTextView() -> UITextView? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return nil }
        return findTextViewInView(window)
    }

    private func findTextViewInView(_ view: UIView) -> UITextView? {
        if let tv = view as? UITextView, tv.isEditable { return tv }
        for sub in view.subviews {
            if let found = findTextViewInView(sub) { return found }
        }
        return nil
    }
}
