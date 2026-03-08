import SwiftUI

enum NoteSortOption: String, CaseIterable {
    case dateDesc = "Сначала новые"
    case dateAsc = "Сначала старые"
    case titleAsc = "По названию А-Я"
    case titleDesc = "По названию Я-А"
}

struct NoteListView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @State private var showingNewNote = false
    @State private var showingVoiceRecorder = false
    @State private var selectedNote: Note?
    @State private var sortOption: NoteSortOption = .dateDesc

    private var sortedNotes: [Note] {
        let notes = noteStore.filteredNotes
        switch sortOption {
        case .dateDesc: return notes.sorted { $0.createdAt > $1.createdAt }
        case .dateAsc: return notes.sorted { $0.createdAt < $1.createdAt }
        case .titleAsc: return notes.sorted { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedAscending }
        case .titleDesc: return notes.sorted { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedDescending }
        }
    }

    var body: some View {
        Group {
            if noteStore.isLoading && noteStore.notes.isEmpty {
                ProgressView("Загрузка...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if noteStore.filteredNotes.isEmpty && !noteStore.searchQuery.isEmpty {
                searchEmptyState
            } else if noteStore.filteredNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .navigationTitle("Заметки")
        .searchable(text: $noteStore.searchQuery, prompt: "Поиск по заметкам")
        .refreshable {
            await noteStore.loadNotes()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(NoteSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingNewNote = true
                    } label: {
                        Label("Текстовая заметка", systemImage: "square.and.pencil")
                    }
                    Button {
                        showingVoiceRecorder = true
                    } label: {
                        Label("Голосовая заметка", systemImage: "mic")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NavigationStack {
                NoteEditorView(note: .new())
            }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            NavigationStack {
                VoiceRecorderView()
            }
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack {
                NoteEditorView(note: note)
            }
        }
        .task {
            if noteStore.notes.isEmpty {
                await noteStore.loadNotes()
            }
        }
    }

    private var notesList: some View {
        List {
            ForEach(sortedNotes) { note in
                NoteRowView(note: note)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNote = note
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await noteStore.deleteNote(note) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            // TODO: folder picker
                        } label: {
                            Label("В папку", systemImage: "folder")
                        }
                        .tint(.accentColor)
                    }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: sortOption)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ничего не найдено")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Попробуй другой запрос")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Пока нет заметок")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Создай первую текстовую или голосовую заметку")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    showingNewNote = true
                } label: {
                    Label("Текст", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingVoiceRecorder = true
                } label: {
                    Label("Голос", systemImage: "mic")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                if note.isVoiceNote {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundStyle(.accentColor)
                }
                Spacer()
            }

            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(note.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
