import SwiftUI

struct MacDistractionFreeView: View {
    @EnvironmentObject private var noteStore: NoteStore

    @State private var note: Note
    @State private var htmlContent: String
    @State private var title: String
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?

    @Binding var isPresented: Bool

    init(note: Note, isPresented: Binding<Bool>) {
        _note = State(initialValue: note)
        _htmlContent = State(initialValue: note.content)
        _title = State(initialValue: note.title)
        _isPresented = isPresented
    }

    var body: some View {
        ZStack {
            Color(.textBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                hoverToolbar

                ScrollView {
                    VStack(spacing: 0) {
                        TextField("Заголовок", text: $title)
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 60)
                            .padding(.bottom, 12)
                            .onChange(of: title) { _, _ in scheduleAutoSave() }

                        MacRichTextEditor(
                            htmlContent: $htmlContent,
                            onTextChange: { scheduleAutoSave() }
                        )
                        .frame(maxWidth: 700)
                        .frame(minHeight: 500)
                        .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: 740)
                    .frame(maxWidth: .infinity)
                }

                wordCountFooter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hoverToolbar: some View {
        HStack {
            Spacer()
            Button {
                saveTask?.cancel()
                Task {
                    await saveNote()
                    isPresented = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.left.and.arrow.up.right")
                        .font(.system(size: 12))
                    Text("Выйти")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .opacity(0.5)
    }

    private var wordCountFooter: some View {
        HStack {
            Spacer()
            Text("\(computeWordCount()) слов")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func computeWordCount() -> Int {
        htmlContent
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
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
        note.wordCount = computeWordCount()
        note.updatedAt = Date()
        await noteStore.updateNote(note)
    }
}
