import WebKit

extension BrowserCaptureModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        pageTitle = webView.title ?? "Cookey"
        if !initialLoadComplete {
            initialLoadComplete = true
        }
    }

    func webView(
        _: WKWebView,
        didFail _: WKNavigation!,
        withError error: Error
    ) {
        errorMessage = error.localizedDescription
    }

    func webView(
        _: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError error: Error
    ) {
        errorMessage = error.localizedDescription
    }
}
