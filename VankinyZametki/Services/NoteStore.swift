import Foundation
import SwiftUI

@MainActor
final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""

    private let api = APIService.shared

    var filteredNotes: [Note] {
        guard !searchQuery.isEmpty else { return notes }
        let q = searchQuery.lowercased()
        return notes.filter {
            $0.title.lowercased().contains(q) ||
            $0.snippet.lowercased().contains(q)
        }
    }

    func loadNotes() async {
        isLoading = true
        errorMessage = nil
        do {
            notes = try await api.fetchNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadNotes(inFolder folderId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            notes = try await api.fetchNotes(inFolder: folderId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createNote(title: String = "", content: String = "", folderId: UUID? = nil, sortOrder: Int = 0) async -> Note? {
        do {
            let created = try await api.createNote(title: title, content: content, folderId: folderId, sortOrder: sortOrder)
            notes.insert(created, at: 0)
            return created
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func loadChapters(bookId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            notes = try await api.fetchChapters(bookId: bookId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reorderNotes(_ items: [APIService.ReorderItem]) async {
        do {
            try await api.reorderNotes(items: items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNote(_ note: Note) async {
        do {
            let updated = try await api.updateNote(note)
            if let idx = notes.firstIndex(where: { $0.id == updated.id }) {
                notes[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteNote(_ note: Note) async {
        do {
            try await api.deleteNote(id: note.id)
            notes.removeAll { $0.id == note.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            await loadNotes()
            return
        }
        isLoading = true
        do {
            notes = try await api.searchNotes(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
