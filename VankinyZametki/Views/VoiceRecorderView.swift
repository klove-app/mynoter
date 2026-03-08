import SwiftUI

struct VoiceRecorderView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorderService()

    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var createdNote: Note?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if isProcessing {
                processingView
            } else if let note = createdNote {
                successView(note: note)
            } else {
                recordingView
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Голосовая заметка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    recorder.cleanup()
                    dismiss()
                }
            }
        }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(recorder.errorMessage ?? "Неизвестная ошибка")
        }
    }

    private var recordingView: some View {
        VStack(spacing: 24) {
            audioVisualization

            Text(recorder.formattedTime)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(recorder.isRecording ? .primary : .secondary)

            HStack(spacing: 40) {
                if recorder.isRecording {
                    Button {
                        _ = recorder.stopRecording()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.red)
                    }

                    Button {
                        finishRecording()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                    }
                } else if recorder.recordingURL != nil {
                    Button {
                        recorder.cleanup()
                        recorder.startRecording()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        finishRecording()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                    }
                } else {
                    Button {
                        recorder.startRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }

            if !recorder.isRecording && recorder.recordingURL == nil {
                Text("Нажми для начала записи")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var audioVisualization: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(recorder.isRecording ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 4, height: barHeight(for: i))
                    .animation(
                        .easeInOut(duration: 0.1),
                        value: recorder.audioLevel
                    )
            }
        }
        .frame(height: 80)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard recorder.isRecording else { return 8 }
        let base: CGFloat = 8
        let maxH: CGFloat = 80
        let variation = sin(Double(index) * 0.5 + recorder.recordingTime * 3) * 0.3 + 0.7
        return base + (maxH - base) * CGFloat(recorder.audioLevel) * CGFloat(variation)
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(processingStatus)
                .font(.headline)
            Text("Обычно это занимает 10-30 секунд")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func successView(note: Note) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Заметка создана!")
                .font(.title2.bold())
            Text(note.displayTitle)
                .font(.headline)
                .foregroundStyle(.secondary)

            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                dismiss()
            } label: {
                Text("Готово")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
    }

    private func finishRecording() {
        if recorder.isRecording {
            _ = recorder.stopRecording()
        }

        guard let audioData = recorder.getRecordingData() else {
            recorder.errorMessage = "Не удалось прочитать аудио файл"
            showError = true
            return
        }

        isProcessing = true
        processingStatus = "Загружаю аудио..."

        Task {
            do {
                processingStatus = "Распознаю речь и форматирую..."
                let note = try await APIService.shared.processVoiceNote(audioData: audioData)

                await noteStore.loadNotes()
                createdNote = note
                recorder.cleanup()
            } catch {
                recorder.errorMessage = "Ошибка обработки: \(error.localizedDescription)"
                showError = true
                isProcessing = false
            }
        }
    }
}
