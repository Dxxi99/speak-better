import Foundation
import Combine

@MainActor
final class WhisperService: ObservableObject {
    @Published private(set) var isWorking = false
    @Published private(set) var status: String = ""
    @Published var cues: [SubtitleCue] = []

    func transcribe(url: URL) async throws {
        isWorking = true
        status = "AI 분석 중..."
        cues = []
        defer { isWorking = false }

        let possiblePaths = ["/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli"]
        guard let cliPath = possiblePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw NSError(domain: "Whisper", code: 1, userInfo: [NSLocalizedDescriptionKey: "whisper-cli를 찾을 수 없습니다."])
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelURL = appSupport.appendingPathComponent("AudioRepeatMVP/ggml-large-v3-turbo.bin")
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw NSError(domain: "Whisper", code: 2, userInfo: [NSLocalizedDescriptionKey: "AI 모델이 없습니다."])
        }

        let tempWav = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_input.wav")
        try? FileManager.default.removeItem(at: tempWav)

        guard let ffmpeg = AppSettings.ffmpegPath else {
            throw NSError(domain: "Whisper", code: 3, userInfo: [NSLocalizedDescriptionKey: "ffmpeg를 찾을 수 없습니다."])
        }

        let convertProcess = Process()
        convertProcess.executableURL = URL(fileURLWithPath: ffmpeg)
        convertProcess.arguments = ["-y", "-i", url.path, "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", tempWav.path]
        convertProcess.standardOutput = Pipe()
        convertProcess.standardError = Pipe()
        try convertProcess.run()
        convertProcess.waitUntilExit()

        guard convertProcess.terminationStatus == 0 else {
            throw NSError(domain: "Whisper", code: 4, userInfo: [NSLocalizedDescriptionKey: "오디오 포맷 변환 실패."])
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_out_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let outputBase = tempDir.appendingPathComponent("output")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = [
            "-m", modelURL.path,
            "-f", tempWav.path,
            "-l", "auto",
            "-osrt",
            "-of", outputBase.path,
            "--max-len", "40",
            "--split-on-word"
        ]

        let errPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? "알 수 없는 오류"
            throw NSError(domain: "Whisper", code: 5, userInfo: [NSLocalizedDescriptionKey: "Whisper 실행 실패: \(errStr.prefix(200))"])
        }

        let srtURL = outputBase.appendingPathExtension("srt")
        guard FileManager.default.fileExists(atPath: srtURL.path) else {
            throw NSError(domain: "Whisper", code: 6, userInfo: [NSLocalizedDescriptionKey: "자막 파일이 생성되지 않았습니다."])
        }

        let srtContent = try String(contentsOf: srtURL, encoding: .utf8)
        let parsed = SubtitleService.parseSRT(srtContent)
        if parsed.isEmpty {
            throw NSError(domain: "Whisper", code: 7, userInfo: [NSLocalizedDescriptionKey: "자막 파싱 결과가 비어 있습니다."])
        }
        self.cues = parsed
        status = "분석 완료 (\(parsed.count)개)"
    }
}
