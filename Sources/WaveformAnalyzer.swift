import Foundation
import AVFoundation
import Accelerate

struct WaveformData {
    let samples: [Float]
    let duration: TimeInterval
    let sampleRate: Double
}

struct AudioMetrics {
    let duration: TimeInterval
    let peakAmplitude: Float
    let rmsLevel: Float
    let silenceRatio: Double
    let estimatedSpeechDuration: TimeInterval
}

struct WaveformAnalysis {
    let waveform: WaveformData
    let metrics: AudioMetrics
}

enum WaveformError: LocalizedError {
    case cannotOpenFile
    case emptyAudio
    case converterFailed

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile: return "오디오 파일을 열 수 없습니다."
        case .emptyAudio: return "오디오에 유효한 샘플이 없습니다."
        case .converterFailed: return "오디오 포맷 변환에 실패했습니다."
        }
    }
}

enum WaveformAnalyzer {

    static let targetWaveformPoints = 1200
    static let silenceRMSThreshold: Float = 0.01

    static func analyze(from url: URL) throws -> WaveformAnalysis {
        let samples = try decodeMono16k(url: url)
        guard !samples.isEmpty else { throw WaveformError.emptyAudio }

        let sampleRate = 16_000.0
        let duration = Double(samples.count) / sampleRate

        let downsampled = downsample(samples, targetCount: targetWaveformPoints)

        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))

        var meanSquare: Float = 0
        vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(samples.count))
        let rms = sqrt(meanSquare)

        let windowSize = Int(0.1 * sampleRate)
        var silentWindows = 0
        var totalWindows = 0
        var start = 0
        while start + windowSize <= samples.count {
            var windowRMS: Float = 0
            samples.withUnsafeBufferPointer { buf in
                vDSP_rmsqv(buf.baseAddress! + start, 1, &windowRMS, vDSP_Length(windowSize))
            }
            if windowRMS < silenceRMSThreshold { silentWindows += 1 }
            totalWindows += 1
            start += windowSize
        }

        let silenceRatio = totalWindows > 0 ? Double(silentWindows) / Double(totalWindows) : 0
        let speechDuration = duration * (1 - silenceRatio)

        let metrics = AudioMetrics(
            duration: duration,
            peakAmplitude: peak,
            rmsLevel: rms,
            silenceRatio: silenceRatio,
            estimatedSpeechDuration: speechDuration
        )

        let waveform = WaveformData(
            samples: downsampled,
            duration: duration,
            sampleRate: sampleRate
        )

        return WaveformAnalysis(waveform: waveform, metrics: metrics)
    }

    private static func decodeMono16k(url: URL) throws -> [Float] {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw WaveformError.cannotOpenFile
        }

        let sourceFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw WaveformError.converterFailed
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw WaveformError.converterFailed
        }

        let sourceFrameCount = AVAudioFrameCount(file.length)
        guard sourceFrameCount > 0 else { throw WaveformError.emptyAudio }

        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: sourceFrameCount
        ) else {
            throw WaveformError.converterFailed
        }

        try file.read(into: sourceBuffer)

        let ratio = 16_000.0 / sourceFormat.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(sourceFrameCount) * ratio) + 1024

        guard let targetBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: targetCapacity
        ) else {
            throw WaveformError.converterFailed
        }

        var conversionError: NSError?
        var supplied = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if supplied {
                outStatus.pointee = .endOfStream
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        converter.convert(to: targetBuffer, error: &conversionError, withInputFrom: inputBlock)

        if let conversionError { throw conversionError }

        guard let channelData = targetBuffer.floatChannelData?[0] else {
            throw WaveformError.emptyAudio
        }

        let count = Int(targetBuffer.frameLength)
        guard count > 0 else { throw WaveformError.emptyAudio }

        return Array(UnsafeBufferPointer(start: channelData, count: count))
    }

    private static func downsample(_ samples: [Float], targetCount: Int) -> [Float] {
        guard samples.count > targetCount, targetCount > 0 else { return samples }

        let bucketSize = samples.count / targetCount
        guard bucketSize > 0 else { return samples }

        var result = [Float](repeating: 0, count: targetCount)
        for i in 0..<targetCount {
            let start = i * bucketSize
            let end = min(start + bucketSize, samples.count)
            var peak: Float = 0
            for j in start..<end {
                let v = abs(samples[j])
                if v > peak { peak = v }
            }
            result[i] = peak
        }
        return result
    }
}
