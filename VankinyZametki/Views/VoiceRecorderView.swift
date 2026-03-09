import SwiftUI
@preconcurrency import AVFoundation

struct VoiceRecorderView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorderService()

    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var rawTranscription = ""
    @State private var createdNote: Note?
    @State private var showError = false
    @State private var isPlaying = false
    @State private var player: AVAudioPlayer?

    var body: some View {
        VStack(spacing: 0) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("Запись")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    stopPlayback()
                    recorder.cleanup()
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
        }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(recorder.errorMessage ?? "Неизвестная ошибка")
        }
        .onChange(of: recorder.recordingTime) { _, newValue in
            if newValue >= maxDuration && recorder.isRecording {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                _ = recorder.stopRecording()
            }
        }
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: 28) {
            waveformView

            VStack(spacing: 8) {
                Text(simpleTime)
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .foregroundStyle(recorder.isRecording ? .primary : .tertiary)
                    .monospacedDigit()

                if recorder.isRecording {
                    GeometryReader { geo in
                        let progress = min(recorder.recordingTime / maxDuration, 1.0)
                        let isWarning = maxDuration - recorder.recordingTime <= 30
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.quaternarySystemFill))
                                .frame(height: 3)
                            Capsule()
                                .fill(isWarning ? Color.red : Color.accentColor)
                                .frame(width: geo.size.width * progress, height: 3)
                                .animation(.linear(duration: 0.1), value: progress)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 32)
                }
            }

            recordControls

            Text(statusHint)
                .font(.footnote)
                .foregroundStyle(maxDuration - recorder.recordingTime <= 30 && recorder.isRecording ? Color.red : Color(.tertiaryLabel))
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    private let maxDuration: TimeInterval = 600

    private var simpleTime: String {
        let total = Int(recorder.recordingTime)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var remainingTime: String {
        let left = max(0, Int(maxDuration - recorder.recordingTime))
        let m = left / 60
        let s = left % 60
        return String(format: "%d:%02d", m, s)
    }

    private var statusHint: String {
        if recorder.isRecording {
            let left = maxDuration - recorder.recordingTime
            if left <= 30 {
                return "Осталось \(remainingTime)"
            }
            return "Макс. 10 минут"
        } else if recorder.recordingURL != nil {
            return "Прослушай или отправь на распознавание"
        } else {
            return "Нажми для записи (макс. 10 мин)"
        }
    }

    // MARK: - Waveform

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<40, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: i))
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(.easeOut(duration: 0.08), value: recorder.audioLevel)
            }
        }
        .frame(height: 64)
    }

    private func barColor(for index: Int) -> Color {
        guard recorder.isRecording else {
            return Color.accentColor.opacity(0.15)
        }
        let progress = Double(index) / 40.0
        return Color.accentColor.opacity(0.4 + progress * 0.5)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard recorder.isRecording else { return 3 }
        let base: CGFloat = 3
        let maxH: CGFloat = 64
        let wave = sin(Double(index) * 0.4 + recorder.recordingTime * 3.0)
        let variation = wave * 0.35 + 0.65
        return base + (maxH - base) * CGFloat(recorder.audioLevel) * CGFloat(variation)
    }

    // MARK: - Controls

    private var recordControls: some View {
        HStack(spacing: 28) {
            if recorder.isRecording {
                circleButton(icon: "stop.fill", size: 52, bg: Color(.systemGray4)) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    _ = recorder.stopRecording()
                }

                circleButton(icon: "arrow.up", size: 60, bg: Color.accentColor, iconWeight: .semibold) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    finishRecording()
                }
            } else if recorder.recordingURL != nil {
                labeledCircleButton(icon: "arrow.counterclockwise", size: 46, bg: Color(.tertiarySystemFill), fgColor: .secondary, label: "Заново") {
                    stopPlayback()
                    recorder.cleanup()
                    recorder.startRecording()
                }

                labeledCircleButton(icon: isPlaying ? "pause.fill" : "play.fill", size: 46, bg: Color(.tertiarySystemFill), fgColor: .primary, label: "Слушать") {
                    togglePlayback()
                }

                labeledCircleButton(icon: "arrow.up", size: 60, bg: Color.accentColor, fgColor: .white, iconWeight: .semibold, label: "Отправить") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    stopPlayback()
                    finishRecording()
                }
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    recorder.startRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.gradient)
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 4)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func circleButton(icon: String, size: CGFloat, bg: Color, fgColor: Color = .white, iconWeight: Font.Weight = .regular, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.32, weight: iconWeight))
                .foregroundStyle(fgColor)
                .frame(width: size, height: size)
                .background(Circle().fill(bg))
        }
    }

    private func labeledCircleButton(icon: String, size: CGFloat, bg: Color, fgColor: Color = .white, iconWeight: Font.Weight = .regular, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.32, weight: iconWeight))
                    .foregroundStyle(fgColor)
                    .frame(width: size, height: size)
                    .background(Circle().fill(bg))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let url = recorder.recordingURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true
        } catch {
            recorder.errorMessage = "Не удалось воспроизвести: \(error.localizedDescription)"
            showError = true
        }
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 4)
                    .frame(width: 56, height: 56)
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.accentColor)
            }

            VStack(spacing: 4) {
                Text(processingStatus)
                    .font(.headline)
                Text("Обычно 10-30 сек")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !rawTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Text("Распознано:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(rawTranscription)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Success

    private func successView(note: Note) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)

            VStack(spacing: 4) {
                Text("Заметка создана")
                    .font(.headline)
                Text(note.displayTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 32)
        .task {
            try? await Task.sleep(for: .seconds(2))
            dismiss()
        }
    }

    // MARK: - Logic

    private func finishRecording() {
        guard !isProcessing else { return }

        if recorder.isRecording {
            _ = recorder.stopRecording()
        }

        guard let audioData = recorder.getRecordingData() else {
            recorder.errorMessage = "Не удалось прочитать аудио"
            showError = true
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
                createdNote = note
                recorder.cleanup()
            } catch {
                recorder.errorMessage = "Ошибка: \(error.localizedDescription)"
                showError = true
                isProcessing = false
            }
        }
    }
}
