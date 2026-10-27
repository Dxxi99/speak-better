import Foundation
import Combine

@MainActor
final class AudioSeparatorService: ObservableObject {
    @Published private(set) var isSeparating = false
    @Published private(set) var status = ""

    func separateVocals(from url: URL) async throws -> URL {
        isSeparating = true
        status = "AI가 목소리를 추출 중입니다..."
        defer { isSeparating = false }

        let possiblePaths = [
            "/opt/homebrew/bin/demucs",
            "/usr/local/bin/demucs",
            "\(NSHomeDirectory())/.pyenv/shims/demucs",
            "\(NSHomeDirectory())/.local/bin/demucs"
        ]
        guard let demucsPath = possiblePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw NSError(domain: "Separator", code: 1, userInfo: [NSLocalizedDescriptionKey: "demucs를 찾을 수 없습니다."])
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("demucs_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: demucsPath)
        process.arguments = ["-n", "htdemucs", "-d", "mps", "--two-stems=vocals", "-o", tempDir.path, url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: data, encoding: .utf8) ?? "알 수 없는 오류"
            throw NSError(domain: "Separator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Demucs 실패: \(errorMsg.prefix(300))"])
        }

        let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent == "vocals.wav" {
                status = "추출 완료"
                return fileURL
            }
        }

        throw NSError(domain: "Separator", code: 3, userInfo: [NSLocalizedDescriptionKey: "분리된 보컬 파일을 찾을 수 없습니다."])
    }
}
