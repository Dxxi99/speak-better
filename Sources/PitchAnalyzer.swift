import Foundation
import Accelerate

struct PitchPoint: Identifiable {
    let id = UUID()
    let time: TimeInterval
    let frequency: Double
}

struct PitchTrack {
    let points: [PitchPoint]
    let medianHz: Double
    let minHz: Double
    let maxHz: Double
}

enum PitchError: LocalizedError {
    case emptyAudio
    case analysisFailed

    var errorDescription: String? {
        switch self {
        case .emptyAudio: return "피치를 분석할 샘플이 없습니다."
        case .analysisFailed: return "피치 분석에 실패했습니다."
        }
    }
}

enum PitchAnalyzer {

    static let sampleRate: Double = 16_000
    static let frameSize = 1024
    static let hopSize = 1024          // ← 512 → 1024 (분석 개수 절반, 속도 2배)
    static let minHz: Double = 70
    static let maxHz: Double = 500
    static let silenceRMS: Float = 0.01

    static func analyze(samples: [Float]) throws -> PitchTrack {
        guard samples.count >= frameSize else { throw PitchError.emptyAudio }

        var points: [PitchPoint] = []
        var idx = 0
        while idx + frameSize <= samples.count {
            let frame = Array(samples[idx..<(idx + frameSize)])

            var rms: Float = 0
            vDSP_rmsqv(frame, 1, &rms, vDSP_Length(frame.count))
            let time = Double(idx) / sampleRate

            if rms < silenceRMS {
                points.append(PitchPoint(time: time, frequency: 0))
                idx += hopSize
                continue
            }

            let freq = estimateFrequency(frame: frame)
            points.append(PitchPoint(time: time, frequency: freq))
            idx += hopSize
        }

        let voiced = points.map { $0.frequency }.filter { $0 > 0 }
        let median = medianOf(voiced)
        let minV = voiced.min() ?? 0
        let maxV = voiced.max() ?? 0

        return PitchTrack(points: points, medianHz: median, minHz: minV, maxHz: maxV)
    }

    // autocorrelation을 샘플 4개당 1개로 다운샘플 → 4배 빠름
    private static func estimateFrequency(frame: [Float]) -> Double {
        // 다운샘플 (4:1)
        let factor = 4
        let downLen = frame.count / factor
        var down = [Float](repeating: 0, count: downLen)
        for i in 0..<downLen { down[i] = frame[i * factor] }
        let sr = sampleRate / Double(factor)

        let minLag = max(1, Int(sr / maxHz))
        let maxLag = min(down.count - 1, Int(sr / minHz))
        guard maxLag > minLag else { return 0 }

        var bestLag = minLag
        var bestScore: Float = 0
        // lag 샘플링: 2개씩 건너뜀
        var lag = minLag
        while lag <= maxLag {
            var sum: Float = 0
            let count = down.count - lag
            var i = 0
            while i < count {
                sum += down[i] * down[i + lag]
                i += 2  // 2개당 1개
            }
            sum /= Float(count / 2)
            if sum > bestScore {
                bestScore = sum
                bestLag = lag
            }
            lag += 1
        }

        if bestScore <= 0 { return 0 }

        var rms: Float = 0
        vDSP_rmsqv(down, 1, &rms, vDSP_Length(down.count))
        let normalized = bestScore / max(rms * rms, 1e-6)
        if normalized < 0.2 { return 0 }

        return sr / Double(bestLag)
    }

    private static func medianOf(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 { return (sorted[mid - 1] + sorted[mid]) / 2 }
        return sorted[mid]
    }
}
