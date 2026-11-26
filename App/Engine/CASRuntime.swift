import Foundation
import WebKit

/// Each calculation gets a fresh, offline worker. A native deadline terminates the worker
/// and discards its WebView; no script state survives into the next calculation.
@MainActor final class CASRuntime: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Calculation, Error>?
    private var deadline: Task<Void, Never>?
    private var source = ""
    private var adapter = ""
    private var input = ""
    private var exact = true

    static func evaluate(_ input: String, exact: Bool, timeout: Duration = .seconds(5)) async throws -> Calculation {
        let runtime = CASRuntime()
        return try await runtime.run(input, exact: exact, timeout: timeout)
    }
    // scriptOverride is internal and used by the deadline test to simulate a stuck worker.
    func run(_ input: String, exact: Bool, timeout: Duration, scriptOverride: String? = nil) async throws -> Calculation {
        guard input.utf8.count <= 4096 else { throw CalculationError(message: "CAS expressions are limited to 4096 bytes.") }
        try Task.checkCancellation()
        self.input = input; self.exact = exact
        let bundle = Bundle.main
        guard let host = bundle.url(forResource: "host", withExtension: "html", subdirectory: "CAS"),
              let sourceURL = bundle.url(forResource: "nerdamer", withExtension: "js", subdirectory: "CAS"),
              let adapterURL = bundle.url(forResource: "adapter", withExtension: "js", subdirectory: "CAS"),
              let analysisURL = bundle.url(forResource: "improper", withExtension: "js", subdirectory: "CAS") else {
            throw CalculationError(message: "Bundled CAS resources are missing.")
        }
        source = try String(contentsOf: sourceURL, encoding: .utf8)
        adapter = try scriptOverride ?? (String(contentsOf: analysisURL, encoding: .utf8) + "\n" + String(contentsOf: adapterURL, encoding: .utf8))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .nonPersistent()
                let view = WKWebView(frame: .zero, configuration: configuration)
                webView = view; view.navigationDelegate = self
                deadline = Task { [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.finish(.failure(CalculationError(message: "CAS calculation timed out. Try a smaller expression.")))
                }
                view.loadFileURL(host, allowingReadAccessTo: host.deletingLastPathComponent())
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) }
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard continuation != nil else { return }
        webView.callAsyncJavaScript("return await window.calculateCAS(source, adapter, input, exact)",
            arguments: ["source": source, "adapter": adapter, "input": input, "exact": exact],
            in: nil, in: .page) { [weak self] result in
                guard let self, self.continuation != nil else { return }
                do {
                    let raw = try result.get()
                    guard let data = raw as? [String: Any] else { throw CalculationError(message: "Invalid CAS response.") }
                    guard data["ok"] as? Bool == true else { throw CalculationError(message: data["error"] as? String ?? "CAS calculation failed.") }
                    guard let text = data["text"] as? String, let latex = data["latex"] as? String,
                          let inputLatex = data["inputLatex"] as? String else { throw CalculationError(message: "Incomplete CAS result.") }
                    self.finish(.success(Calculation(id: UUID(), date: Date(), expression: self.input,
                        text: text, latex: latex, inputLatex: inputLatex,
                        approximate: data["approximate"] as? Bool ?? true,
                        warnings: data["warnings"] as? [String] ?? [], mode: .cas)))
                } catch { self.finish(.failure(error)) }
            }
    }
    private func finish(_ result: Result<Calculation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        deadline?.cancel(); deadline = nil
        webView?.evaluateJavaScript("window.cancelCalculation && window.cancelCalculation()")
        webView?.stopLoading(); webView?.navigationDelegate = nil; webView = nil
        continuation.resume(with: result)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.failure(CalculationError(message: "CAS process stopped. Try a smaller expression."))) }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(action.request.url?.isFileURL == true ? .allow : .cancel)
    }
}

/// Builds solver calls without changing the user's editable equations.
enum CASSolveInput {
    static func command(equations source: String, variables sourceVariables: String) throws -> String {
        let variables = sourceVariables.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !variables.isEmpty, variables.count <= 8,
              Set(variables).count == variables.count,
              variables.allSatisfy({ $0.range(of: "^[A-Za-z][A-Za-z0-9_]*$", options: .regularExpression) != nil && !["pi", "e", "i", "Infinity"].contains($0) }) else {
            throw CalculationError(message: "Enter a variable such as x, or distinct system variables separated by commas, such as x, y.")
        }
        let equations = source.components(separatedBy: CharacterSet(charactersIn: ";\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !equations.isEmpty, equations.count <= 8 else {
            throw CalculationError(message: "Enter one to eight equations, separated by semicolons or new lines.")
        }
        for equation in equations {
            let sides = equation.components(separatedBy: "=")
            guard sides.count <= 2, sides.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
                throw CalculationError(message: "Each equation needs a left and right side, for example 2*x + 3 = 9.")
            }
        }
        if equations.count == 1 && variables.count == 1 {
            return "solve(\(equations[0]),\(variables[0]))"
        }
        return "linsolve([\(equations.joined(separator: ","))],[\(variables.joined(separator: ","))])"
    }
}
