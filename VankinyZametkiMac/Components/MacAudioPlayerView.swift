import SwiftUI
import AVFoundation

struct MacAudioPlayerView: View {
    let urlString: String

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)

            ZStack(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color(.separatorColor))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: duration > 0 ? geo.size.width * progress / duration : 0, height: 3)
                }
                .frame(height: 3)
            }
            .padding(.vertical, 10)

            Text(formatTime(progress))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(10)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .onAppear { preparePlayer() }
        .onDisappear { cleanup() }
    }

    private func preparePlayer() {
        guard let url = URL(string: urlString) else { return }
        player = AVPlayer(url: url)
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            timer?.invalidate()
        } else {
            if let d = player.currentItem?.duration, !d.seconds.isNaN {
                duration = d.seconds
            }
            player.play()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let current = player.currentTime().seconds
                if !current.isNaN { progress = current }
                if let d = player.currentItem?.duration, !d.seconds.isNaN {
                    duration = d.seconds
                }
                if current >= duration && duration > 0 {
                    isPlaying = false
                    timer?.invalidate()
                    player.seek(to: .zero)
                    progress = 0
                }
            }
        }
        isPlaying.toggle()
    }

    private func cleanup() {
        timer?.invalidate()
        player?.pause()
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
