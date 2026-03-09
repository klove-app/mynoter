import SwiftUI

enum NoteSortOption: String, CaseIterable {
    case dateDesc = "Сначала новые"
    case dateAsc = "Сначала старые"
    case titleAsc = "А → Я"
    case titleDesc = "Я → А"
}

struct NoteListView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @State private var showingNewNote = false
    @State private var showingVoiceRecorder = false
    @State private var selectedNote: Note?
    @State private var sortOption: NoteSortOption = .dateDesc
    @State private var searchText = ""

    private var filteredNotes: [Note] {
        let base = searchText.isEmpty ? noteStore.notes : noteStore.notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.snippet.localizedCaseInsensitiveContains(searchText)
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
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Заметки")
                .font(.title2.bold())

            Spacer()

            if !noteStore.notes.isEmpty {
                Menu {
                    Picker("Сортировка", selection: $sortOption) {
                        ForEach(NoteSortOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }

            Button { showingVoiceRecorder = true } label: {
                Image(systemName: "mic")
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }

            Button { showingNewNote = true } label: {
                Image(systemName: "square.and.pencil")
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

    private var notesList: some View {
        List {
            ForEach(filteredNotes) { note in
                NoteRowView(note: note)
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
        let c = noteStore.notes.count
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.displayTitle)
                .font(.body.weight(.semibold))
                .lineLimit(1)

            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 4) {
                Text(note.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if note.isVoiceNote {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 2)
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
