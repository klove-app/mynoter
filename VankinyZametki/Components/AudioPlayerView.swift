import SwiftUI
@preconcurrency import AVFoundation

struct AudioPlayerView: View {
    let urlString: String

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let error = loadError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
            } else {
                HStack(spacing: 14) {
                    Button {
                        togglePlayback()
                    } label: {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.accentColor.gradient)
                        )
                    }
                    .disabled(isLoading)

                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(height: 4)

                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(
                                        width: duration > 0 ? geo.size.width * (progress / duration) : 0,
                                        height: 4
                                    )
                                    .animation(.linear(duration: 0.1), value: progress)
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 16)

                        HStack {
                            Text(formatTime(progress))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                            Text(formatTime(duration))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
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
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            isLoading = false
        } catch {
            loadError = "Не удалось загрузить"
            isLoading = false
        }
    }

    private func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            timer?.invalidate()
        } else {
            player.play()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
                MainActor.assumeIsolated {
                    progress = player.currentTime
                    if !player.isPlaying {
                        isPlaying = false
                        timer?.invalidate()
                        progress = 0
                    }
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
