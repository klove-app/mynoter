import Foundation
import AVFoundation

@MainActor
final class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var recordingURL: URL?

    override init() {
        super.init()
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "Не удалось настроить аудио сессию: \(error.localizedDescription)"
            return
        }

        let filename = "voice_\(UUID().uuidString).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            recordingTime = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let recorder = self.recorder, recorder.isRecording else { return }
                    self.recordingTime = recorder.currentTime
                    recorder.updateMeters()
                    let db = recorder.averagePower(forChannel: 0)
                    self.audioLevel = max(0, (db + 50) / 50)
                }
            }
        } catch {
            errorMessage = "Не удалось начать запись: \(error.localizedDescription)"
        }
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        audioLevel = 0

        try? AVAudioSession.sharedInstance().setActive(false)

        return recordingURL
    }

    func getRecordingData() -> Data? {
        guard let url = recordingURL else { return nil }
        return try? Data(contentsOf: url)
    }

    func cleanup() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }

    var formattedTime: String {
        let mins = Int(recordingTime) / 60
        let secs = Int(recordingTime) % 60
        let ms = Int((recordingTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, secs, ms)
    }
}
