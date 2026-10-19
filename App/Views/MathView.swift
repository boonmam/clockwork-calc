import SwiftUI
import WebKit

struct MathView: View {
    let calculation: Calculation
    @State private var ready = false
    @State private var failed = false
    var body: some View {
        ZStack(alignment: .topLeading) {
            if !ready {
                VStack(alignment: .leading, spacing: 20) {
                    Text(calculation.expression).font(.system(.callout, design: .monospaced))
                    Text(calculation.presentedText).font(.title2).foregroundStyle(Color.calculatorAccent)
                    if !failed { ProgressView("Formatting equation…").font(.caption) }
                }.padding(20)
            }
            MathWebView(calculation: calculation, ready: $ready, failed: $failed).opacity(ready ? 1 : 0)
        }
    }
}

private struct MathWebView: UIViewRepresentable {
    let calculation: Calculation
    @Binding var ready: Bool
    @Binding var failed: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false; view.backgroundColor = .clear; view.scrollView.backgroundColor = .clear
        view.navigationDelegate = context.coordinator
        view.accessibilityLabel = "\(calculation.expression) equals \(calculation.presentedText)"
        view.accessibilityIdentifier = "formattedEquation"
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Math") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        view.accessibilityLabel = "\(calculation.expression) equals \(calculation.presentedText)"
        if context.coordinator.loaded { context.coordinator.render(view) }
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MathWebView; var loaded = false; var renderedID: UUID?
        init(_ parent: MathWebView) { self.parent = parent }
        func webView(_ view: WKWebView, didFinish navigation: WKNavigation!) { loaded = true; render(view) }
        func webView(_ view: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.failed = true }
        func webView(_ view: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { parent.failed = true }
        func webViewWebContentProcessDidTerminate(_ view: WKWebView) {
            loaded = false; renderedID = nil; parent.ready = false; parent.failed = true
        }
        func render(_ view: WKWebView) {
            let calculation = parent.calculation
            guard renderedID != calculation.id else { return }; renderedID = calculation.id
            view.callAsyncJavaScript("window.showCalculation(input, result, approximate)",
                arguments: ["input": calculation.inputLatex, "result": calculation.latex, "approximate": calculation.approximate],
                in: nil, in: .page, completionHandler: { [weak self] result in
                    switch result {
                    case .success: self?.parent.ready = true; self?.parent.failed = false
                    case .failure: self?.parent.ready = false; self?.parent.failed = true
                    }
                })
        }
        func webView(_ view: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url?.isFileURL == true ? .allow : .cancel)
        }
    }
}
