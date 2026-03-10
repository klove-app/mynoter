import SwiftUI

struct MacChapterListView: View {
    @EnvironmentObject private var noteStore: NoteStore
    let book: Folder
    @Binding var selectedNoteId: UUID?

    @State private var stats: APIService.BookStats?

    private var chapters: [Note] {
        noteStore.notes
            .filter { $0.folderId == book.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            bookStatsHeader

            Divider()

            if chapters.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("Нет глав")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await addChapter() }
                    } label: {
                        Label("Добавить главу", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedNoteId) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { idx, chapter in
                        chapterRow(idx: idx, chapter: chapter)
                            .tag(chapter.id)
                    }
                    .onMove { from, to in
                        var reordered = chapters
                        reordered.move(fromOffsets: from, toOffset: to)
                        for (i, ch) in reordered.enumerated() {
                            if let noteIdx = noteStore.notes.firstIndex(where: { $0.id == ch.id }) {
                                noteStore.notes[noteIdx].sortOrder = i
                            }
                        }
                        Task { await saveOrder(reordered) }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 500)
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await addChapter() }
                } label: {
                    Image(systemName: "plus")
                }
                .help("Новая глава")
            }
        }
        .task {
            await noteStore.loadChapters(bookId: book.id)
            stats = try? await APIService.shared.fetchBookStats(bookId: book.id)
        }
        .onChange(of: book.id) { _, newId in
            Task {
                await noteStore.loadChapters(bookId: newId)
                stats = try? await APIService.shared.fetchBookStats(bookId: newId)
            }
        }
    }

    // MARK: - Book Header

    private var bookStatsHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.name)
                .font(.headline)
                .lineLimit(2)

            if let s = stats {
                HStack(spacing: 10) {
                    statLabel(value: s.chapterCount, unit: "глав")
                    statLabel(value: s.totalWords, unit: "слов")
                    if s.completedChapters > 0 {
                        statLabel(value: s.completedChapters, unit: "готово", tint: .green)
                    }
                    if let target = book.targetWordCount, target > 0 {
                        Spacer()
                        let pct = min(Double(s.totalWords) / Double(target), 1.0)
                        Text("\(Int(pct * 100))%")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(pct >= 1.0 ? .green : Color.accentColor)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func statLabel(value: Int, unit: String, tint: Color = .secondary) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Chapter Row

    private func chapterRow(idx: Int, chapter: Note) -> some View {
        HStack(spacing: 8) {
            Text("\(idx + 1)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 22, alignment: .trailing)

            statusDot(chapter.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !chapter.synopsis.isEmpty {
                        Text(chapter.synopsis)
                            .font(.caption.italic())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if chapter.wordCount > 0 {
                        Text("\(chapter.wordCount) сл.")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .help(chapter.status.displayName)
    }

    private func statusDot(_ status: ChapterStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 8, height: 8)
    }

    private func statusColor(_ status: ChapterStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .inProgress: return .blue
        case .revised: return .orange
        case .final_: return .green
        }
    }

    // MARK: - Actions

    private func addChapter() async {
        let nextOrder = (chapters.last?.sortOrder ?? 0) + 1
        let note = await noteStore.createNote(
            title: "Глава \(chapters.count + 1)",
            folderId: book.id,
            sortOrder: nextOrder
        )
        if let note {
            selectedNoteId = note.id
        }
    }

    private func saveOrder(_ chapters: [Note]) async {
        let items = chapters.enumerated().map { idx, ch in
            APIService.ReorderItem(id: ch.id, sort_order: idx)
        }
        await noteStore.reorderNotes(items)
    }
}
