import SwiftUI

struct MacVoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var noteStore: NoteStore
    @StateObject private var recorder = MacAudioRecorderService()

    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var rawTranscription = ""
    @State private var createdNote: Note?
    @State private var error: String?

    private let maxDuration: TimeInterval = 600

    var body: some View {
        VStack(spacing: 24) {
            if isProcessing {
                processingView
            } else if let note = createdNote {
                successView(note: note)
            } else {
                recordingView
            }
        }
        .padding(24)
        .navigationTitle("Голосовая заметка")
    }

    private var recordingView: some View {
        VStack(spacing: 20) {
            if !recorder.isRecording {
                microphonePicker
            }

            waveformView
                .frame(height: 60)

            Text(simpleTime)
                .font(.system(size: 40, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(recorder.isRecording ? .primary : .tertiary)

            if recorder.isRecording {
                GeometryReader { geo in
                    let progress = min(recorder.recordingTime / maxDuration, 1.0)
                    let isWarning = maxDuration - recorder.recordingTime <= 30
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.separatorColor)).frame(height: 3)
                        Capsule()
                            .fill(isWarning ? Color.red : Color.accentColor)
                            .frame(width: geo.size.width * progress, height: 3)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 32)
            }

            HStack(spacing: 24) {
                if recorder.isRecording {
                    Button { finishRecording() } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .frame(width: 48, height: 48)
                            .background(Color.red, in: Circle())
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { recorder.startRecording() } label: {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .frame(width: 48, height: 48)
                            .background(Color.red, in: Circle())
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(recorder.isRecording ? "Запись... (до 10 мин)" : "Нажмите для начала записи")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: recorder.recordingTime) { _, newVal in
            if newVal >= maxDuration && recorder.isRecording {
                finishRecording()
            }
        }
        .onAppear { recorder.refreshInputDevices() }
    }

    private var microphonePicker: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Picker("", selection: $recorder.selectedInputID) {
                ForEach(recorder.availableInputs) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 250)
            .onChange(of: recorder.selectedInputID) { _, newVal in
                recorder.selectInput(newVal)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<30, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(recorder.isRecording ? Color.red : Color(.separatorColor))
                    .frame(width: 3, height: max(3, 50 * recorder.audioLevels[i]))
                    .animation(.easeOut(duration: 0.05), value: recorder.audioLevels[i])
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(processingStatus)
                .font(.body.weight(.medium))
            if !rawTranscription.isEmpty {
                ScrollView {
                    Text(rawTranscription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 150)
                .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func successView(note: Note) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Заметка создана!")
                .font(.title3.weight(.medium))
            Text(note.displayTitle)
                .font(.body)
                .foregroundStyle(.secondary)
            Button("Закрыть") { dismiss() }
                .buttonStyle(.borderedProminent)
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
        rawTranscription = ""
        Task {
            do {
                let result = try await APIService.shared.transcribeAudio(audioData: audioData)
                rawTranscription = result.transcription
                processingStatus = "Форматирую текст..."
                let note = try await APIService.shared.formatAndSaveNote(
                    transcription: result.transcription,
                    audioUrl: result.audioUrl
                )
                await noteStore.loadNotes()
                isProcessing = false
                createdNote = note
                recorder.cleanup()
            } catch {
                isProcessing = false
                self.error = error.localizedDescription
            }
        }
    }
}
