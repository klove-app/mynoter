import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    let urlString: String

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 8) {
            if let error = loadError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                HStack(spacing: 12) {
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.accentColor)
                    }

                    VStack(spacing: 4) {
                        ProgressView(value: progress, total: max(duration, 1))
                            .tint(.accentColor)

                        HStack {
                            Text(formatTime(progress))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                            Text(formatTime(duration))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
        }
        .task {
            await loadAudio()
        }
        .onDisappear {
            timer?.invalidate()
            player?.stop()
        }
    }

    private func loadAudio() async {
        guard let url = URL(string: urlString) else {
            loadError = "Неверный URL аудио"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            loadError = "Не удалось загрузить аудио"
        }
    }

    private func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            timer?.invalidate()
        } else {
            player.play()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                progress = player.currentTime
                if !player.isPlaying {
                    isPlaying = false
                    timer?.invalidate()
                    progress = 0
                }
            }
        }
        isPlaying.toggle()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
