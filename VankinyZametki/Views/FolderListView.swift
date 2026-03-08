import SwiftUI

struct FolderListView: View {
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var noteStore: NoteStore
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var selectedFolder: Folder?

    var body: some View {
        Group {
            if folderStore.isLoading && folderStore.folders.isEmpty {
                ProgressView("Загрузка...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folderStore.folders.isEmpty {
                emptyState
            } else {
                foldersList
            }
        }
        .navigationTitle("Папки")
        .refreshable {
            await folderStore.loadFolders()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .alert("Новая папка", isPresented: $showingNewFolder) {
            TextField("Название папки", text: $newFolderName)
            Button("Создать") {
                guard !newFolderName.isEmpty else { return }
                Task {
                    _ = await folderStore.createFolder(name: newFolderName)
                    newFolderName = ""
                }
            }
            Button("Отмена", role: .cancel) {
                newFolderName = ""
            }
        }
        .navigationDestination(item: $selectedFolder) { folder in
            FolderDetailView(folder: folder)
        }
        .task {
            if folderStore.folders.isEmpty {
                await folderStore.loadFolders()
            }
        }
    }

    private var foldersList: some View {
        List {
            ForEach(folderStore.folders) { folder in
                Button {
                    selectedFolder = folder
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(folder.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await folderStore.deleteFolder(folder) }
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Нет папок")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Создай папки для организации заметок")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button {
                showingNewFolder = true
            } label: {
                Label("Создать папку", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct FolderDetailView: View {
    let folder: Folder
    @EnvironmentObject private var noteStore: NoteStore
    @State private var showingNewNote = false
    @State private var selectedNote: Note?

    var body: some View {
        Group {
            if noteStore.isLoading && noteStore.notes.isEmpty {
                ProgressView("Загрузка...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if noteStore.notes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Папка пуста")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Button {
                        showingNewNote = true
                    } label: {
                        Label("Новая заметка", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(noteStore.notes) { note in
                        NoteRowView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedNote = note }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await noteStore.deleteNote(note) }
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(folder.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewNote = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NavigationStack {
                NoteEditorView(note: .new(folderId: folder.id))
            }
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack {
                NoteEditorView(note: note)
            }
        }
        .task {
            await noteStore.loadNotes(inFolder: folder.id)
        }
    }
}
