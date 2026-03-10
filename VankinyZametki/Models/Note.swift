import Foundation

enum ChapterStatus: String, Codable, CaseIterable, Equatable, Hashable {
    case draft
    case inProgress = "in_progress"
    case revised
    case final_ = "final"

    var displayName: String {
        switch self {
        case .draft: return "Черновик"
        case .inProgress: return "В работе"
        case .revised: return "Правка"
        case .final_: return "Готово"
        }
    }

    var icon: String {
        switch self {
        case .draft: return "doc"
        case .inProgress: return "pencil"
        case .revised: return "checkmark.circle"
        case .final_: return "checkmark.seal.fill"
        }
    }

    var color: String {
        switch self {
        case .draft: return "gray"
        case .inProgress: return "blue"
        case .revised: return "orange"
        case .final_: return "green"
        }
    }
}

struct Note: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var folderId: UUID?
    var isVoiceNote: Bool
    var audioUrl: String?
    var transcriptionRaw: String?
    var sortOrder: Int
    var synopsis: String
    var status: ChapterStatus
    var wordCount: Int
    var tags: [Tag]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, content, synopsis, status, tags
        case folderId = "folder_id"
        case isVoiceNote = "is_voice_note"
        case audioUrl = "audio_url"
        case transcriptionRaw = "transcription_raw"
        case sortOrder = "sort_order"
        case wordCount = "word_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        folderId = try c.decodeIfPresent(UUID.self, forKey: .folderId)
        isVoiceNote = try c.decodeIfPresent(Bool.self, forKey: .isVoiceNote) ?? false
        audioUrl = try c.decodeIfPresent(String.self, forKey: .audioUrl)
        transcriptionRaw = try c.decodeIfPresent(String.self, forKey: .transcriptionRaw)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        synopsis = try c.decodeIfPresent(String.self, forKey: .synopsis) ?? ""
        status = try c.decodeIfPresent(ChapterStatus.self, forKey: .status) ?? .draft
        wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        tags = try c.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    init(
        id: UUID, title: String, content: String, folderId: UUID?,
        isVoiceNote: Bool, audioUrl: String?, transcriptionRaw: String?,
        sortOrder: Int = 0, synopsis: String = "",
        status: ChapterStatus = .draft, wordCount: Int = 0,
        tags: [Tag] = [],
        createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.folderId = folderId
        self.isVoiceNote = isVoiceNote
        self.audioUrl = audioUrl
        self.transcriptionRaw = transcriptionRaw
        self.sortOrder = sortOrder
        self.synopsis = synopsis
        self.status = status
        self.wordCount = wordCount
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func new(title: String = "", content: String = "", folderId: UUID? = nil) -> Note {
        let now = Date()
        return Note(
            id: UUID(), title: title, content: content, folderId: folderId,
            isVoiceNote: false, audioUrl: nil, transcriptionRaw: nil,
            createdAt: now, updatedAt: now
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

    var computedWordCount: Int {
        content
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }
}
