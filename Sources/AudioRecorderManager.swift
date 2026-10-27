import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorderManager: NSObject, ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var recordingTime: TimeInterval = 0
    @Published private(set) var lastRecordingURL: URL?

    private var recorder: AVAudioRecorder?
    private var timer: AnyCancellable?
    private var currentRecordingURL: URL?

    func startRecording(stopAt: TimeInterval? = nil) throws {
        guard !isRecording else { return }

        let url = Self.makeRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw NSError(
                domain: "AudioRecorder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "녹음을 시작할 수 없습니다. 마이크 권한을 확인해 주세요."]
            )
        }

        self.recorder = recorder
        self.currentRecordingURL = url
        self.isRecording = true
        self.recordingTime = 0
        startTimer(stopAt: stopAt)
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopTimer()
        lastRecordingURL = currentRecordingURL
    }

    private func startTimer(stopAt: TimeInterval? = nil) {
        stopTimer()
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let recorder = self.recorder else { return }
                self.recordingTime = recorder.currentTime
                if let limit = stopAt, recorder.currentTime >= limit {
                    self.stopRecording()
                }
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private static func makeRecordingURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "recording_\(formatter.string(from: Date())).wav"
        return docs.appendingPathComponent(name)
    }
}
