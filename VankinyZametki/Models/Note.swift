import Foundation

struct Note: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var folderId: UUID?
    var isVoiceNote: Bool
    var audioUrl: String?
    var transcriptionRaw: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case folderId = "folder_id"
        case isVoiceNote = "is_voice_note"
        case audioUrl = "audio_url"
        case transcriptionRaw = "transcription_raw"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func new(title: String = "", content: String = "", folderId: UUID? = nil) -> Note {
        let now = Date()
        return Note(
            id: UUID(),
            title: title,
            content: content,
            folderId: folderId,
            isVoiceNote: false,
            audioUrl: nil,
            transcriptionRaw: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    var snippet: String {
        let stripped = content
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(stripped.prefix(120))
    }

    var displayTitle: String {
        title.isEmpty ? "Без названия" : title
    }
}
