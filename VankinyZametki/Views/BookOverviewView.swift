import SwiftUI

struct BookOverviewView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var folderStore: FolderStore
    @Environment(\.dismiss) private var dismiss

    let book: Folder

    @State private var stats: APIService.BookStats?
    @State private var showSettings = false
    @State private var showNewChapter = false
    @State private var selectedChapter: Note?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                bookHeader
                statsSection
                Divider().padding(.horizontal, 16)
                chapterSection
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                }
            }
            ToolbarItem(placement: .principal) {
                Text(book.name)
                    .font(.headline)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showSettings = true } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 15))
                }
                Button { showNewChapter = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15))
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { BookSettingsView(book: book) }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNewChapter) {
            NavigationStack {
                NoteEditorView(note: .new(folderId: book.id))
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedChapter) { chapter in
            NavigationStack {
                NoteEditorView(
                    note: chapter,
                    bookContext: BookContext(
                        bookId: book.id,
                        chapters: noteStore.notes,
                        currentIndex: noteStore.notes.firstIndex(where: { $0.id == chapter.id }) ?? 0
                    )
                )
            }
            .presentationDragIndicator(.visible)
        }
        .task {
            await noteStore.loadChapters(bookId: book.id)
            stats = try? await APIService.shared.fetchBookStats(bookId: book.id)
        }
    }

    // MARK: - Header

    private var bookHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            if !book.genre.isEmpty {
                Text(book.genre.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }

            if !book.description.isEmpty {
                Text(book.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 12) {
            if let s = stats {
                HStack(spacing: 16) {
                    statPill(value: "\(s.totalWords)", label: "слов")
                    statPill(value: "\(s.chapterCount)", label: "глав")
                    statPill(value: "\(s.completedChapters)", label: "готово")
                }

                if let target = book.targetWordCount, target > 0 {
                    VStack(spacing: 4) {
                        ProgressView(value: min(Double(s.totalWords) / Double(target), 1.0))
                            .tint(s.totalWords >= target ? .green : .accentColor)
                        Text("\(s.totalWords) / \(target) слов")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 16)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Chapters

    private var chapterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Главы")
                    .font(.headline)
                Spacer()
                Text("\(noteStore.notes.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if noteStore.notes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("Нет глав")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Создать первую главу") { showNewChapter = true }
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(Array(noteStore.notes.enumerated()), id: \.element.id) { idx, chapter in
                    Button { selectedChapter = chapter } label: {
                        chapterRow(chapter, index: idx + 1)
                    }
                }
            }
        }
        .padding(.bottom, 32)
    }

    private func chapterRow(_ chapter: Note, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color(.tertiarySystemBackground), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(chapter.displayTitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    statusBadge(chapter.status)
                }
                if !chapter.synopsis.isEmpty {
                    Text(chapter.synopsis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(chapter.wordCount) сл.")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func statusBadge(_ status: ChapterStatus) -> some View {
        HStack(spacing: 2) {
            Image(systemName: status.icon)
                .font(.system(size: 8))
            Text(status.displayName)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(statusColor(status))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor(status).opacity(0.12), in: Capsule())
    }

    private func statusColor(_ status: ChapterStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .inProgress: return .blue
        case .revised: return .orange
        case .final_: return .green
        }
    }
}

// MARK: - Book Settings

struct BookSettingsView: View {
    @EnvironmentObject private var folderStore: FolderStore
    @Environment(\.dismiss) private var dismiss
    @State private var book: Folder
    @State private var name: String
    @State private var bookDescription: String
    @State private var genre: String
    @State private var targetWords: String

    init(book: Folder) {
        _book = State(initialValue: book)
        _name = State(initialValue: book.name)
        _bookDescription = State(initialValue: book.description)
        _genre = State(initialValue: book.genre)
        _targetWords = State(initialValue: book.targetWordCount.map { String($0) } ?? "")
    }

    var body: some View {
        Form {
            Section("Основное") {
                TextField("Название книги", text: $name)
                TextField("Жанр", text: $genre)
            }
            Section("Описание") {
                TextField("Краткое описание", text: $bookDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            Section("Цель") {
                TextField("Целевое количество слов", text: $targetWords)
                    .keyboardType(.numberPad)
            }
        }
        .navigationTitle("Настройки книги")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    book.name = name
                    book.description = bookDescription
                    book.genre = genre
                    book.targetWordCount = Int(targetWords)
                    Task {
                        await folderStore.updateFolder(book)
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

struct BookContext {
    let bookId: UUID
    let chapters: [Note]
    let currentIndex: Int
}
