import Foundation
import Speech

struct SubtitleCue: Identifiable {
    let id = UUID()
    let start: TimeInterval
    let end: TimeInterval
    let text: String
    var translatedText: String? = nil
}

enum SubtitleError: LocalizedError {
    case unreadable
    case recognitionUnavailable
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadable: return "자막 파일을 읽을 수 없습니다."
        case .recognitionUnavailable: return "이 Mac에서는 음성 인식을 사용할 수 없습니다."
        case .recognitionFailed(let msg): return "음성 인식 실패: \(msg)"
        }
    }
}

@MainActor
final class SubtitleService: ObservableObject {

    @Published var cues: [SubtitleCue] = []
    @Published private(set) var isWorking = false
    @Published private(set) var status: String = ""

    func loadSubtitles(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let ext = url.pathExtension.lowercased()
        let parsed: [SubtitleCue]
        if ext == "vtt" {
            parsed = Self.parseVTT(content)
        } else {
            parsed = Self.parseSRT(content)
        }
        self.cues = parsed
    }

    func transcribe(audioURL: URL, languageCode: String = "ko-KR") async throws {
        // "auto"이거나 비어있으면 기기 기본 언어, 아니면 지정 언어
        let recognizer: SFSpeechRecognizer?
        if languageCode == "auto" {
            // 기기 기본 설정 언어를 사용
            let defaultLocale = Locale.current
            recognizer = SFSpeechRecognizer(locale: defaultLocale) ?? SFSpeechRecognizer()
        } else {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
        }

        guard let finalRecognizer = recognizer else {
            throw SubtitleError.recognitionUnavailable
        }
        guard finalRecognizer.isAvailable else {
            throw SubtitleError.recognitionUnavailable
        }
        guard finalRecognizer.isAvailable else {
            throw SubtitleError.recognitionUnavailable
        }

        isWorking = true
        status = "음성 인식 중..."
        defer { isWorking = false }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { cont in
            var resumed = false
            finalRecognizer.recognitionTask(with: request) { result, error in
                if resumed { return }
                if let error {
                    resumed = true
                    cont.resume(throwing: SubtitleError.recognitionFailed(error.localizedDescription))
                    return
                }
                if let result, result.isFinal {
                    resumed = true
                    cont.resume(returning: result)
                }
            }
        }

        let segments = result.bestTranscription.segments
        self.cues = segments.map { seg in
            SubtitleCue(
                start: seg.timestamp,
                end: seg.timestamp + seg.duration,
                text: seg.substring
            )
        }
        status = "완료"
    }

    static func parseVTT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = content.components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.split(separator: "\n").map(String.init)
            guard let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timeLine = lines[timeLineIndex]
            guard let (start, end) = parseTimeRange(timeLine) else { continue }
            let text = lines[(timeLineIndex + 1)...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                cues.append(SubtitleCue(start: start, end: end, text: text))
            }
        }
        return cues
    }

    static func parseSRT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = content.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.split(separator: "\n").map(String.init)
            guard let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timeLine = lines[timeLineIndex]
            guard let (start, end) = parseTimeRange(timeLine) else { continue }
            let text = lines[(timeLineIndex + 1)...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                cues.append(SubtitleCue(start: start, end: end, text: text))
            }
        }
        return cues
    }

    static func parseTimeRange(_ line: String) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }
        let startStr = parts[0].trimmingCharacters(in: .whitespaces)
        let endStr = parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
        guard let start = parseTimestamp(startStr), let end = parseTimestamp(endStr) else { return nil }
        return (start, end)
    }

    static func parseTimestamp(_ s: String) -> TimeInterval? {
        let normalized = s.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ":").map(String.init)
        guard parts.count >= 2 else { return nil }
        var total: Double = 0
        for (i, p) in parts.enumerated() {
            guard let v = Double(p) else { return nil }
            total += v * pow(60, Double(parts.count - 1 - i))
        }
        return total
    }
}
