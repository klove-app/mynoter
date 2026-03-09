import Foundation

struct Folder: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var parentId: UUID?
    var noteCount: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentId = "parent_id"
        case noteCount = "note_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        parentId = try c.decodeIfPresent(UUID.self, forKey: .parentId)
        noteCount = try c.decodeIfPresent(Int.self, forKey: .noteCount) ?? 0
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    init(id: UUID, name: String, parentId: UUID? = nil, noteCount: Int = 0, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.noteCount = noteCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func new(name: String, parentId: UUID? = nil) -> Folder {
        let now = Date()
        return Folder(
            id: UUID(),
            name: name,
            parentId: parentId,
            noteCount: 0,
            createdAt: now,
            updatedAt: now
        )
    }
}
