import Foundation

struct Folder: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var parentId: UUID?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentId = "parent_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func new(name: String, parentId: UUID? = nil) -> Folder {
        let now = Date()
        return Folder(
            id: UUID(),
            name: name,
            parentId: parentId,
            createdAt: now,
            updatedAt: now
        )
    }
}
