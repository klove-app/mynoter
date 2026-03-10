import AVFoundation
import CoreAudio
import Foundation

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
}

@MainActor
final class MacAudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    @Published var availableInputs: [AudioInputDevice] = []
    @Published var selectedInputID: AudioDeviceID = 0

    private var recorder: AVAudioRecorder?
    private var displayLink: Timer?
    private var tempURL: URL?

    override init() {
        super.init()
        refreshInputDevices()
    }

    var audioData: Data? {
        guard let url = tempURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func refreshInputDevices() {
        availableInputs = Self.listInputDevices()
        let currentDefault = Self.getDefaultInputDevice()
        if selectedInputID == 0 || !availableInputs.contains(where: { $0.id == selectedInputID }) {
            selectedInputID = currentDefault
        }
    }

    func selectInput(_ deviceID: AudioDeviceID) {
        selectedInputID = deviceID
        Self.setDefaultInputDevice(deviceID)
    }

    func startRecording() {
        if selectedInputID != 0 {
            Self.setDefaultInputDevice(selectedInputID)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(UUID().uuidString).m4a")
        tempURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            recordingTime = 0
            startMetering()
        } catch {
            print("Recording error: \(error)")
        }
    }

    // MARK: - Core Audio helpers

    private static func listInputDevices() -> [AudioInputDevice] {
        var propAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propAddress, 0, nil, &dataSize) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddress, 0, nil, &dataSize, &deviceIDs) == noErr else { return [] }

        var result: [AudioInputDevice] = []
        for devID in deviceIDs {
            var inputScope = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var bufSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(devID, &inputScope, 0, nil, &bufSize) == noErr, bufSize > 0 else { continue }

            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }
            guard AudioObjectGetPropertyData(devID, &inputScope, 0, nil, &bufSize, bufferList) == noErr else { continue }

            let channelCount = (0..<Int(bufferList.pointee.mNumberBuffers)).reduce(0) { total, i in
                let buf = UnsafeMutableAudioBufferListPointer(bufferList)[i]
                return total + Int(buf.mNumberChannels)
            }
            guard channelCount > 0 else { continue }

            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(devID, &nameAddr, 0, nil, &nameSize, &name)

            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(devID, &uidAddr, 0, nil, &uidSize, &uid)

            result.append(AudioInputDevice(id: devID, name: name as String, uid: uid as String))
        }
        return result
    }

    private static func getDefaultInputDevice() -> AudioDeviceID {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &size, &deviceID)
        return deviceID
    }

    private static func setDefaultInputDevice(_ deviceID: AudioDeviceID) {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var devID = deviceID
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &devID)
    }

    func stopRecording() {
        recorder?.stop()
        displayLink?.invalidate()
        displayLink = nil
        isRecording = false
    }

    func cleanup() {
        stopRecording()
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
        }
        tempURL = nil
        recordingTime = 0
        audioLevels = Array(repeating: 0, count: 30)
    }

    private func startMetering() {
        displayLink = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder, recorder.isRecording else { return }
                recorder.updateMeters()
                self.recordingTime = recorder.currentTime

                let power = recorder.averagePower(forChannel: 0)
                let normalized = max(0, min(1, CGFloat((power + 50) / 50)))
                self.audioLevels.append(normalized)
                if self.audioLevels.count > 30 { self.audioLevels.removeFirst() }
            }
        }
    }
}
