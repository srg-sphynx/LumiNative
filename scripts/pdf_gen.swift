import Cocoa
import WebKit

// Usage: swift pdf_gen.swift <input_html_path> <output_pdf_path>

guard CommandLine.arguments.count == 3 else {
    print("Usage: swift pdf_gen.swift <input_html_path> <output_pdf_path>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

let app = NSApplication.shared

class PDFRenderer: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let outputURL: URL
    let inputURL: URL
    
    init(inputPath: String, outputPath: String) {
        self.inputURL = URL(fileURLWithPath: inputPath)
        self.outputURL = URL(fileURLWithPath: outputPath)
        
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1200), configuration: config)
        
        super.init()
        self.webView.navigationDelegate = self
    }
    
    func start() {
        // Allow access to local files (like the app icon)
        webView.loadFileURL(inputURL, allowingReadAccessTo: inputURL.deletingLastPathComponent().deletingLastPathComponent())
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a bit for layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.createPDF()
        }
    }
    
    func createPDF() {
        let config = WKPDFConfiguration()
        
        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                do {
                    try data.write(to: self.outputURL)
                    print("✅ PDF created successfully at \(self.outputURL.path)")
                    exit(0)
                } catch {
                    print("❌ Failed to write PDF: \(error)")
                    exit(1)
                }
            case .failure(let error):
                print("❌ Failed to create PDF: \(error)")
                exit(1)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ Webview load failed: \(error)")
        exit(1)
    }
}

let renderer = PDFRenderer(inputPath: inputPath, outputPath: outputPath)
renderer.start()

app.run()
