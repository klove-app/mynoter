import SwiftUI

struct MacVoiceAppendView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = MacAudioRecorderService()
    let onAppend: (String) -> Void

    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var rawTranscription = ""
    @State private var done = false
    @State private var error: String?

    private let maxDuration: TimeInterval = 600

    var body: some View {
        VStack(spacing: 20) {
            Text("Дозапись голосом")
                .font(.headline)

            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(processingStatus)
                        .font(.callout.weight(.medium))
                    if !rawTranscription.isEmpty {
                        ScrollView {
                            Text(rawTranscription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                        }
                        .frame(maxHeight: 120)
                        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else if done {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                    Text("Текст добавлен!")
                        .font(.body.weight(.medium))
                    Button("Закрыть") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                waveformView
                    .frame(height: 50)

                Text(simpleTime)
                    .font(.system(size: 36, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(recorder.isRecording ? .primary : .tertiary)

                HStack(spacing: 20) {
                    if recorder.isRecording {
                        Button { finishRecording() } label: {
                            Image(systemName: "stop.fill")
                                .font(.body)
                                .frame(width: 40, height: 40)
                                .background(Color.red, in: Circle())
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { recorder.startRecording() } label: {
                            Image(systemName: "mic.fill")
                                .font(.body)
                                .frame(width: 40, height: 40)
                                .background(Color.red, in: Circle())
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(20)
        .onChange(of: recorder.recordingTime) { _, newVal in
            if newVal >= maxDuration && recorder.isRecording { finishRecording() }
        }
    }

    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<30, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(recorder.isRecording ? Color.red : Color(.separatorColor))
                    .frame(width: 3, height: max(3, 40 * recorder.audioLevels[i]))
                    .animation(.easeOut(duration: 0.05), value: recorder.audioLevels[i])
            }
        }
    }

    private var simpleTime: String {
        let t = Int(recorder.recordingTime)
        let m = t / 60, s = t % 60
        return String(format: "%d:%02d", m, s)
    }

    private func finishRecording() {
        recorder.stopRecording()
        guard let audioData = recorder.audioData else {
            error = "Нет аудио данных"
            return
        }
        isProcessing = true
        processingStatus = "Распознаю речь..."
        Task {
            do {
                let result = try await APIService.shared.transcribeAudio(audioData: audioData)
                rawTranscription = result.transcription
                processingStatus = "Форматирую текст..."
                let html = try await APIService.shared.formatText(transcription: result.transcription)
                isProcessing = false
                done = true
                onAppend(html)
                recorder.cleanup()
            } catch {
                isProcessing = false
                self.error = error.localizedDescription
            }
        }
    }
}
