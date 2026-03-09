import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var folderStore: FolderStore
    @Environment(\.dismiss) private var dismiss

    @State private var note: Note
    @State private var title: String
    @State private var htmlContent: String
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isNewNote: Bool
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showSaved = false
    @State private var showFolderPicker = false
    @State private var showDeleteConfirm = false

    init(note: Note) {
        _note = State(initialValue: note)
        _title = State(initialValue: note.title)
        _htmlContent = State(initialValue: note.content)
        _isNewNote = State(initialValue: note.createdAt == note.updatedAt && note.content.isEmpty && note.title.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            folderBar
            titleField

            if note.isVoiceNote, let audioUrl = note.audioUrl {
                AudioPlayerView(urlString: audioUrl)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Divider()
                .padding(.horizontal, 16)

            RichTextEditor(
                htmlContent: $htmlContent,
                selectedRange: $selectedRange,
                onTextChange: { scheduleAutoSave() }
            )
        }
        .safeAreaInset(edge: .bottom) {
            FormattingToolbar { action in
                findTextView()?.applyFormat(action)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    saveTask?.cancel()
                    Task {
                        await saveNote()
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.primary)
            }

            ToolbarItem(placement: .principal) {
                Group {
                    if showSaved {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                            Text("Сохранено")
                                .font(.caption)
                        }
                        .foregroundStyle(.green)
                        .transition(.opacity)
                    } else if isSaving {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: showSaved)
                .animation(.easeInOut(duration: 0.25), value: isSaving)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15))
                }

                moreMenu
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerSheet(selectedFolderId: $note.folderId)
        }
        .alert("Удалить заметку?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                Task {
                    await noteStore.deleteNote(note)
                    dismiss()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить")
        }
        .task {
            if folderStore.folders.isEmpty {
                await folderStore.loadFolders()
            }
        }
        .onChange(of: note.folderId) { _, _ in
            scheduleAutoSave()
        }
    }

    // MARK: - Folder bar

    private var folderBar: some View {
        Button { showFolderPicker = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                Text(folderName)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var folderName: String {
        if let fid = note.folderId,
           let folder = folderStore.folders.first(where: { $0.id == fid }) {
            return folder.name
        }
        return "Без папки"
    }

    // MARK: - Title

    private var titleField: some View {
        TextField("Заголовок", text: $title)
            .font(.title2.bold())
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .onChange(of: title) { _, _ in
                scheduleAutoSave()
            }
    }

    // MARK: - More menu

    private var moreMenu: some View {
        Menu {
            Button {
                showFolderPicker = true
            } label: {
                Label("Переместить в папку", systemImage: "folder")
            }

            Button {
                Task { await duplicateNote() }
            } label: {
                Label("Дублировать", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15))
        }
    }

    // MARK: - Share text

    private var shareText: String {
        let t = title.isEmpty ? "" : title + "\n\n"
        let body = htmlContent
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return t + body
    }

    // MARK: - Duplicate

    private func duplicateNote() async {
        let newNote = await noteStore.createNote(
            title: title.isEmpty ? "" : title + " (копия)",
            content: htmlContent,
            folderId: note.folderId
        )
        if newNote != nil {
            dismiss()
        }
    }

    // MARK: - Auto-save

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await saveNote()
            showSaved = true
            try? await Task.sleep(for: .seconds(1.5))
            showSaved = false
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

// MARK: - Folder Picker

struct FolderPickerSheet: View {
    @EnvironmentObject private var folderStore: FolderStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFolderId: UUID?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedFolderId = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("Без папки")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedFolderId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                ForEach(folderStore.folders) { folder in
                    Button {
                        selectedFolderId = folder.id
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(folder.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedFolderId == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Выбрать папку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
