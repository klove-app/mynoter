import Foundation
import SwiftUI

struct Tag: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var color: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "blue"
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? Date()
    }

    init(id: UUID, name: String, color: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum TagColor: String, CaseIterable, Equatable {
    case red, orange, yellow, green, blue, purple, pink, teal

    var displayName: String {
        switch self {
        case .red: return "Красный"
        case .orange: return "Оранжевый"
        case .yellow: return "Жёлтый"
        case .green: return "Зелёный"
        case .blue: return "Голубой"
        case .purple: return "Фиолетовый"
        case .pink: return "Розовый"
        case .teal: return "Бирюзовый"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return Color(red: 0.9, green: 0.8, blue: 0.0)
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .teal: return .teal
        }
    }

    static func from(_ string: String) -> TagColor {
        TagColor(rawValue: string) ?? .blue
    }
}

extension Tag {
    var tagColor: TagColor { TagColor.from(color) }
    var swiftUIColor: Color { tagColor.swiftUIColor }
}
