import Foundation

@MainActor
final class NoteProcessingService: ObservableObject {
    @Published var isProcessing = false
    @Published var status = ""
    @Published var errorMessage: String?

    private let api = APIService.shared

    func processVoiceRecording(audioData: Data) async -> Note? {
        isProcessing = true
        errorMessage = nil

        do {
            status = "Распознаю речь и форматирую..."
            let note = try await api.processVoiceNote(audioData: audioData)

            status = "Готово!"
            isProcessing = false
            return note
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
            return nil
        }
    }
}
