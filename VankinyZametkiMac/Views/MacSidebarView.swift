import SwiftUI

enum SidebarSelection: Hashable {
    case allNotes
    case folder(UUID)
    case tag(UUID)
}

struct MacSidebarView: View {
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var tagStore: TagStore
    @Binding var selection: SidebarSelection?

    @State private var showNewFolder = false
    @State private var showNewBook = false
    @State private var showNewTag = false
    @State private var newFolderName = ""
    @State private var newBookName = ""
    @State private var newTagName = ""
    @State private var newTagColor: TagColor = .blue
    @State private var renamingFolder: Folder?
    @State private var renameText = ""

    var body: some View {
        List(selection: $selection) {
            Section {
                Label {
                    Text("Все заметки")
                } icon: {
                    Image(systemName: "note.text")
                        .foregroundStyle(Color.accentColor)
                }
                .badge(noteStore.notes.count)
                .tag(SidebarSelection.allNotes)
            } header: {
                Text("Заметки")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            if !folderStore.books.isEmpty {
                Section {
                    ForEach(folderStore.books) { book in
                        Label {
                            Text(book.name)
                        } icon: {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .badge(book.noteCount)
                        .tag(SidebarSelection.folder(book.id))
                        .contextMenu {
                            Button("Переименовать") {
                                renamingFolder = book
                                renameText = book.name
                            }
                            Divider()
                            Button("Удалить", role: .destructive) {
                                Task { await folderStore.deleteFolder(book) }
                            }
                        }
                    }
                } header: {
                    Text("Книги")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }

            if !folderStore.regularFolders.isEmpty {
                Section {
                    ForEach(folderStore.regularFolders) { folder in
                        Label {
                            if renamingFolder?.id == folder.id {
                                TextField("Имя", text: $renameText, onCommit: {
                                    commitRename(folder)
                                })
                                .textFieldStyle(.plain)
                            } else {
                                Text(folder.name)
                            }
                        } icon: {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.brown)
                        }
                        .badge(folder.noteCount)
                        .tag(SidebarSelection.folder(folder.id))
                        .contextMenu {
                            Button("Переименовать") {
                                renamingFolder = folder
                                renameText = folder.name
                            }
                            Divider()
                            Button("Удалить", role: .destructive) {
                                Task { await folderStore.deleteFolder(folder) }
                            }
                        }
                    }
                } header: {
                    Text("Папки")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }

            if !tagStore.tags.isEmpty {
                Section {
                    ForEach(tagStore.tags) { tag in
                        Label {
                            Text(tag.name)
                        } icon: {
                            Circle()
                                .fill(tag.swiftUIColor)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(tag.swiftUIColor.opacity(0.3), lineWidth: 2))
                        }
                        .tag(SidebarSelection.tag(tag.id))
                        .contextMenu {
                            Button("Удалить", role: .destructive) {
                                Task { await tagStore.deleteTag(tag) }
                            }
                        }
                    }
                } header: {
                    Text("Теги")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 170, ideal: 220, max: 280)
        .toolbar {
            ToolbarItem {
                Menu {
                    Button {
                        showNewFolder = true
                    } label: {
                        Label("Новая папка", systemImage: "folder.badge.plus")
                    }
                    Button {
                        showNewBook = true
                    } label: {
                        Label("Новая книга", systemImage: "book.closed.fill")
                    }
                    Divider()
                    Button {
                        showNewTag = true
                    } label: {
                        Label("Новый тег", systemImage: "tag.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Новая папка", isPresented: $showNewFolder) {
            TextField("Название", text: $newFolderName)
            Button("Создать") {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                newFolderName = ""
                guard !name.isEmpty else { return }
                Task {
                    _ = try? await APIService.shared.createFolder(
                        name: name, parentId: nil
                    )
                    await folderStore.loadFolders()
                }
            }
            Button("Отмена", role: .cancel) { newFolderName = "" }
        }
        .alert("Новая книга", isPresented: $showNewBook) {
            TextField("Название книги", text: $newBookName)
            Button("Создать") {
                let name = newBookName.trimmingCharacters(in: .whitespaces)
                newBookName = ""
                guard !name.isEmpty else { return }
                Task {
                    _ = try? await APIService.shared.createFolder(
                        name: name, parentId: nil, type: .book
                    )
                    await folderStore.loadFolders()
                }
            }
            Button("Отмена", role: .cancel) { newBookName = "" }
        }
        .sheet(isPresented: $showNewTag) {
            MacNewTagView { name, color in
                Task {
                    _ = await tagStore.createTag(name: name, color: color.rawValue)
                }
            }
        }
    }

    private func commitRename(_ folder: Folder) {
        guard !renameText.isEmpty else { renamingFolder = nil; return }
        var updated = folder
        updated.name = renameText
        Task {
            _ = try? await APIService.shared.updateFolder(updated)
            await folderStore.loadFolders()
        }
        renamingFolder = nil
    }
}
