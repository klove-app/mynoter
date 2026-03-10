import Foundation

enum FolderType: String, Codable, Equatable, Hashable {
    case folder
    case book
}

struct Folder: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var parentId: UUID?
    var type: FolderType
    var description: String
    var targetWordCount: Int?
    var coverImageUrl: String?
    var genre: String
    var noteCount: Int
    var createdAt: Date
    var updatedAt: Date

    var isBook: Bool { type == .book }

    enum CodingKeys: String, CodingKey {
        case id, name, type, description, genre
        case parentId = "parent_id"
        case targetWordCount = "target_word_count"
        case coverImageUrl = "cover_image_url"
        case noteCount = "note_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        parentId = try c.decodeIfPresent(UUID.self, forKey: .parentId)
        type = try c.decodeIfPresent(FolderType.self, forKey: .type) ?? .folder
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        targetWordCount = try c.decodeIfPresent(Int.self, forKey: .targetWordCount)
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
        genre = try c.decodeIfPresent(String.self, forKey: .genre) ?? ""
        noteCount = try c.decodeIfPresent(Int.self, forKey: .noteCount) ?? 0
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    init(
        id: UUID, name: String, parentId: UUID? = nil,
        type: FolderType = .folder, description: String = "",
        targetWordCount: Int? = nil, coverImageUrl: String? = nil,
        genre: String = "", noteCount: Int = 0,
        createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.type = type
        self.description = description
        self.targetWordCount = targetWordCount
        self.coverImageUrl = coverImageUrl
        self.genre = genre
        self.noteCount = noteCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func new(name: String, parentId: UUID? = nil, type: FolderType = .folder) -> Folder {
        let now = Date()
        return Folder(
            id: UUID(), name: name, parentId: parentId,
            type: type, createdAt: now, updatedAt: now
        )
    }
}
