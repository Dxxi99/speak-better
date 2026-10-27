import Foundation
import Combine

enum URLImportError: LocalizedError {
    case ytDlpMissing
    case ffmpegMissing
    case invalidURL
    case downloadFailed(String)
    case convertFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .ytDlpMissing: return "yt-dlp를 찾을 수 없습니다."
        case .ffmpegMissing: return "ffmpeg를 찾을 수 없습니다."
        case .invalidURL: return "유효하지 않은 URL입니다."
        case .downloadFailed(let msg): return "다운로드 실패: \(msg)"
        case .convertFailed(let msg): return "오디오 변환 실패: \(msg)"
        case .cancelled: return "취소되었습니다."
        }
    }
}

struct URLImportResult {
    let audioURL: URL
    let title: String
    let subtitleURL: URL?
}

@MainActor
final class URLImportService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status: String = ""
    @Published private(set) var progress: Double = 0

    private var currentProcess: Process?

    func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
        isRunning = false
        status = "취소됨"
    }

    func importURL(_ urlString: String) async throws -> URLImportResult {
        guard let url = URL(string: urlString), url.scheme != nil else {
            throw URLImportError.invalidURL
        }
        guard let ytDlp = AppSettings.ytDlpPath else { throw URLImportError.ytDlpMissing }
        guard let ffmpeg = AppSettings.ffmpegPath else { throw URLImportError.ffmpegMissing }

        let dir = try AppSettings.makeWorkingDirectory()
        isRunning = true
        progress = 0
        status = "다운로드 준비 중..."

        defer {
            isRunning = false
            currentProcess = nil
        }

        let downloadTemplate = dir.appendingPathComponent("source.%(ext)s").path

        let downloadArgs: [String] = [
            "--ignore-errors",
            "--no-playlist",
            "--no-warnings",
            "-f", "bestaudio/best",
            "-o", downloadTemplate,
            "--write-auto-subs",
            "--sub-langs", "ko,en,ja,zh",
            "--sub-format", "vtt",
            "--newline",
            url.absoluteString
        ]

        status = "다운로드 중..."
        let downloadOutput = try await runProcess(
            executable: ytDlp,
            arguments: downloadArgs
        ) { [weak self] line in
            Task { @MainActor in
                self?.status = line.isEmpty ? "다운로드 중..." : line
            }
        }
        if downloadOutput.exitCode != 0 {
            throw URLImportError.downloadFailed(downloadOutput.stderr)
        }

        guard let audioFile = try findAudioFile(in: dir) else {
            throw URLImportError.downloadFailed("다운로드된 오디오 파일을 찾을 수 없습니다.")
        }

        progress = 0.7
        status = "오디오 변환 중..."
        let wavURL = dir.appendingPathComponent("converted.wav")
        let convertOutput = try await runProcess(
            executable: ffmpeg,
            arguments: [
                "-y",
                "-i", audioFile.path,
                "-ac", "1",
                "-ar", "16000",
                "-c:a", "pcm_s16le",
                wavURL.path
            ]
        ) { _ in }
        if convertOutput.exitCode != 0 {
            throw URLImportError.convertFailed(convertOutput.stderr)
        }

        progress = 1.0
        status = "완료"

        let subtitleURL = try findSubtitleFile(in: dir)
        let title = audioFile.deletingPathExtension().lastPathComponent

        return URLImportResult(audioURL: wavURL, title: title, subtitleURL: subtitleURL)
    }

    private struct ProcessOutput {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        onLine: @escaping (String) -> Void
    ) async throws -> ProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdoutBuffer = LineBuffer(onLine: onLine)
            let stderrBuffer = LineBuffer(onLine: onLine)

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { stdoutBuffer.append(data) }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { stderrBuffer.append(data) }
            }

            process.terminationHandler = { p in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                stdoutBuffer.flush()
                stderrBuffer.flush()
                continuation.resume(returning: ProcessOutput(
                    exitCode: p.terminationStatus,
                    stdout: stdoutBuffer.text,
                    stderr: stderrBuffer.text
                ))
            }

            self.currentProcess = process

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func findAudioFile(in dir: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )
        let audioExts: Set<String> = ["m4a", "webm", "mp3", "ogg", "opus", "aac", "wav", "flac"]
        return contents.first { audioExts.contains($0.pathExtension.lowercased()) }
    }

    private func findSubtitleFile(in dir: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )
        return contents.first { ["vtt", "srt"].contains($0.pathExtension.lowercased()) }
    }
}

final class LineBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let onLine: (String) -> Void
    private(set) var text: String = ""

    init(onLine: @escaping (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ data: Data) {
        buffer.append(data)
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[..<newlineIndex]
            buffer.removeSubrange(...newlineIndex)
            if let line = String(data: lineData, encoding: .utf8) {
                text += line + "\n"
                onLine(line)
            }
        }
    }

    func flush() {
        if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) {
            text += line
            onLine(line)
            buffer.removeAll()
        }
    }
}
