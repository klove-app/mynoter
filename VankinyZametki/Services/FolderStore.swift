import Foundation
import SwiftUI

@MainActor
final class FolderStore: ObservableObject {
    @Published var folders: [Folder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    func loadFolders() async {
        isLoading = true
        errorMessage = nil
        do {
            folders = try await api.fetchFolders()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createFolder(name: String, parentId: UUID? = nil, type: FolderType = .folder,
                      description: String = "", targetWordCount: Int? = nil,
                      genre: String = "") async -> Folder? {
        do {
            let created = try await api.createFolder(
                name: name, parentId: parentId, type: type,
                description: description, targetWordCount: targetWordCount,
                genre: genre
            )
            folders.append(created)
            folders.sort { $0.name < $1.name }
            return created
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    var books: [Folder] { folders.filter { $0.isBook } }
    var regularFolders: [Folder] { folders.filter { !$0.isBook } }

    func updateFolder(_ folder: Folder) async {
        do {
            let updated = try await api.updateFolder(folder)
            if let idx = folders.firstIndex(where: { $0.id == updated.id }) {
                folders[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFolder(_ folder: Folder) async {
        do {
            try await api.deleteFolder(id: folder.id)
            folders.removeAll { $0.id == folder.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
