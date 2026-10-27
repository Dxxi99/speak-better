import Foundation
import Accelerate

struct RhythmAnalysis {
    let syllableRate: Double
    let stressTimes: [Double]
    let intonationTrend: String
}

enum RhythmAnalyzer {

    static func analyze(samples: [Float], pitchTrack: PitchTrack?, sampleRate: Double = 16_000) -> RhythmAnalysis? {
        guard !samples.isEmpty else { return nil }
        let duration = Double(samples.count) / sampleRate
        guard duration > 0.1 else { return nil }

        // 음량 피크(강세) 추출
        let window = Int(0.03 * sampleRate)
        var rmsValues: [(time: Double, rms: Float)] = []
        var idx = 0
        while idx + window <= samples.count {
            var rms: Float = 0
            samples.withUnsafeBufferPointer { buf in
                vDSP_rmsqv(buf.baseAddress! + idx, 1, &rms, vDSP_Length(window))
            }
            rmsValues.append((Double(idx) / sampleRate, rms))
            idx += window
        }
        guard !rmsValues.isEmpty else { return nil }

        let avgRMS = rmsValues.map { $0.rms }.reduce(0, +) / Float(rmsValues.count)
        let threshold = avgRMS * 1.1

        var stressTimes: [Double] = []
        for i in 1..<(rmsValues.count - 1) {
            let r = rmsValues[i].rms
            if r > threshold && r > rmsValues[i-1].rms && r > rmsValues[i+1].rms {
                if let last = stressTimes.last, rmsValues[i].time - last < 0.1 { continue }
                stressTimes.append(rmsValues[i].time)
            }
        }

        let estimatedSyllables = Double(stressTimes.count) * 1.5
        let syllableRate = estimatedSyllables / duration

        var trend = "평탄"
        if let track = pitchTrack {
            let voiced = track.points.filter { $0.frequency > 0 }
            if voiced.count >= 10 {
                let firstThird = voiced.prefix(voiced.count / 3).map { $0.frequency }
                let lastThird = voiced.suffix(voiced.count / 3).map { $0.frequency }
                let firstAvg = firstThird.reduce(0, +) / Double(firstThird.count)
                let lastAvg = lastThird.reduce(0, +) / Double(lastThird.count)
                let diff = (lastAvg - firstAvg) / max(firstAvg, 1)
                if diff > 0.1 { trend = "올라감" }
                else if diff < -0.1 { trend = "내려감" }
            }
        }

        return RhythmAnalysis(
            syllableRate: syllableRate,
            stressTimes: stressTimes,
            intonationTrend: trend
        )
    }

    /// 특정 구간만 분석 (자막 한 개에 대응)
    static func analyzeSegment(
        samples: [Float],
        pitchTrack: PitchTrack?,
        start: TimeInterval,
        end: TimeInterval,
        sampleRate: Double = 16_000
    ) -> RhythmAnalysis? {
        let startIdx = max(0, Int(start * sampleRate))
        let endIdx = min(samples.count, Int(end * sampleRate))
        guard endIdx > startIdx + 1 else { return nil }
        let segment = Array(samples[startIdx..<endIdx])

        let segmentPitch: PitchTrack?
        if let track = pitchTrack {
            let points = track.points.filter { $0.time >= start && $0.time < end }
            let voiced = points.map { $0.frequency }.filter { $0 > 0 }
            let median = voiced.isEmpty ? 0 : voiced.sorted()[voicesCountHalf(voiced)]
            segmentPitch = PitchTrack(
                points: points,
                medianHz: median,
                minHz: voiced.min() ?? 0,
                maxHz: voiced.max() ?? 0
            )
        } else {
            segmentPitch = nil
        }

        // 상대 시간으로 변환
        let relative = analyze(samples: segment, pitchTrack: segmentPitch, sampleRate: sampleRate)
        guard let base = relative else { return nil }
        let shiftedStress = base.stressTimes.map { $0 + start }
        return RhythmAnalysis(
            syllableRate: base.syllableRate,
            stressTimes: shiftedStress,
            intonationTrend: base.intonationTrend
        )
    }

    private static func voicesCountHalf(_ arr: [Double]) -> Int {
        arr.count / 2
    }
}
