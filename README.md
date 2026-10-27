# 너는 생각보다 언어를 잘한다

macOS 어학 학습 앱. 유튜브 영상의 발음·억양·리듬을 내 녹음과 비교한다.

## 기능

- 유튜브 링크에서 오디오 다운로드 (yt-dlp)
- 보컬만 분리 (Demucs, M5 GPU)
- 자동 자막 (Whisper large-v3-turbo, 99개 언어)
- 한국어 번역 (Apple Translation)
- 파형 · 피치 · 리듬 시각화
- 자막 클릭 → 구간 반복
- 3·2·1 카운트다운 → 자동 녹음 (자막 구간)
- 원본 vs 내 녹음 유사도 %

## 요구 사항

- macOS 15.0 이상, Xcode 15 이상, Homebrew

## 설치

필수 도구:

    brew install yt-dlp ffmpeg whisper-cpp deno
    pip3 install -U demucs numpy soundfile torchaudio

Whisper 모델 (1.5GB, 최초 1회):

    mkdir -p ~/Library/Application\ Support/AudioRepeatMVP
    curl -L -o ~/Library/Application\ Support/AudioRepeatMVP/ggml-large-v3-turbo.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin

## 빌드

    xcodebuild -project AudioRepeatMVP.xcodeproj -scheme AudioRepeatMVP -configuration Debug CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build

## 사용법

1. 유튜브 링크 입력 → 가져오기
2. 자막 클릭 → 그 구간 반복
3. 녹음 버튼 → 3·2·1 → 그 구간만 녹음
4. 원본(파랑) vs 녹음(노랑) + 유사도 %

## 키보드 단축키

- Space: 재생 / 일시정지
- 좌우 화살표: 5초 이동

## 라이선스

MIT License.
