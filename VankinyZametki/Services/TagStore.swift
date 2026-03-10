import Foundation
import SwiftUI

@MainActor
final class TagStore: ObservableObject {
    @Published var tags: [Tag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    func loadTags() async {
        isLoading = true
        errorMessage = nil
        do {
            tags = try await api.fetchTags()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createTag(name: String, color: String) async -> Tag? {
        do {
            let tag = try await api.createTag(name: name, color: color)
            tags.append(tag)
            tags.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            return tag
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updateTag(_ tag: Tag) async {
        do {
            let updated = try await api.updateTag(tag)
            if let idx = tags.firstIndex(where: { $0.id == updated.id }) {
                tags[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTag(_ tag: Tag) async {
        do {
            try await api.deleteTag(id: tag.id)
            tags.removeAll { $0.id == tag.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTag(_ tagId: UUID, toNote noteId: UUID) async -> [Tag] {
        do {
            return try await api.addTagToNote(tagId: tagId, noteId: noteId)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func removeTag(_ tagId: UUID, fromNote noteId: UUID) async -> [Tag] {
        do {
            return try await api.removeTagFromNote(tagId: tagId, noteId: noteId)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func fetchNotesForTag(_ tagId: UUID) async -> [Note] {
        do {
            return try await api.fetchNotesForTag(tagId: tagId)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}
