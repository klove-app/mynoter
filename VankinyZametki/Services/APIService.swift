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

    func createNote(title: String, content: String, folderId: UUID?) async throws -> Note {
        let body: [String: Any?] = [
            "title": title,
            "content": content,
            "folder_id": folderId?.uuidString
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
            "transcription_raw": note.transcriptionRaw
        ]
        return try await put("/api/notes/\(note.id)", body: body)
    }

    func deleteNote(id: UUID) async throws {
        let _: EmptyResponse = try await delete("/api/notes/\(id)")
    }

    // MARK: - Folders

    func fetchFolders() async throws -> [Folder] {
        try await get("/api/folders")
    }

    func createFolder(name: String, parentId: UUID?) async throws -> Folder {
        let body: [String: Any?] = [
            "name": name,
            "parent_id": parentId?.uuidString
        ]
        return try await post("/api/folders", body: body)
    }

    func updateFolder(_ folder: Folder) async throws -> Folder {
        let body: [String: Any?] = [
            "name": folder.name,
            "parent_id": folder.parentId?.uuidString
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
