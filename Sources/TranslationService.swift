import Foundation
import Combine

@MainActor
final class TranslationService: ObservableObject {
    @Published private(set) var isTranslating = false
    @Published private(set) var status: String = ""

    func translate(cues: [SubtitleCue], targetLanguageCode: String) async -> [SubtitleCue] {
        guard !cues.isEmpty else { return cues }
        isTranslating = true
        status = "번역 중..."
        defer { isTranslating = false }

        let cliPaths = ["/opt/homebrew/bin/llama-cli", "/usr/local/bin/llama-cli"]
        guard let cliPath = cliPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            print("❌ [번역] llama-cli를 찾을 수 없습니다.")
            return cues
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelPath = appSupport.appendingPathComponent("AudioRepeatMVP/qwen2.5-3b-instruct-q4_k_m.gguf").path
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("❌ [번역] 번역 모델 파일이 없습니다.")
            return cues
        }

        let langName: String
        switch targetLanguageCode {
        case "ko": langName = "Korean"
        case "en": langName = "English"
        case "ja": langName = "Japanese"
        case "zh": langName = "Chinese"
        default: langName = "Korean"
        }

        var numberedLines: [String] = []
        for (i, cue) in cues.enumerated() {
            numberedLines.append("\(i + 1). \(cue.text)")
        }
        let combined = numberedLines.joined(separator: "\n")

        let prompt = """
        You are a professional subtitle translator for anime/drama.
        Translate each numbered line into natural \(langName), preserving emotion and informal tone.
        Do not translate literally. Use natural spoken \(langName).
        Output exactly one line per input line, prefixed with the same number and a dot.
        No explanations, no extra text.

        \(combined)

        Translation:
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = [
            "-m", modelPath,
            "-p", prompt,
            "-n", "2048",
            "--temp", "0.3",
            "-no-cnv",
            "-t", "8",
            "-ngl", "99"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            print("🔄 [번역] llama-cli 실행 시작...")
            try process.run()
            process.waitUntilExit()
            print("✅ [번역] llama-cli 종료. 상태: \(process.terminationStatus)")

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return cues }

            var translated: [String: String] = [:]
            for line in output.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.split(separator: ".", maxSplits: 1)
                if parts.count == 2, let idx = Int(parts[0].trimmingCharacters(in: .whitespaces)) {
                    let text = parts[1].trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        translated["\(idx)"] = text
                    }
                }
            }

            var result = cues
            for i in 0..<result.count {
                if let t = translated["\(i + 1)"] {
                    result[i].translatedText = t
                }
            }

            print("✅ [번역] 성공적으로 번역된 줄: \(translated.count)/\(cues.count)")
            status = "번역 완료 (\(translated.count)개)"
            return result
        } catch {
            print("❌ [번역] LLM 실행 에러: \(error.localizedDescription)")
            return cues
        }
    }
}
