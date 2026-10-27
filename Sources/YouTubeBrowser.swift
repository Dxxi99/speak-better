import SwiftUI
import WebKit

struct YouTubeBrowser: NSViewRepresentable {
    @Binding var currentURL: String?
    @Binding var shouldReload: Bool

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // 자바스크립트에서 Swift로 메시지 보낼 수 있게 설정
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "urlChanged")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // PC용 유튜브로 위장 (URL 추출이 훨씬 쉬움)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // 유튜브 홈으로 시작
        if let url = URL(string: "https://www.youtube.com") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if shouldReload {
            webView.reload()
            DispatchQueue.main.async { self.shouldReload = false }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubeBrowser
        init(_ parent: YouTubeBrowser) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectObserverJS(into: webView)
        }
        
        private func injectObserverJS(into webView: WKWebView) {
            // 유튜브 SPA에서 URL이 바뀔 때마다 Swift로 알림
            let js = """
            (function() {
                if (window.__urlObserverInstalled) return;
                window.__urlObserverInstalled = true;
                
                function notify() {
                    window.webkit.messageHandlers.urlChanged.postMessage(window.location.href);
                }
                
                // 1) history.pushState / replaceState 가로채기
                var origPush = history.pushState;
                var origReplace = history.replaceState;
                history.pushState = function() { origPush.apply(this, arguments); setTimeout(notify, 100); };
                history.replaceState = function() { origReplace.apply(this, arguments); setTimeout(notify, 100); };
                
                // 2) popstate 이벤트
                window.addEventListener('popstate', notify);
                
                // 3) 주기적으로 확인 (유튜브가 내부 상태를 바꾸는 경우 대비)
                setInterval(notify, 1000);
                
                notify();
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // 자바스크립트에서 보낸 메시지 처리
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "urlChanged", let url = message.body as? String {
                DispatchQueue.main.async {
                    self.parent.currentURL = url
                }
            }
        }
    }
}
