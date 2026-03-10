import SwiftUI

struct MacContentView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var tagStore: TagStore

    @State private var sidebarSelection: SidebarSelection? = .allNotes
    @State private var selectedNoteId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showVoiceRecorder = false
    @State private var isDistractionFree = false

    private var selectedFolderId: UUID? {
        if case .folder(let id) = sidebarSelection { return id }
        return nil
    }

    private var selectedFolder: Folder? {
        guard let id = selectedFolderId else { return nil }
        return folderStore.folders.first(where: { $0.id == id })
    }

    private var selectedNote: Note? {
        guard let id = selectedNoteId else { return nil }
        return noteStore.notes.first(where: { $0.id == id })
    }

    var body: some View {
        if isDistractionFree, let note = selectedNote {
            MacDistractionFreeView(
                note: note,
                isPresented: $isDistractionFree
            )
        } else {
            mainLayout
        }
    }

    private var mainLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MacSidebarView(selection: $sidebarSelection)
        } content: {
            if case .tag = sidebarSelection {
                MacNoteListView(
                    selectedFolderId: nil,
                    selectedNoteId: $selectedNoteId
                )
            } else if let folder = selectedFolder, folder.isBook {
                MacChapterListView(
                    book: folder,
                    selectedNoteId: $selectedNoteId
                )
            } else {
                MacNoteListView(
                    selectedFolderId: selectedFolderId,
                    selectedNoteId: $selectedNoteId
                )
            }
        } detail: {
            if let note = selectedNote {
                if let folder = selectedFolder, folder.isBook {
                    let bookChapters = noteStore.notes
                        .filter { $0.folderId == folder.id }
                        .sorted { $0.sortOrder < $1.sortOrder }
                    MacNoteEditorView(
                        note: note,
                        bookContext: MacBookContext(
                            bookId: folder.id,
                            bookName: folder.name,
                            chapters: bookChapters,
                            currentIndex: bookChapters.firstIndex(where: { $0.id == note.id }) ?? 0
                        )
                    )
                    .id(note.id)
                } else {
                    MacNoteEditorView(note: note)
                        .id(note.id)
                }
            } else {
                let isBook = selectedFolder?.isBook == true
                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: isBook ? "book.closed" : "note.text")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    VStack(spacing: DS.Spacing.xs) {
                        Text(isBook ? "Выбери главу для редактирования" : "Выбери заметку")
                            .font(.ds.titleSmall)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 6) {
                        shortcutHint("⌘N", label: "Новая заметка")
                        shortcutHint("⇧⌘N", label: "Голосовая заметка")
                        shortcutHint("⇧⌘F", label: "Режим фокуса")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .navigationTitle(selectedNote?.displayTitle ?? "Ванькины Заметки")
        .navigationSubtitle(selectedFolder?.name ?? "")
        .sheet(isPresented: $showVoiceRecorder) {
            MacVoiceRecorderView()
                .frame(width: 440, height: 400)
        }
        .task {
            await folderStore.loadFolders()
            await noteStore.loadNotes()
            await tagStore.loadTags()
        }
        .animation(.easeInOut(duration: 0.2), value: selectedNoteId)
        .onChange(of: sidebarSelection) { _, newSelection in
            withAnimation(.easeOut(duration: 0.15)) { selectedNoteId = nil }
            Task {
                switch newSelection {
                case .allNotes:
                    await noteStore.loadNotes()
                case .folder(let folderId):
                    if let folder = folderStore.folders.first(where: { $0.id == folderId }) {
                        if folder.isBook {
                            await noteStore.loadChapters(bookId: folder.id)
                        } else {
                            await noteStore.loadNotes(inFolder: folder.id)
                        }
                    } else {
                        await noteStore.loadNotes()
                    }
                case .tag(let tagId):
                    let notes = await tagStore.fetchNotesForTag(tagId)
                    noteStore.notes = notes
                case nil:
                    await noteStore.loadNotes()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in
            Task { await createNewNote() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newVoiceNote)) { _ in
            showVoiceRecorder = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleDistractionFree)) { _ in
            if selectedNoteId != nil {
                isDistractionFree.toggle()
            }
        }
    }

    private func shortcutHint(_ shortcut: String, label: String) -> some View {
        HStack(spacing: 8) {
            Text(shortcut)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func createNewNote() async {
        let folderId: UUID? = if let folder = selectedFolder, !folder.isBook {
            folder.id
        } else {
            nil
        }
        let note = await noteStore.createNote(
            title: "",
            content: "",
            folderId: folderId
        )
        if let note {
            selectedNoteId = note.id
        }
    }
}

struct MacBookContext {
    let bookId: UUID
    let bookName: String
    let chapters: [Note]
    let currentIndex: Int
}
