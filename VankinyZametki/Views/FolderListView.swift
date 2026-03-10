import SwiftUI

struct FolderListView: View {
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var noteStore: NoteStore
    @State private var showingNewFolder = false
    @State private var showingNewBook = false
    @State private var newFolderName = ""
    @State private var newBookName = ""
    @State private var selectedFolder: Folder?
    @State private var selectedBook: Folder?
    @State private var editingFolder: Folder?
    @State private var editFolderName = ""
    @State private var searchText = ""

    private var filteredFolders: [Folder] {
        let folders = folderStore.regularFolders
        if searchText.isEmpty { return folders }
        return folders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredBooks: [Folder] {
        let books = folderStore.books
        if searchText.isEmpty { return books }
        return books.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar

            if folderStore.isLoading && folderStore.folders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folderStore.folders.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Нет папок и книг")
                        .font(.subheadline.weight(.medium))
                    Text("Нажми + чтобы создать")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainList
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
        .alert("Новая книга", isPresented: $showingNewBook) {
            TextField("Название книги", text: $newBookName)
            Button("Создать") {
                let name = newBookName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                Task { _ = await folderStore.createFolder(name: name, type: .book); newBookName = "" }
            }
            Button("Отмена", role: .cancel) { newBookName = "" }
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
        .sheet(item: $selectedBook) { book in
            NavigationStack {
                BookOverviewView(book: book)
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

            Menu {
                Button {
                    showingNewFolder = true
                } label: {
                    Label("Новая папка", systemImage: "folder.badge.plus")
                }
                Button {
                    showingNewBook = true
                } label: {
                    Label("Новая книга", systemImage: "book.closed.fill")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Поиск", text: $searchText)
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

    // MARK: - List

    private var mainList: some View {
        List {
            if !filteredBooks.isEmpty {
                Section {
                    ForEach(filteredBooks) { book in
                        Button { selectedBook = book } label: {
                            bookRow(book)
                        }
                        .contextMenu {
                            folderContextMenu(book)
                        }
                    }
                } header: {
                    Text("Книги".uppercased())
                        .font(.caption2.weight(.medium))
                }
            }

            if !filteredFolders.isEmpty {
                Section {
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
                            folderContextMenu(folder)
                        }
                    }
                    .onDelete { offsets in
                        let folders = filteredFolders
                        for f in offsets.map({ folders[$0] }) {
                            Task { await folderStore.deleteFolder(f) }
                        }
                    }
                } header: {
                    Text("Папки".uppercased())
                        .font(.caption2.weight(.medium))
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await folderStore.loadFolders() }
    }

    private func bookRow(_ book: Folder) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !book.genre.isEmpty {
                        Text(book.genre)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(book.noteCount) глав")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: Folder) -> some View {
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
