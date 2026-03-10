import SwiftUI

enum NoteSortOption: String, CaseIterable {
    case dateDesc = "Сначала новые"
    case dateAsc = "Сначала старые"
    case titleAsc = "А → Я"
    case titleDesc = "Я → А"
}

struct NoteListView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var tagStore: TagStore
    @State private var showingNewNote = false
    @State private var showingVoiceRecorder = false
    @State private var selectedNote: Note?
    @State private var sortOption: NoteSortOption = .dateDesc
    @State private var searchText = ""
    @State private var selectedTagId: UUID?

    private var filteredNotes: [Note] {
        var base = noteStore.notes

        if let tagId = selectedTagId {
            base = base.filter { note in
                note.tags.contains(where: { $0.id == tagId })
            }
        }

        if !searchText.isEmpty {
            base = base.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.snippet.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .dateDesc: return base.sorted { $0.createdAt > $1.createdAt }
        case .dateAsc: return base.sorted { $0.createdAt < $1.createdAt }
        case .titleAsc: return base.sorted { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedAscending }
        case .titleDesc: return base.sorted { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedDescending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            tagFilterBar
            noteCountBar

            if noteStore.isLoading && noteStore.notes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotes.isEmpty && !searchText.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("Ничего не найдено")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if noteStore.notes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Нет заметок")
                        .font(.subheadline.weight(.medium))
                    Text("Нажми \u{270F}\u{FE0F} или \u{1F3A4} вверху")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                notesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $showingNewNote) {
            NavigationStack { NoteEditorView(note: .new()) }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            NavigationStack { VoiceRecorderView() }
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack { NoteEditorView(note: note) }
                .presentationDragIndicator(.visible)
        }
        .task {
            if noteStore.notes.isEmpty {
                await noteStore.loadNotes()
            }
            if folderStore.folders.isEmpty {
                await folderStore.loadFolders()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Заметки")
                .font(.system(size: 22, weight: .bold))

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if !noteStore.notes.isEmpty {
                    Menu {
                        Picker("Сортировка", selection: $sortOption) {
                            ForEach(NoteSortOption.allCases, id: \.self) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                }

                Button { showingVoiceRecorder = true } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }

                Button { showingNewNote = true } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor, in: Circle())
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.xs)
    }

    // MARK: - Search (Evernote style — outline border, icon on right)

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Поиск по заметкам", text: $searchText)
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

    // MARK: - Tag Filter

    @ViewBuilder
    private var tagFilterBar: some View {
        if !tagStore.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    tagFilterChip(label: "Все", color: .accentColor, isSelected: selectedTagId == nil) {
                        withAnimation(.easeOut(duration: 0.2)) { selectedTagId = nil }
                    }

                    ForEach(tagStore.tags) { tag in
                        tagFilterChip(label: tag.name, color: tag.swiftUIColor, isSelected: selectedTagId == tag.id) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedTagId = selectedTagId == tag.id ? nil : tag.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 6)
        }
    }

    private func tagFilterChip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.15) : Color(.tertiarySystemFill))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.4) : .clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Count

    private var noteCountBar: some View {
        Group {
            if !noteStore.notes.isEmpty {
                Text(noteCountText.uppercased())
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - List

    private func accentColor(for note: Note) -> Color {
        if let fid = note.folderId {
            if let folder = folderStore.folders.first(where: { $0.id == fid }) {
                return folder.isBook ? .orange : .blue
            }
        }
        if note.isVoiceNote { return .orange }
        if let first = note.tags.first { return first.swiftUIColor }
        return .gray.opacity(0.5)
    }

    private var notesList: some View {
        List {
            ForEach(filteredNotes) { note in
                NoteRowView(note: note, accent: accentColor(for: note))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNote = note }
            }
            .onDelete { offsets in
                let notes = filteredNotes
                for note in offsets.map({ notes[$0] }) {
                    Task { await noteStore.deleteNote(note) }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await noteStore.loadNotes() }
    }

    // MARK: - Helpers

    private var noteCountText: String {
        let c = filteredNotes.count
        let m10 = c % 10
        let m100 = c % 100
        let w: String
        if m10 == 1 && m100 != 11 { w = "заметка" }
        else if m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20) { w = "заметки" }
        else { w = "заметок" }
        return "\(c) \(w)"
    }
}

// MARK: - Row

struct NoteRowView: View {
    let note: Note
    var accent: Color = .gray.opacity(0.5)

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(note.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    if note.isVoiceNote {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }

                    Spacer(minLength: 0)
                }

                if !note.snippet.isEmpty {
                    Text(note.snippet)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(note.formattedDate)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.quaternary)

                    if !note.tags.isEmpty {
                        ForEach(note.tags.prefix(2)) { tag in
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(tag.swiftUIColor)
                                    .frame(width: 5, height: 5)
                                Text(tag.name)
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.tertiary)
                        }
                        if note.tags.count > 2 {
                            Text("+\(note.tags.count - 2)")
                                .font(.system(size: 11))
                                .foregroundStyle(.quaternary)
                        }
                    }
                }
            }
            .padding(.leading, 10)
        }
        .padding(.vertical, 5)
        .background(accent.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Date

extension Note {
    var formattedDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(createdAt) {
            return Self.timeFmt.string(from: createdAt)
        } else if cal.isDateInYesterday(createdAt) {
            return "Вчера"
        } else if cal.isDate(createdAt, equalTo: Date(), toGranularity: .year) {
            return Self.shortFmt.string(from: createdAt)
        } else {
            return Self.fullFmt.string(from: createdAt)
        }
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "ru_RU"); return f
    }()
    private static let shortFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "ru_RU"); return f
    }()
    private static let fullFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; f.locale = Locale(identifier: "ru_RU"); return f
    }()
}
