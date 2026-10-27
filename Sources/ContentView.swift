import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import Translation

struct ContentView: View {
    @StateObject private var playback = AudioPlaybackManager()
    @StateObject private var recorder = AudioRecorderManager()
    @StateObject private var urlImporter = URLImportService()
    @StateObject private var subtitleService = SubtitleService()
    @StateObject private var whisperService = WhisperService()

    @State private var originalURL: URL?
    @State private var originalName: String = ""
    @State private var isImporterPresented = false
    @State private var urlField: String = ""
    @State private var isImportingURL = false
    @State private var isDropTargeted = false

    @State private var originalAnalysis: WaveformAnalysis?
    @State private var recordingAnalysis: WaveformAnalysis?
    @State private var pitchTrack: PitchTrack?
    @State private var recordingPitchTrack: PitchTrack?
    @State private var isAnalyzing = false
    @State private var showOverlay = true

    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var translatedCues: [SubtitleCue] = []
    @State private var translationConfig: TranslationSession.Configuration? = nil
    @State private var originalRhythm: RhythmAnalysis?
    @State private var recordingRhythm: RhythmAnalysis?
    @State private var cueRhythms: [UUID: RhythmAnalysis] = [:]
    @State private var countdown: Int? = nil

    // 새 기능
    @State private var recentItems: [RecentItem] = []
    @State private var comparisonScore: Double? = nil
    @State private var cueSimilarities: [UUID: Double] = [:]
    @State private var waveformSimilarity: Double? = nil
    @State private var pitchSimilarity: Double? = nil
    @State private var showExporter = false
    @State private var exportURL: URL? = nil
    @State private var rateIndex: Int = 2  // 0.5, 0.75, 1.0, 1.25, 1.5, 2.0
    let rates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    private let audioTypes: [UTType] = [.audio, .wav, .mp3, .mpeg4Audio]

