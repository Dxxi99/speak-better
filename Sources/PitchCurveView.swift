import SwiftUI

struct PitchCurveView: View {
    let track: PitchTrack
    var recordingTrack: PitchTrack? = nil
    var playhead: Double? = nil
    var totalDuration: Double? = nil

    // 자막별 피치 미니 그래프용 (전체 곡선 대신 이 구간만)
    var rangeStart: Double? = nil
    var rangeEnd: Double? = nil

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let allVoiced = track.points.map { $0.frequency }.filter { $0 > 0 }
                    + (recordingTrack?.points.map { $0.frequency }.filter { $0 > 0 } ?? [])
                guard !allVoiced.isEmpty else { return }
                let rawMin = allVoiced.min()!
                let rawMax = allVoiced.max()!
                let minFreq = max(0, rawMin * 0.85)
                let maxFreq = rawMax * 1.15

                for i in 1...3 {
                    let y = size.height * CGFloat(i) / 4
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(DS.ColorToken.hairline.opacity(0.5)), lineWidth: 0.5)
                }

                // 구간 지정이 있으면 그 구간만 x축으로 펼침
                let useRange = rangeStart != nil && rangeEnd != nil
                let tStart = rangeStart ?? 0
                let tEnd = rangeEnd ?? (totalDuration ?? max(track.points.last?.time ?? 0, 0.001))
                let span = max(tEnd - tStart, 0.001)

                drawPitch(track: track, context: context, size: size, color: DS.ColorToken.primary, minFreq: minFreq, maxFreq: maxFreq, tStart: useRange ? tStart : 0, tEnd: useRange ? tEnd : (totalDuration ?? max(track.points.last?.time ?? 0, 0.001)))

                if let rec = recordingTrack {
                    drawPitch(track: rec, context: context, size: size, color: .yellow, minFreq: minFreq, maxFreq: maxFreq, tStart: useRange ? tStart : 0, tEnd: useRange ? tEnd : (totalDuration ?? max(rec.points.last?.time ?? 0, 0.001)))
                }

                if let ph = playhead, ph >= 0, ph <= 1 {
                    let x = size.width * CGFloat(min(max(ph, 0), 1))
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(line, with: .color(.yellow), lineWidth: 1.5)
                }
            }
            .background(DS.ColorToken.parchment.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    private func drawPitch(track: PitchTrack, context: GraphicsContext, size: CGSize, color: Color, minFreq: Double, maxFreq: Double, tStart: Double, tEnd: Double) {
        let span = max(tEnd - tStart, 0.001)
        var path = Path()
        var started = false

        for p in track.points {
            if p.time < tStart { continue }
            if p.time > tEnd { break }
            let x = size.width * CGFloat((p.time - tStart) / span)
            if p.frequency <= 0 {
                started = false
                continue
            }
            let normalized = (p.frequency - minFreq) / max(maxFreq - minFreq, 1)
            let y = size.height * (0.92 - CGFloat(normalized) * 0.84)

            if !started {
                path.move(to: CGPoint(x: x, y: y))
                started = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}
