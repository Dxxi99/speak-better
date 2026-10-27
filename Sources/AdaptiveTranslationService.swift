import Foundation
import Combine

@MainActor
final class AdaptiveTranslationService: ObservableObject {
    @Published private(set) var isTranslating = false
    
    /// 사용자의 맥 시스템 언어 감지 (예: "ko-KR", "en-US", "ja-JP")
    var userLocaleIdentifier: String {
        Locale.current.identifier
    }
    
    var userLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// 대상 언어 이름 (UI 표시용)
    var targetLanguageName: String {
        Locale.current.localizedString(forLanguageCode: userLanguageCode) ?? userLanguageCode
    }
}