    var body: some View {
        ZStack {
            Color(hex: 0xf5f5f7).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 22) {
                            Color.clear.frame(height: 0).id("top")
                            heroSection
                            recentSection
                            contentSection
                        }
                        .padding(.vertical, 24)
                    }
                    .onChange(of: originalURL) { _, _ in
                        withAnimation { proxy.scrollTo("top", anchor: .top) }
                    }
                }
            }

            if isDropTargeted {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(DS.ColorToken.primary, style: StrokeStyle(lineWidth: 4, dash: [10]))
                    .background(DS.ColorToken.primary.opacity(0.08))
                    .padding(40)
                    .allowsHitTesting(false)
            }
        }
        .background(GlobalKeyHandler(
            onSpace: { playback.isPlaying ? playback.pause() : playback.play() },
            onLeft: { playback.seek(to: max(0, playback.currentTime - 5)) },
            onRight: { playback.seek(to: min(playback.duration, playback.currentTime + 5)) }
        ).frame(width: 0, height: 0))
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: audioTypes, allowsMultipleSelection: false) { handleImport($0) }
        .fileExporter(isPresented: $showExporter, document: exportURL.map { RecordingFileDocument(url: $0) }, contentType: .audio, defaultFilename: "recording.wav") { _ in }
        .alert("알림", isPresented: $showAlert) { Button("확인", role: .cancel) {} } message: { Text(alertMessage ?? "") }
        .overlay(countdownOverlay)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .onAppear {
            recentItems = AppSettings.loadRecent()
        }
        .translationTask(translationConfig) { session in
            var newCues: [SubtitleCue] = []
            for cue in whisperService.cues {
                do {
                    let r = try await session.translate(cue.text)
                    var n = cue; n.translatedText = r.targetText; newCues.append(n)
                } catch { newCues.append(cue) }
            }
            self.translatedCues = newCues
        }
    }

    // MARK: - top bar
    private var topBar: some View {
        HStack {
            Text("너는 생각보다 언어를 잘한다")
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.12)
                .foregroundStyle(DS.ColorToken.onDark)
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(height: 44)
        .background(DS.ColorToken.surfaceBlack)
    }

    // MARK: - hero
    private var heroSection: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("영상 링크를 붙여넣으세요")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(DS.ColorToken.ink)
                Text("자막 · 번역 · 파형 · 피치 · 리듬")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.ColorToken.inkMuted48)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.ColorToken.inkMuted48)
                    TextField("https://...", text: $urlField)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(DS.ColorToken.ink)
                        .disabled(isImportingURL)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DS.ColorToken.canvas)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                )
                .frame(maxWidth: 480)

                Button(isImportingURL ? "..." : "가져오기") { runURLImport() }
                    .buttonStyle(ApplePrimaryButtonStyle())
                    .disabled(isImportingURL || urlField.isEmpty)

                Button { isImporterPresented = true } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.ColorToken.ink)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DS.ColorToken.canvas)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }

            if !originalName.isEmpty {
                Text(originalName)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.ColorToken.inkMuted48)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32).padding(.horizontal, 28)
        .background(DS.ColorToken.canvas, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 28)
        .frame(maxWidth: 960)
    }

    // MARK: - 최근 사용
    @ViewBuilder
    private var recentSection: some View {
        if !recentItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("최근 사용")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.ink)
                    Spacer()
                    Button("전체 삭제") {
                        AppSettings.clearRecent()
                        recentItems = []
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(DS.ColorToken.inkMuted48)
                    .buttonStyle(.plain)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentItems.prefix(8)) { item in
                            Button {
                                urlField = item.url
                                runURLImport()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(DS.ColorToken.ink)
                                        .lineLimit(1).truncationMode(.middle)
                                        .frame(maxWidth: 160, alignment: .leading)
                                    Text(item.url).font(.system(size: 9))
                                        .foregroundStyle(DS.ColorToken.inkMuted48)
                                        .lineLimit(1).truncationMode(.middle)
                                        .frame(maxWidth: 160, alignment: .leading)
                                }
                                .padding(.vertical, 8).padding(.horizontal, 12)
                                .background(DS.ColorToken.canvas, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 28).frame(maxWidth: 960)
        }
    }

    // MARK: - content
    private var contentSection: some View {
        VStack(spacing: 18) {
            playerCard
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) { waveformCard; pitchCard }
                VStack(spacing: 18) { waveformCard; pitchCard }
            }
            subtitleCard
        }
        .padding(.horizontal, 28).frame(maxWidth: 960).frame(maxWidth: .infinity)
    }

    // MARK: - Play
    private var playerCard: some View {
        VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Play").font(.system(size: 28, weight: .semibold)).tracking(-0.3).foregroundStyle(.white)
                Spacer()
                if let start = playback.loopStart, let end = playback.loopEnd {
                    Text("자막 반복: \(formatTime(start)) – \(formatTime(end))")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                        .padding(.vertical, 4).padding(.horizontal, 10)
                        .background(Color.white.opacity(0.2), in: Capsule())
                }
            }

            HStack(spacing: 12) {
                Button { playback.isPlaying ? playback.pause() : playback.play() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(playback.isPlaying ? "일시정지" : "재생").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(DS.ColorToken.onPrimary)
                    .padding(.vertical, 10).padding(.horizontal, 20)
                    .background(DS.ColorToken.primary, in: Capsule())
                    .shadow(color: DS.ColorToken.primary.opacity(0.4), radius: 12, x: 0, y: 4)
                }.buttonStyle(.plain).disabled(originalURL == nil)

                // 속도 버튼
                Button {
                    rateIndex = (rateIndex + 1) % rates.count
                    playback.rate = rates[rateIndex]
                } label: {
                    Text("\(String(format: "%.2g", rates[rateIndex]))x")
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(Color.white.opacity(0.15), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.6))
                }.buttonStyle(.plain).disabled(originalURL == nil)

                Spacer()

                if recorder.isRecording {
                    HStack(spacing: 8) {
                        Button("중지") { recorder.stopRecording(); analyzeRecording() }.buttonStyle(ApplePrimaryButtonStyle())
                        Text("● \(formatTime(recorder.recordingTime))").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).monospacedDigit()
                    }
                } else {
                    Button { startCountdownRecording() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "record.circle").font(.system(size: 13, weight: .semibold))
                            Text("녹음").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(DS.ColorToken.onPrimary)
                        .padding(.vertical, 10).padding(.horizontal, 20)
                        .background(DS.ColorToken.primary, in: Capsule())
                        .shadow(color: DS.ColorToken.primary.opacity(0.4), radius: 12, x: 0, y: 4)
                    }.buttonStyle(.plain).disabled(originalURL == nil)
                }
            }

            if let score = comparisonScore {
                HStack(spacing: 8) {
                    Text("점수").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                    Text("\(Int(score.rounded())) / 100").font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(score >= 75 ? Color.green : score >= 50 ? Color.orange : Color.red)
                    Text(scoreComment(score)).font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if originalURL != nil {
                if recorder.lastRecordingURL != nil {
                    VStack(spacing: 10) {
                        volumeRow(label: "원본", color: Color(hex: 0x2997ff), value: Binding(
                            get: { Double(playback.primaryVolume) },
                            set: { playback.primaryVolume = Float($0) }
                        ))
                        volumeRow(label: "녹음", color: .orange, value: Binding(
                            get: { Double(playback.secondaryVolume) },
                            set: { playback.secondaryVolume = Float($0) }
                        ))
                        HStack(spacing: 8) {
                            Button("녹음 내보내기") {
                                if let url = recorder.lastRecordingURL { exportURL = url; showExporter = true }
                            }.buttonStyle(ApplePearlCapsuleStyle())
                            Spacer()
                        }
                    }
                }

                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15)).frame(height: 4)
                            Capsule().fill(Color(hex: 0x2997ff))
                                .frame(width: geo.size.width * CGFloat(playback.currentTime / max(playback.duration, 0.001)), height: 4)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                            let ratio = max(0, min(1, v.location.x / geo.size.width))
                            playback.seek(to: playback.duration * Double(ratio))
                        })
                    }.frame(height: 16)
                    HStack {
                        Text(formatTime(playback.currentTime)).font(.system(size: 11)).monospacedDigit().foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(formatTime(playback.duration)).font(.system(size: 11)).monospacedDigit().foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(22)
        .background(DS.ColorToken.tile1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 6)
    }

    private func volumeRow(label: String, color: Color, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7)).frame(width: 32, alignment: .leading)
            Slider(value: value, in: 0...1).tint(color)
        }
    }

    // MARK: - Waveform
    private var waveformCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Waveform").font(.system(size: 14, weight: .semibold)).tracking(-0.2).foregroundStyle(DS.ColorToken.ink)
                Spacer()
                if let score = waveformSimilarity {
                    Text("유사도 \(Int(score.rounded()))%").font(.system(size: 11, weight: .semibold)).foregroundStyle(scoreColor(score))
                }
            }
            WaveformView(
                sequences: overlayWaveLayers,
                playhead: playheadProgress,
                onSeek: { ratio in playback.seek(to: playback.duration * ratio) },
                subtitleRanges: (translatedCues.isEmpty ? whisperService.cues : translatedCues).map { ($0.start, $0.end) },
                totalDuration: playback.duration
            ).frame(height: 110)

            HStack(spacing: 12) {
                legend(color: DS.ColorToken.primary, "원본")
                if recordingAnalysis != nil { legend(color: .yellow, "내 녹음") }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(DS.ColorToken.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.black.opacity(0.07), lineWidth: 1))
    }

    private var overlayWaveLayers: [WaveformView.WaveformLayer] {
        var layers: [WaveformView.WaveformLayer] = []
        if let a = originalAnalysis {
            layers.append(WaveformView.WaveformLayer(samples: a.waveform.samples, color: DS.ColorToken.primary.opacity(0.7), label: "원본"))
        }
        if let b = recordingAnalysis, playback.duration > 0 {
            // 녹음한 구간에만 노란색 파형을 그림
            if let recStart = playback.loopStart, let recEnd = playback.loopEnd {
                let startRatio = max(0, min(1, recStart / playback.duration))
                let endRatio = max(0, min(1, recEnd / playback.duration))
                layers.append(WaveformView.WaveformLayer(
                    samples: b.waveform.samples,
                    color: .orange,
                    label: "내 녹음",
                    timeRange: (startRatio, endRatio)
                ))
            } else {
                // 자막 반복 구간이 없으면 전체 길이에 맞춰 표시
                layers.append(WaveformView.WaveformLayer(
                    samples: b.waveform.samples,
                    color: .orange,
                    label: "내 녹음"
                ))
            }
        }
        return layers
    }

    private var originalWaveLayer: [WaveformView.WaveformLayer] {
        if let a = originalAnalysis {
            return [WaveformView.WaveformLayer(samples: a.waveform.samples, color: DS.ColorToken.primary, label: "원본")]
        }
        return []
    }

    private var recordingWaveLayer: [WaveformView.WaveformLayer] {
        if let b = recordingAnalysis {
            return [WaveformView.WaveformLayer(samples: b.waveform.samples, color: .orange, label: "녹음")]
        }
        return []
    }

    // MARK: - Pitch (전체)
    private var pitchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pitch").font(.system(size: 14, weight: .semibold)).tracking(-0.2).foregroundStyle(DS.ColorToken.ink)
                Spacer()
                if let score = pitchSimilarity {
                    Text("유사도 \(Int(score.rounded()))%").font(.system(size: 11, weight: .semibold)).foregroundStyle(scoreColor(score))
                } else if let track = pitchTrack, !track.points.isEmpty {
                    Text("\(Int(track.medianHz)) Hz").font(.system(size: 11, weight: .medium)).foregroundStyle(DS.ColorToken.inkMuted48)
                }
            }
            if let track = pitchTrack, !track.points.isEmpty {
                PitchCurveView(track: track, recordingTrack: recordingPitchTrack, playhead: playheadProgress, totalDuration: playback.duration)
                    .frame(height: 110)
                HStack(spacing: 12) {
                    legend(color: DS.ColorToken.primary, "원본")
                    if recordingPitchTrack != nil { legend(color: .yellow, "내 녹음") }
                }
            } else {
                Spacer().frame(minHeight: 110)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(DS.ColorToken.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.black.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Subtitle (자막별 피치 오른쪽)
    private var subtitleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("자막").font(.system(size: 14, weight: .semibold)).tracking(-0.2).foregroundStyle(DS.ColorToken.ink)
                Text("한국어").font(.system(size: 10)).foregroundStyle(DS.ColorToken.inkMuted48)
                Spacer()
                let active = !translatedCues.isEmpty ? translatedCues : whisperService.cues
                if !active.isEmpty {
                    Text("\(active.count)").font(.system(size: 10)).foregroundStyle(DS.ColorToken.inkMuted48)
                }
            }

            let activeCues = !translatedCues.isEmpty ? translatedCues : whisperService.cues
            if activeCues.isEmpty {
                Text("자막이 아직 없습니다").font(.system(size: 11)).foregroundStyle(DS.ColorToken.inkMuted48)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(activeCues.enumerated()), id: \.element.id) { index, cue in
                            subtitleRow(cue: cue, isLast: index == activeCues.count - 1)
                        }
                    }
                }.frame(maxHeight: 380)
            }
        }
        .padding(16)
        .background(DS.ColorToken.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.black.opacity(0.07), lineWidth: 1))
    }

    @ViewBuilder
    private func subtitleRow(cue: SubtitleCue, isLast: Bool) -> some View {
        let isActive = playback.currentTime >= cue.start && playback.currentTime < cue.end
        let isLoop = playback.loopStart == cue.start && playback.loopEnd == cue.end
        let bg: Color = isLoop
            ? DS.ColorToken.primary.opacity(0.10)
            : (isActive ? DS.ColorToken.primary.opacity(0.04) : Color.clear)

        Button {
            if isLoop {
                playback.clearLoopRegion()
                playback.seek(to: cue.start)
            } else {
                playback.loopStart = cue.start
                playback.loopEnd = cue.end
                playback.seek(to: cue.start)
                if !playback.isPlaying { playback.play() }
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text(formatTime(cue.start))
                    .font(.system(size: 10, weight: .medium)).monospacedDigit()
                    .foregroundStyle(DS.ColorToken.inkMuted48)
                    .frame(width: 34, alignment: .leading)

                subtitleTextStack(cue: cue, isLoop: isLoop)

                subtitleRecordingPreview(cue: cue, isActive: isActive || isLoop)
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(bg)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(DS.ColorToken.hairline.opacity(0.5)).frame(height: 0.5).padding(.horizontal, 12)
                }
            }
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private func subtitleTextStack(cue: SubtitleCue, isLoop: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(cue.text)
                .font(.system(size: 14, weight: isLoop ? .semibold : .regular))
                .foregroundStyle(DS.ColorToken.ink)
                .multilineTextAlignment(.leading)
            if let trans = cue.translatedText, !trans.isEmpty, trans != cue.text {
                Text(trans)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.ColorToken.inkMuted48)
                    .multilineTextAlignment(.leading)
            }
            if let rhythm = cueRhythms[cue.id] {
                cueRhythmView(rhythm: rhythm, cue: cue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func subtitleRecordingPreview(cue: SubtitleCue, isActive: Bool) -> some View {
        if let recAnalysis = recordingAnalysis, let recPitch = recordingPitchTrack {
            let recDuration = recAnalysis.metrics.duration
            let cueSpan = max(cue.end - cue.start, 0.001)
            // 자막 하나 녹음했다고 가정: 녹음 전체를 자막 하나 구간으로 매핑
            // (녹음이 자막 하나만 담고 있으면 recDuration ≈ cueSpan)
            let useStart = cue.start
            let useEnd = cue.end

            VStack(alignment: .trailing, spacing: 3) {
                WaveformView(
                    sequences: [WaveformView.WaveformLayer(samples: recAnalysis.waveform.samples, color: .orange, label: "녹음")],
                    playhead: nil,
                    onSeek: nil,
                    subtitleRanges: [],
                    totalDuration: recDuration
                )
                .frame(width: 70, height: 24)
                .opacity(isActive ? 1.0 : 0.6)
                .background(DS.ColorToken.parchment.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))

                PitchCurveView(
                    track: recPitch,
                    recordingTrack: nil,
                    playhead: nil,
                    totalDuration: recDuration,
                    rangeStart: 0,
                    rangeEnd: recDuration
                )
                .frame(width: 70, height: 20)
                .opacity(isActive ? 1.0 : 0.6)
                .background(DS.ColorToken.parchment.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))

                if let score = cueSimilarities[cue.id] {
                    Text("\(Int(score.rounded()))%")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(scoreColor(score))
                }
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - helpers & actions (기존과 동일)

    private func cueRhythmView(rhythm: RhythmAnalysis, cue: SubtitleCue) -> some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(DS.ColorToken.hairline.opacity(0.4)).frame(height: 1).frame(maxHeight: .infinity, alignment: .center)
                    ForEach(rhythm.stressTimes, id: \.self) { t in
                        let ratio = (t - cue.start) / max(cue.end - cue.start, 0.001)
                        let x = geo.size.width * CGFloat(min(max(ratio, 0), 1))
                        Circle().fill(DS.ColorToken.primary).frame(width: 4, height: 4).offset(x: x - 2, y: 5)
                    }
                }
            }.frame(width: 90, height: 14)
            Text(rhythm.intonationTrend).font(.system(size: 10)).foregroundStyle(DS.ColorToken.inkMuted48)
        }.padding(.top, 2)
    }

    private func legend(color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 10)).foregroundStyle(DS.ColorToken.inkMuted80)
        }
    }

    private var countdownOverlay: some View {
        Group {
            if let count = countdown {
                VStack {
                    Spacer()
                    Text("\(count)").font(.system(size: 120, weight: .bold, design: .rounded)).foregroundStyle(DS.ColorToken.primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.4)).ignoresSafeArea()
            }
        }
    }

    private var playheadProgress: Double? {
        guard originalURL != nil, playback.duration > 0 else { return nil }
        return playback.currentTime / playback.duration
    }

    private func backgroundColorFor(cue: SubtitleCue) -> Color {
        if playback.loopStart == cue.start && playback.loopEnd == cue.end { return DS.ColorToken.primary.opacity(0.10) }
        let t = playback.currentTime
        if t >= cue.start && t < cue.end { return DS.ColorToken.primary.opacity(0.04) }
        return Color.clear
    }

    private func scoreComment(_ score: Double) -> String {
        switch score {
        case 85...: return "매우 비슷"
        case 70..<85: return "꽤 비슷"
        case 50..<70: return "조금 다름"
        default: return "많이 다름"
        }
    }

    private func buildLayers() -> [WaveformView.WaveformLayer] {
        if showOverlay, let a = originalAnalysis, let b = recordingAnalysis {
            let target = max(a.waveform.samples.count, b.waveform.samples.count)
            return [
                WaveformView.WaveformLayer(samples: resample(a.waveform.samples, to: target), color: DS.ColorToken.primary.opacity(0.65), label: "원본"),
                WaveformView.WaveformLayer(samples: resample(b.waveform.samples, to: target), color: Color.orange.opacity(0.65), label: "녹음")
            ]
        }
        var layers: [WaveformView.WaveformLayer] = []
        if let a = originalAnalysis { layers.append(WaveformView.WaveformLayer(samples: a.waveform.samples, color: DS.ColorToken.primary, label: "원본")) }
        if let b = recordingAnalysis { layers.append(WaveformView.WaveformLayer(samples: b.waveform.samples, color: .orange, label: "녹음")) }
        return layers
    }

    private func resample(_ s: [Float], to count: Int) -> [Float] {
        guard !s.isEmpty, count > 0 else { return [] }
        guard s.count != count else { return s }
        var r = [Float](repeating: 0, count: count)
        let ratio = Double(s.count - 1) / Double(max(count - 1, 1))
        for i in 0..<count { let src = Int(Double(i) * ratio); r[i] = s[min(src, s.count - 1)] }
        return r
    }

    private func runURLImport() {
        guard !urlField.isEmpty else { return }
        isImportingURL = true
        subtitleService.cues = []; whisperService.cues = []; translatedCues = []
        Task {
            do {
                let result = try await urlImporter.importURL(urlField)
                AppSettings.addRecent(url: urlField, name: result.title)
                recentItems = AppSettings.loadRecent()
                let accessed = result.audioURL.startAccessingSecurityScopedResource()
                defer { if accessed { result.audioURL.stopAccessingSecurityScopedResource() } }
                let vocalURL = try await AudioSeparatorService().separateVocals(from: result.audioURL)
                try playback.load(url: vocalURL)
                self.originalURL = vocalURL; self.originalName = result.title
                self.originalAnalysis = nil; self.pitchTrack = nil
                if let sub = result.subtitleURL { try subtitleService.loadSubtitles(from: sub) }
                analyzeOriginal(); isImportingURL = false
                Task {
                    do {
                        try await whisperService.transcribe(url: vocalURL)
                        self.translationConfig = TranslationSession.Configuration(source: nil, target: Locale.Language(identifier: "ko"))
                        if let samples = try? self.loadFloatSamples(from: vocalURL) { self.calculateCueRhythms(samples: samples) }
                    } catch { self.presentAlert("자막 생성 실패: \(error.localizedDescription)") }
                }
            } catch { isImportingURL = false; presentAlert("링크 가져오기 실패: \(error.localizedDescription)") }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importAudio(from: url)
        case .failure(let error): presentAlert("파일을 가져오지 못했습니다: \(error.localizedDescription)")
        }
    }

    private func importAudio(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        // 이전 상태 초기화
        subtitleService.cues = []
        whisperService.cues = []
        translatedCues = []
        originalAnalysis = nil
        recordingAnalysis = nil
        pitchTrack = nil
        recordingPitchTrack = nil
        originalRhythm = nil
        recordingRhythm = nil
        cueRhythms = [:]
        comparisonScore = nil
        waveformSimilarity = nil
        pitchSimilarity = nil
        playback.clearSecond()
        playback.clearLoopRegion()

        Task {
            do {
                isImportingURL = true
                let vocalURL = try await AudioSeparatorService().separateVocals(from: url)
                try playback.load(url: vocalURL)
                originalURL = vocalURL; originalName = url.lastPathComponent
                originalAnalysis = nil; pitchTrack = nil
                subtitleService.cues = []; whisperService.cues = []; translatedCues = []
                isImportingURL = false; analyzeOriginal()
                Task {
                    do {
                        try await whisperService.transcribe(url: vocalURL)
                        self.translationConfig = TranslationSession.Configuration(source: nil, target: Locale.Language(identifier: "ko"))
                        if let samples = try? self.loadFloatSamples(from: vocalURL) { self.calculateCueRhythms(samples: samples) }
                    } catch { self.presentAlert("자막 생성 실패: \(error.localizedDescription)") }
                }
            } catch { isImportingURL = false; presentAlert("\(error.localizedDescription)") }
        }
    }

    private func startCountdownRecording() {
        let loopDuration: TimeInterval? = {
            if let start = playback.loopStart, let end = playback.loopEnd { return end - start }
            return nil
        }()
        countdown = 3
        Task {
            while countdown ?? 0 > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { if countdown ?? 0 > 1 { countdown = (countdown ?? 1) - 1 } else { countdown = nil } }
            }
            recordingAnalysis = nil
            comparisonScore = nil
            do {
                try recorder.startRecording(stopAt: loopDuration)
                if let start = playback.loopStart { playback.seek(to: start) }
                if !playback.isPlaying { playback.play() }
            } catch { await MainActor.run { presentAlert("\(error.localizedDescription)") } }
        }
    }

    private func analyzeOriginal() {
        guard let url = originalURL else { return }
        isAnalyzing = true

        // 1) 파형 분석 (빠름) — 먼저 표시
        Task {
            do {
                let analysis = try await Task.detached(priority: .userInitiated) {
                    try WaveformAnalyzer.analyze(from: url)
                }.value
                await MainActor.run {
                    self.originalAnalysis = analysis
                    // 파형 표시 즉시 isAnalyzing 해제 (사용자가 파형부터 봄)
                    self.isAnalyzing = false
                }

                // 2) 피치 분석 (느림) — 파형 표시 후
                let samples = try await Task.detached(priority: .userInitiated) {
                    try self.loadFloatSamples(from: url)
                }.value
                let track = try await Task.detached(priority: .userInitiated) {
                    try PitchAnalyzer.analyze(samples: samples)
                }.value
                await MainActor.run {
                    self.pitchTrack = track
                }

                // 3) 리듬 분석 — 마지막
                let rhythm = try await Task.detached(priority: .background) {
                    RhythmAnalyzer.analyze(samples: samples, pitchTrack: track)
                }.value
                await MainActor.run {
                    self.originalRhythm = rhythm
                    self.calculateCueRhythms(samples: samples)
                }
            } catch {
                await MainActor.run { self.isAnalyzing = false }
            }
        }
    }

    private func analyzeRecording() {
        guard let url = recorder.lastRecordingURL else { return }
        try? playback.loadSecond(url: url)
        playback.secondaryVolume = 0.7
        playback.primaryVolume = 1.0
        if let start = playback.loopStart { playback.seek(to: start) }
        isAnalyzing = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let samples = try self.loadFloatSamples(from: url)
                    let analysis = try WaveformAnalyzer.analyze(from: url)
                    let track = try PitchAnalyzer.analyze(samples: samples)
                    let rhythm = RhythmAnalyzer.analyze(samples: samples, pitchTrack: track)
                    return (analysis, rhythm, track)
                }.value
                await MainActor.run {
                    self.recordingAnalysis = result.0
                    self.recordingRhythm = result.1
                    self.recordingPitchTrack = result.2
                    self.isAnalyzing = false
                    self.computeScore()
                }
            } catch { await MainActor.run { self.isAnalyzing = false } }
        }
    }

    // 녹음 점수 (피치 곡선 간 코사인 유사도 기반 간이 점수)
    private func computeScore() {
        // 피치 유사도
        if let orig = pitchTrack, let rec = recordingPitchTrack {
            let origVals = orig.points.map { $0.frequency }.filter { $0 > 0 }
            let recVals = rec.points.map { $0.frequency }.filter { $0 > 0 }
            if !origVals.isEmpty, !recVals.isEmpty {
                let n = min(origVals.count, recVals.count)
                let a = Array(origVals.prefix(n))
                let b = Array(recVals.prefix(n))
                let meanA = a.reduce(0, +) / Double(n)
                let meanB = b.reduce(0, +) / Double(n)
                var num = 0.0, denA = 0.0, denB = 0.0
                for i in 0..<n {
                    let da = a[i] - meanA, db = b[i] - meanB
                    num += da * db; denA += da * da; denB += db * db
                }
                let denom = sqrt(denA) * sqrt(denB)
                if denom > 1e-8 {
                    let corr = num / denom
                    pitchSimilarity = max(0, min(100, (corr + 1) * 50))
                } else {
                    pitchSimilarity = 0
                }
            }
        }

        // 파형 유사도 (RMS 시퀀스의 피어슨 상관)
        if let orig = originalAnalysis, let rec = recordingAnalysis {
            let origS = orig.waveform.samples
            let recS = rec.waveform.samples
            let n = min(origS.count, recS.count)
            if n > 0 {
                var a = Array(origS.prefix(n))
                var b = Array(recS.prefix(n))
                let meanA = a.reduce(0, +) / Float(n)
                let meanB = b.reduce(0, +) / Float(n)
                var num: Float = 0, denA: Float = 0, denB: Float = 0
                for i in 0..<n {
                    let da = a[i] - meanA, db = b[i] - meanB
                    num += da * db; denA += da * da; denB += db * db
                }
                let denom = sqrt(denA) * sqrt(denB)
                if denom > 1e-8 {
                    let corr = num / denom
                    waveformSimilarity = max(0, min(100, Double((corr + 1) * 50)))
                } else {
                    waveformSimilarity = 0
                }
            }
        }

        // 종합
        let scores = [pitchSimilarity, waveformSimilarity].compactMap { $0 }
        if !scores.isEmpty {
            comparisonScore = scores.reduce(0, +) / Double(scores.count)
        }

        // 자막별 유사도 — 각 자막 구간의 원본/녹음 피치 비교
        computeCueSimilarities()
    }

    private func computeCueSimilarities() {
        guard let recPitch = recordingPitchTrack, let origPitch = pitchTrack else { return }
        let cues = !translatedCues.isEmpty ? translatedCues : whisperService.cues
        var result: [UUID: Double] = [:]
        for cue in cues {
            // 원본: 이 자막 구간
            let origVals = origPitch.points.filter { $0.time >= cue.start && $0.time < cue.end && $0.frequency > 0 }.map { $0.frequency }
            // 녹음: 전체 녹음에서 이 자막 구간 비율로 잘라냄 (녹음이 자막 하나만 담고 있다고 가정)
            // 자막 구간이 5초이고 녹음 전체가 5초면 → 녹음 전체
            let recVals = recPitch.points.filter { $0.frequency > 0 }.map { $0.frequency }

            guard !origVals.isEmpty, !recVals.isEmpty else { continue }
            let n = min(origVals.count, recVals.count)
            if n < 3 { continue }
            let a = Array(origVals.prefix(n))
            let b = Array(recVals.prefix(n))
            let meanA = a.reduce(0, +) / Double(n)
            let meanB = b.reduce(0, +) / Double(n)
            var num = 0.0, denA = 0.0, denB = 0.0
            for i in 0..<n {
                let da = a[i] - meanA, db = b[i] - meanB
                num += da * db; denA += da * da; denB += db * db
            }
            let denom = sqrt(denA) * sqrt(denB)
            if denom > 1e-8 {
                let corr = num / denom
                result[cue.id] = max(0, min(100, (corr + 1) * 50))
            }
        }
        self.cueSimilarities = result
    }

    private func scoreColor(_ score: Double) -> Color {
        score >= 75 ? .green : score >= 50 ? .orange : .red
    }

    private func calculateCueRhythms(samples: [Float]) {
        let activeCues = !translatedCues.isEmpty ? translatedCues : whisperService.cues
        let track = self.pitchTrack
        guard !activeCues.isEmpty else { return }
        var cache: [UUID: RhythmAnalysis] = [:]
        for cue in activeCues {
            if let r = RhythmAnalyzer.analyzeSegment(samples: samples, pitchTrack: track, start: cue.start, end: cue.end) {
                cache[cue.id] = r
            }
        }
        self.cueRhythms = cache
    }

    nonisolated private func loadFloatSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url); let format = file.processingFormat
        let frames = AVAudioFrameCount(file.length); guard frames > 0 else { return [] }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return [] }
        try file.read(into: buffer); guard let channel = buffer.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    private func presentAlert(_ message: String) { alertMessage = message; showAlert = true }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time); return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - 드래그 앤 드롭
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                self.importAudio(from: url)
            }
        }
        return true
    }
}

// MARK: - 키보드 단축키 (Space, ←, →)
final class KeyEventMonitor: ObservableObject {
    var onSpace: (() -> Void)?
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    private var monitor: Any?
    init() {}
    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            switch event.keyCode {
            case 49: self?.onSpace?(); return nil
            case 123: self?.onLeft?(); return nil
            case 124: self?.onRight?(); return nil
            default: return event
            }
        }
    }
    deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
}

struct GlobalKeyHandler: NSViewRepresentable {
    let onSpace: () -> Void
    let onLeft: () -> Void
    let onRight: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.monitor.start()
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    func makeCoordinator() -> Coordinator {
        let c = Coordinator()
        c.monitor.onSpace = onSpace
        c.monitor.onLeft = onLeft
        c.monitor.onRight = onRight
        return c
    }
    class Coordinator {
        let monitor = KeyEventMonitor()
    }
}

// 파일 내보내기 (간단)
struct RecordingFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.audio] }
    let url: URL
    init(url: URL) { self.url = url }
    init(configuration: ReadConfiguration) throws { self.url = URL(fileURLWithPath: "") }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: [])
    }
}
