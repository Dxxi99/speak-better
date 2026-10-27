import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioPlaybackManager: NSObject, ObservableObject {

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var loopStart: TimeInterval? = nil
    @Published var loopEnd: TimeInterval? = nil
    @Published var rate: Float = 1.0 {
        didSet {
            audioPlayer?.enableRate = true
            audioPlayer?.rate = rate
            secondPlayer?.enableRate = true
            secondPlayer?.rate = rate
        }
    }
    @Published var isLooping = false {
        didSet { audioPlayer?.numberOfLoops = isLooping ? -1 : 0 }
    }

    private var audioPlayer: AVAudioPlayer?
    private var secondPlayer: AVAudioPlayer?
    private var timer: AnyCancellable?
    private(set) var loadedURL: URL?

    @Published var primaryVolume: Float = 1.0 {
        didSet { audioPlayer?.volume = primaryVolume }
    }
    @Published var secondaryVolume: Float = 0.0 {
        didSet { secondPlayer?.volume = secondaryVolume }
    }

    func load(url: URL) throws {
        stop()
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.enableRate = true
        player.rate = rate
        player.prepareToPlay()
        player.numberOfLoops = isLooping ? -1 : 0
        audioPlayer = player
        loadedURL = url
        duration = player.duration
        currentTime = 0
    }

    func play() {
        guard let player = audioPlayer else { return }
        player.play()
        if let sp = secondPlayer {
            sp.currentTime = player.currentTime
            sp.play()
        }
        isPlaying = true
        startTimer()
    }

    func pause() {
        audioPlayer?.pause()
        secondPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        secondPlayer?.stop()
        secondPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }

    func loadSecond(url: URL) throws {
        let p = try AVAudioPlayer(contentsOf: url)
        p.enableRate = true
        p.rate = rate
        p.prepareToPlay()
        p.volume = secondaryVolume
        secondPlayer = p
    }

    func clearSecond() {
        secondPlayer?.stop()
        secondPlayer = nil
    }

    func setVolumes(primary: Float, secondary: Float) {
        primaryVolume = primary
        secondaryVolume = secondary
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        if let sp = secondPlayer {
            sp.currentTime = min(clamped, sp.duration)
        }
        currentTime = clamped
    }

    func clearLoopRegion() {
        loopStart = nil
        loopEnd = nil
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                
                // 지정된 반복 구간 끝에 도달하면 구간 시작점으로 이동
                if let start = self.loopStart, let end = self.loopEnd {
                    if player.currentTime >= end {
                        player.currentTime = start
                        self.currentTime = start
                    }
                }

            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}

extension AudioPlaybackManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isPlaying = false
            self.stopTimer()
        }
    }
}
