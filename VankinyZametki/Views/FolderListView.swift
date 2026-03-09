import SwiftUI

struct FolderListView: View {
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var noteStore: NoteStore
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var selectedFolder: Folder?
    @State private var editingFolder: Folder?
    @State private var editFolderName = ""
    @State private var searchText = ""

    private var filteredFolders: [Folder] {
        if searchText.isEmpty { return folderStore.folders }
        return folderStore.folders.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            countBar

            if folderStore.isLoading && folderStore.folders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folderStore.folders.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Нет папок")
                        .font(.subheadline.weight(.medium))
                    Text("Нажми + чтобы создать")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                foldersList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .alert("Новая папка", isPresented: $showingNewFolder) {
            TextField("Название", text: $newFolderName)
            Button("Создать") {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                Task { _ = await folderStore.createFolder(name: name); newFolderName = "" }
            }
            Button("Отмена", role: .cancel) { newFolderName = "" }
        }
        .alert("Переименовать", isPresented: Binding(
            get: { editingFolder != nil },
            set: { if !$0 { editingFolder = nil } }
        )) {
            TextField("Название", text: $editFolderName)
            Button("Сохранить") {
                guard var f = editingFolder else { return }
                let name = editFolderName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                f.name = name
                Task { await folderStore.updateFolder(f) }
                editingFolder = nil
            }
            Button("Отмена", role: .cancel) { editingFolder = nil }
        }
        .sheet(item: $selectedFolder) { folder in
            NavigationStack {
                FolderDetailView(folder: folder)
            }
            .presentationDragIndicator(.visible)
        }
        .task {
            if folderStore.folders.isEmpty { await folderStore.loadFolders() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Папки")
                .font(.title2.bold())
            Spacer()
            Button { showingNewFolder = true } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Search (Evernote style — outline border, icon on right)

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Поиск папок", text: $searchText)
                .font(.subheadline)
            if searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Count

    private var countBar: some View {
        Group {
            if !folderStore.folders.isEmpty {
                Text(folderCountText.uppercased())
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
    }

    private var folderCountText: String {
        let c = folderStore.folders.count
        let m10 = c % 10; let m100 = c % 100
        let w: String
        if m10 == 1 && m100 != 11 { w = "папка" }
        else if m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20) { w = "папки" }
        else { w = "папок" }
        return "\(c) \(w)"
    }

    // MARK: - List

    private var foldersList: some View {
        List {
            ForEach(filteredFolders) { folder in
                Button { selectedFolder = folder } label: {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text(folder.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(folder.noteCount)")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.quaternary)
                    }
                }
                .contextMenu {
                    Button {
                        editFolderName = folder.name
                        editingFolder = folder
                    } label: {
                        Label("Переименовать", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        Task { await folderStore.deleteFolder(folder) }
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                let folders = filteredFolders
                for f in offsets.map({ folders[$0] }) {
                    Task { await folderStore.deleteFolder(f) }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await folderStore.loadFolders() }
    }
}

// MARK: - Folder Detail

struct FolderDetailView: View {
    let folder: Folder
    @EnvironmentObject private var noteStore: NoteStore
    @State private var showingNewNote = false
    @State private var selectedNote: Note?

    var body: some View {
        Group {
            if noteStore.isLoading && noteStore.notes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if noteStore.notes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Папка пуста")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(noteStore.notes) { note in
                        NoteRowView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedNote = note }
                    }
                    .onDelete { offsets in
                        for note in offsets.map({ noteStore.notes[$0] }) {
                            Task { await noteStore.deleteNote(note) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(folder.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewNote = true } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NavigationStack { NoteEditorView(note: .new(folderId: folder.id)) }
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack { NoteEditorView(note: note) }
                .presentationDragIndicator(.visible)
        }
        .task { await noteStore.loadNotes(inFolder: folder.id) }
    }
}
