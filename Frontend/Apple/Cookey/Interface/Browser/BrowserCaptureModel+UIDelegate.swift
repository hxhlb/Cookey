import UIKit
import WebKit

extension BrowserCaptureModel: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame _: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default) { _ in
            completionHandler()
        })
        presentAlert(alert, on: webView, fallback: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame _: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default) { _ in
            completionHandler(true)
        })
        presentAlert(alert, on: webView, fallback: { completionHandler(false) })
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame _: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in
            completionHandler(nil)
        })
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        presentAlert(alert, on: webView, fallback: { completionHandler(nil) })
    }

    private func presentAlert(
        _ alert: UIAlertController,
        on webView: WKWebView,
        fallback: @escaping () -> Void
    ) {
        guard let viewController = webView.window?.rootViewController?.presentedViewController
            ?? webView.window?.rootViewController
        else {
            fallback()
            return
        }
        viewController.present(alert, animated: true)
    }
}
