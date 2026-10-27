import SwiftUI

struct WaveformView: View {
    let sequences: [WaveformLayer]
    var playhead: Double? = nil
    var onSeek: ((Double) -> Void)? = nil
    var subtitleRanges: [(start: Double, end: Double)] = []
    var totalDuration: Double? = nil

    struct WaveformLayer: Identifiable {
        let id = UUID()
        let samples: [Float]
        let color: Color
        let label: String
        /// 이 레이어가 전체 시간축에서 차지하는 비율 (0~1). nil이면 전체
        var timeRange: (start: Double, end: Double)? = nil
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // 자막 구간 (파형 뒤)
                drawSubtitleRanges(context: context, size: size)
                drawCenterLine(context: context, size: size)
                for layer in sequences {
                    drawWaveform(layer: layer, context: context, size: size)
                }
                if let playhead {
                    drawPlayhead(playhead, context: context, size: size)
                }
            }
            .background(DS.ColorToken.parchment.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.ColorToken.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(1, value.location.x / geometry.size.width))
                        onSeek?(Double(ratio))
                    }
            )
        }
        .frame(minHeight: 140)
    }

    private func drawSubtitleRanges(context: GraphicsContext, size: CGSize) {
        guard !subtitleRanges.isEmpty, let total = totalDuration, total > 0 else { return }
        for (i, range) in subtitleRanges.enumerated() {
            let x1 = size.width * CGFloat(range.start / total)
            let x2 = size.width * CGFloat(range.end / total)
            let rect = CGRect(x: x1, y: 0, width: max(1, x2 - x1), height: size.height)
            // 짝수/홀수 교차 색상으로 자막 구간 구분
            let color = i % 2 == 0
                ? DS.ColorToken.primary.opacity(0.12)
                : DS.ColorToken.primary.opacity(0.06)
            context.fill(Path(rect), with: .color(color))
            // 왼쪽 경계선 (자막 시작)
            var linePath = Path()
            linePath.move(to: CGPoint(x: x1, y: 0))
            linePath.addLine(to: CGPoint(x: x1, y: size.height))
            context.stroke(linePath, with: .color(DS.ColorToken.primary.opacity(0.3)), lineWidth: 0.5)
        }
    }

    private func drawCenterLine(context: GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(path, with: .color(DS.ColorToken.hairline), lineWidth: 1)
    }

    private func drawWaveform(layer: WaveformLayer, context: GraphicsContext, size: CGSize) {
        guard !layer.samples.isEmpty else { return }

        let startX = layer.timeRange.map { CGFloat($0.start) * size.width } ?? 0
        let endX = layer.timeRange.map { CGFloat($0.end) * size.width } ?? size.width
        let width = endX - startX

        let count = layer.samples.count
        let stepX = width / CGFloat(max(count - 1, 1))
        let midY = size.height / 2
        let halfHeight = size.height / 2 * 0.9

        var path = Path()
        for (i, sample) in layer.samples.enumerated() {
            let x = startX + CGFloat(i) * stepX
            let amplitude = CGFloat(min(max(sample, 0), 1))
            let topY = midY - amplitude * halfHeight
            let bottomY = midY + amplitude * halfHeight

            if i == 0 {
                path.move(to: CGPoint(x: x, y: topY))
            } else {
                path.addLine(to: CGPoint(x: x, y: topY))
            }
            path.move(to: CGPoint(x: x, y: bottomY))
            path.addLine(to: CGPoint(x: x, y: topY))
        }

        context.stroke(path, with: .color(layer.color), lineWidth: max(1.0, stepX))
    }

    private func drawPlayhead(_ progress: Double, context: GraphicsContext, size: CGSize) {
        let x = size.width * CGFloat(min(max(progress, 0), 1))
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(path, with: .color(DS.ColorToken.primary), lineWidth: 1.5)
    }
}
