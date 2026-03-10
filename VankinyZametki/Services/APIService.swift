import Foundation

final class APIService: @unchecked Sendable {
    static let shared = APIService()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        baseURL = Config.apiBaseURL
        session = URLSession.shared

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: str) { return date }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Notes

    func fetchNotes() async throws -> [Note] {
        try await get("/api/notes")
    }

    func fetchNotes(inFolder folderId: UUID) async throws -> [Note] {
        try await get("/api/notes?folder_id=\(folderId)")
    }

    func searchNotes(query: String) async throws -> [Note] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get("/api/notes?search=\(encoded)")
    }

    func createNote(title: String, content: String, folderId: UUID?, sortOrder: Int = 0) async throws -> Note {
        let body: [String: Any?] = [
            "title": title,
            "content": content,
            "folder_id": folderId?.uuidString,
            "sort_order": sortOrder
        ]
        return try await post("/api/notes", body: body)
    }

    func updateNote(_ note: Note) async throws -> Note {
        let body: [String: Any?] = [
            "title": note.title,
            "content": note.content,
            "folder_id": note.folderId?.uuidString,
            "is_voice_note": note.isVoiceNote,
            "audio_url": note.audioUrl,
            "transcription_raw": note.transcriptionRaw,
            "sort_order": note.sortOrder,
            "synopsis": note.synopsis,
            "status": note.status.rawValue,
            "word_count": note.wordCount
        ]
        return try await put("/api/notes/\(note.id)", body: body)
    }

    func deleteNote(id: UUID) async throws {
        let _: EmptyResponse = try await delete("/api/notes/\(id)")
    }

    func fetchChapters(bookId: UUID) async throws -> [Note] {
        try await get("/api/notes?folder_id=\(bookId)&sort_by_order=true")
    }

    struct ReorderItem: Encodable {
        let id: UUID
        let sort_order: Int
    }

    func reorderNotes(items: [ReorderItem]) async throws {
        let body: [String: Any] = [
            "items": items.map { ["id": $0.id.uuidString, "sort_order": $0.sort_order] }
        ]
        let _: [String: Int] = try await put("/api/notes/reorder/batch", body: body)
    }

    struct BookStats: Decodable {
        let chapterCount: Int
        let totalWords: Int
        let completedChapters: Int
        let draftChapters: Int
        let inProgressChapters: Int
        let revisedChapters: Int

        enum CodingKeys: String, CodingKey {
            case chapterCount = "chapter_count"
            case totalWords = "total_words"
            case completedChapters = "completed_chapters"
            case draftChapters = "draft_chapters"
            case inProgressChapters = "in_progress_chapters"
            case revisedChapters = "revised_chapters"
        }
    }

    func fetchBookStats(bookId: UUID) async throws -> BookStats {
        try await get("/api/notes/book-stats/\(bookId)")
    }

    // MARK: - Tags

    func fetchTags() async throws -> [Tag] {
        try await get("/api/tags")
    }

    func createTag(name: String, color: String) async throws -> Tag {
        let body: [String: Any?] = ["name": name, "color": color]
        return try await post("/api/tags", body: body)
    }

    func updateTag(_ tag: Tag) async throws -> Tag {
        let body: [String: Any?] = ["name": tag.name, "color": tag.color]
        return try await put("/api/tags/\(tag.id)", body: body)
    }

    func deleteTag(id: UUID) async throws {
        let _: EmptyResponse = try await delete("/api/tags/\(id)")
    }

    func fetchTagsForNote(noteId: UUID) async throws -> [Tag] {
        try await get("/api/tags/note/\(noteId)")
    }

    func addTagToNote(tagId: UUID, noteId: UUID) async throws -> [Tag] {
        let body: [String: Any?] = ["tag_id": tagId.uuidString]
        return try await post("/api/tags/note/\(noteId)", body: body)
    }

    func removeTagFromNote(tagId: UUID, noteId: UUID) async throws -> [Tag] {
        try await delete("/api/tags/note/\(noteId)/\(tagId)")
    }

    func fetchNotesForTag(tagId: UUID) async throws -> [Note] {
        try await get("/api/tags/\(tagId)/notes")
    }

    // MARK: - Folders

    func fetchFolders() async throws -> [Folder] {
        try await get("/api/folders")
    }

    func createFolder(name: String, parentId: UUID?, type: FolderType = .folder,
                      description: String = "", targetWordCount: Int? = nil,
                      genre: String = "") async throws -> Folder {
        let body: [String: Any?] = [
            "name": name,
            "parent_id": parentId?.uuidString,
            "type": type.rawValue,
            "description": description,
            "target_word_count": targetWordCount,
            "genre": genre
        ]
        return try await post("/api/folders", body: body)
    }

    func updateFolder(_ folder: Folder) async throws -> Folder {
        let body: [String: Any?] = [
            "name": folder.name,
            "parent_id": folder.parentId?.uuidString,
            "type": folder.type.rawValue,
            "description": folder.description,
            "target_word_count": folder.targetWordCount,
            "genre": folder.genre
        ]
        return try await put("/api/folders/\(folder.id)", body: body)
    }

    func deleteFolder(id: UUID) async throws {
        let _: EmptyResponse = try await delete("/api/folders/\(id)")
    }

    // MARK: - Voice Processing

    struct TranscriptionResult: Decodable {
        let transcription: String
        let audioUrl: String

        enum CodingKeys: String, CodingKey {
            case transcription
            case audioUrl = "audio_url"
        }
    }

    func transcribeAudio(audioData: Data) async throws -> TranscriptionResult {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/api/voice/transcribe")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(TranscriptionResult.self, from: data)
    }

    func formatAndSaveNote(transcription: String, audioUrl: String) async throws -> Note {
        let body: [String: Any?] = [
            "transcription": transcription,
            "audio_url": audioUrl
        ]
        return try await post("/api/voice/format", body: body)
    }

    struct FormatTextResult: Decodable {
        let html: String
    }

    func formatText(transcription: String) async throws -> String {
        let body: [String: Any?] = ["transcription": transcription]
        let result: FormatTextResult = try await post("/api/voice/format-text", body: body)
        return result.html
    }

    func normalizeContent(html: String) async throws -> String {
        let body: [String: Any?] = ["html": html]
        let result: FormatTextResult = try await post("/api/voice/normalize", body: body)
        return result.html
    }

    // MARK: - Diagram Generation

    struct DiagramResult: Decodable {
        let url: String
        let mermaidCode: String
        let filename: String
    }

    func generateDiagram(description: String, type: String = "auto") async throws -> DiagramResult {
        let body: [String: Any?] = ["description": description, "type": type]
        return try await post("/api/diagrams/generate", body: body)
    }

    // MARK: - Image Upload

    struct ImageUploadResult: Decodable {
        let filename: String
        let url: String
        let width: Int?
        let height: Int?
        let size: Int?
    }

    func uploadImage(data: Data, mimeType: String = "image/jpeg") async throws -> ImageUploadResult {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/api/images/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let ext: String
        switch mimeType {
        case "image/png": ext = "png"
        case "image/gif": ext = "gif"
        case "image/webp": ext = "webp"
        default: ext = "jpg"
        }

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.\(ext)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        try checkResponse(response, data: responseData)
        return try decoder.decode(ImageUploadResult.self, from: responseData)
    }

    // MARK: - Audio Upload

    func uploadAudio(data: Data) async throws -> String {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/api/audio/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        try checkResponse(response, data: responseData)

        struct UploadResponse: Decodable {
            let url: String
        }
        let result = try decoder.decode(UploadResponse.self, from: responseData)
        return result.url
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        let (data, response) = try await session.data(from: url)
        try checkResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any?]) async throws -> T {
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func put<T: Decodable>(_ path: String, body: [String: Any?]) async throws -> T {
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.httpMethod = "DELETE"
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "HTTP \(http.statusCode)"
            throw APIError.server(message)
        }
    }
}

private struct EmptyResponse: Decodable {}
private struct ErrorBody: Decodable { let error: String }

enum APIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Неверный ответ сервера"
        case .server(let msg): return msg
        }
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
