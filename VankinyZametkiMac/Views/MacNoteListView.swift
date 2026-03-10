import SwiftUI

struct MacNoteListView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var folderStore: FolderStore
    let selectedFolderId: UUID?
    @Binding var selectedNoteId: UUID?

    @State private var searchText = ""
    @State private var sortOption: MacSortOption = .dateDesc

    private var filteredNotes: [Note] {
        var notes = noteStore.notes
        if let fid = selectedFolderId {
            notes = notes.filter { $0.folderId == fid }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            notes = notes.filter {
                $0.title.lowercased().contains(q) ||
                $0.snippet.lowercased().contains(q)
            }
        }
        switch sortOption {
        case .dateDesc: return notes.sorted { $0.createdAt > $1.createdAt }
        case .dateAsc: return notes.sorted { $0.createdAt < $1.createdAt }
        case .titleAsc: return notes.sorted { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedAscending }
        }
    }

    var body: some View {
        if filteredNotes.isEmpty {
            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.quaternary)
                VStack(spacing: DS.Spacing.xs) {
                    Text(searchText.isEmpty ? "Нет заметок" : "Ничего не найдено")
                        .font(.ds.titleSmall)
                        .foregroundStyle(.secondary)
                    if searchText.isEmpty {
                        Text("⌘N — новая заметка")
                            .font(.ds.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        List(selection: $selectedNoteId) {
            ForEach(filteredNotes) { note in
                noteRow(note)
                    .tag(note.id)
                    .contextMenu { noteContextMenu(note) }
            }
        }
        .listStyle(.inset)
        .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 500)
        .searchable(text: $searchText, prompt: "Поиск по заметкам")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Сортировка", selection: $sortOption) {
                        ForEach(MacSortOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }

            ToolbarItem {
                Button {
                    NotificationCenter.default.post(name: .newNote, object: nil)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }

            ToolbarItem {
                Button {
                    NotificationCenter.default.post(name: .newVoiceNote, object: nil)
                } label: {
                    Image(systemName: "mic")
                }
            }
        }
    }

    // MARK: - Note Row

    @ViewBuilder
    private func noteRow(_ note: Note) -> some View {
        let accent = noteAccentColor(note)

        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(note.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    if note.isVoiceNote {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }

                    Spacer(minLength: 0)
                }

                if !note.snippet.isEmpty {
                    Text(note.snippet)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(note.formattedDateMac)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.quaternary)

                    if !note.tags.isEmpty {
                        ForEach(note.tags.prefix(2)) { tag in
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(tag.swiftUIColor)
                                    .frame(width: 5, height: 5)
                                Text(tag.name)
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(.tertiary)
                        }
                        if note.tags.count > 2 {
                            Text("+\(note.tags.count - 2)")
                                .font(.system(size: 10))
                                .foregroundStyle(.quaternary)
                        }
                    }

                    if selectedFolderId == nil, let fid = note.folderId,
                       let folder = folderStore.folders.first(where: { $0.id == fid }) {
                        HStack(spacing: 2) {
                            Image(systemName: folder.isBook ? "book.closed.fill" : "folder.fill")
                                .font(.system(size: 8))
                            Text(folder.name)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 5)
        .background(accent.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .bottom) {
            Color.ds.separator.opacity(0.1).frame(height: 0.5)
        }
    }

    private func noteAccentColor(_ note: Note) -> Color {
        if let fid = note.folderId,
           let folder = folderStore.folders.first(where: { $0.id == fid }) {
            if folder.isBook {
                return .orange
            }
            return .blue
        }
        if note.isVoiceNote {
            return .orange
        }
        if !note.tags.isEmpty, let first = note.tags.first {
            return first.swiftUIColor
        }
        return .gray.opacity(0.5)
    }

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        if !folderStore.regularFolders.isEmpty {
            Menu("Переместить в папку") {
                ForEach(folderStore.regularFolders) { folder in
                    Button(folder.name) {
                        Task { await moveNote(note, toFolder: folder.id) }
                    }
                }
                Divider()
                Button("Убрать из папки") {
                    Task { await moveNote(note, toFolder: nil) }
                }
            }
        }
        if !folderStore.books.isEmpty {
            Menu("Добавить в книгу") {
                ForEach(folderStore.books) { book in
                    Button(book.name) {
                        Task { await moveNote(note, toFolder: book.id) }
                    }
                }
            }
        }
        Divider()
        Button("Удалить", role: .destructive) {
            Task {
                if selectedNoteId == note.id { selectedNoteId = nil }
                await noteStore.deleteNote(note)
            }
        }
    }

    private func moveNote(_ note: Note, toFolder folderId: UUID?) async {
        var updated = note
        updated.folderId = folderId
        await noteStore.updateNote(updated)
        await folderStore.loadFolders()
    }
}

enum MacSortOption: String, CaseIterable {
    case dateDesc = "Сначала новые"
    case dateAsc = "Сначала старые"
    case titleAsc = "А → Я"
}

extension Note {
    var formattedDateMac: String {
        let cal = Calendar.current
        if cal.isDateInToday(createdAt) {
            return Self.timeFmtMac.string(from: createdAt)
        } else if cal.isDateInYesterday(createdAt) {
            return "Вчера"
        } else if cal.isDate(createdAt, equalTo: Date(), toGranularity: .year) {
            return Self.shortFmtMac.string(from: createdAt)
        } else {
            return Self.fullFmtMac.string(from: createdAt)
        }
    }

    private static let timeFmtMac: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "ru_RU"); return f
    }()
    private static let shortFmtMac: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "ru_RU"); return f
    }()
    private static let fullFmtMac: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; f.locale = Locale(identifier: "ru_RU"); return f
    }()
}
