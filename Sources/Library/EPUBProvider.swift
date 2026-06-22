import SwiftUI

public class EPUBProvider: ContentProvider {
    public let book: Book
    public let fileURL: URL
    
    private var parser: EPUBParser?
    private var _totalUnits: Int = 1
    private var _currentUnit: Int = 0
    
    public required init(book: Book, fileURL: URL) {
        self.book = book
        self.fileURL = fileURL
    }
    
    public var totalUnits: Int {
        _totalUnits
    }
    
    public var capabilities: ReaderCapabilities {
        ReaderCapabilities(canChangeTypography: true, canChangeTheme: true)
    }
    
    public var currentUnit: Int {
        _currentUnit
    }
    
    public func go(to unitIndex: Int) {
        _currentUnit = unitIndex
        NotificationCenter.default.post(name: .init("ProviderNavigateToUnit"), object: nil, userInfo: ["unitIndex": unitIndex, "bookId": book.id])
    }
    
    public func advance(forward: Bool) {
        let newIndex = _currentUnit + (forward ? 1 : -1)
        if newIndex >= 0 && newIndex < _totalUnits {
            go(to: newIndex)
        }
    }
    
    public func load() async throws {
        let parsed = try await EPUBParser(fileURL: fileURL)
        self.parser = parsed
        
        await MainActor.run {
            self._totalUnits = max(1, parsed.spineItems.count)
        }
    }
    
    @MainActor
    public func renderView() -> AnyView {
        guard let parser = parser else {
            return AnyView(Text("EPUB not loaded").foregroundColor(.red))
        }
        return AnyView(EPUBReaderView(book: book, spineItems: parser.spineItems))
    }
    
    deinit {
        parser?.cleanup()
    }
}

import WebKit

struct EPUBReaderView: View {
    let book: Book
    let spineItems: [URL]
    
    @AppStorage("readerTheme") var theme: ReaderTheme = .system
    @AppStorage("readerFontSize") var fontSize: ReaderFontSize = .medium
    @AppStorage("readerMargin") var margin: ReaderMargin = .comfortable
    
    init(book: Book, spineItems: [URL]) {
        self.book = book
        self.spineItems = spineItems
    }
    
    var body: some View {
        EPUBWebView(book: book, spineItems: spineItems, theme: theme, fontSize: fontSize, margin: margin)
            .ignoresSafeArea(edges: .bottom)
    }
}

#if os(iOS)
struct EPUBWebView: UIViewRepresentable {
    let book: Book
    let spineItems: [URL]
    let theme: ReaderTheme
    let fontSize: ReaderFontSize
    let margin: ReaderMargin
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        
        // Navigation observer
        NotificationCenter.default.addObserver(
            forName: .init("ProviderNavigateToUnit"),
            object: nil,
            queue: .main
        ) { [weak webView] notification in
            guard let userInfo = notification.userInfo,
                  let bookId = userInfo["bookId"] as? UUID,
                  bookId == book.id,
                  let unitIndex = userInfo["unitIndex"] as? Int,
                  unitIndex >= 0 && unitIndex < spineItems.count,
                  let webView = webView else { return }
            
            webView.loadFileURL(spineItems[unitIndex], allowingReadAccessTo: spineItems[unitIndex].deletingLastPathComponent())
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Build CSS based on settings
        var css = "body { "
        
        // Font Size
        switch fontSize {
        case .small: css += "font-size: 14px; "
        case .medium: css += "font-size: 18px; "
        case .large: css += "font-size: 24px; "
        }
        
        // Margin
        switch margin {
        case .compact: css += "padding: 5%; line-height: 1.3; "
        case .comfortable: css += "padding: 10%; line-height: 1.6; "
        case .spacious: css += "padding: 15%; line-height: 2.0; "
        }
        
        // Theme
        switch theme {
        case .dark:
            css += "background-color: #000000; color: #FFFFFF; "
        case .sepia:
            css += "background-color: #F4ECD8; color: #5B4636; "
        case .light:
            css += "background-color: #FFFFFF; color: #000000; "
        case .system:
            // Handled by default or media query if we inject more complex CSS
            break
        }
        
        css += "}"
        
        let js = "var style = document.getElementById('metro-comfort-style'); if (!style) { style = document.createElement('style'); style.id = 'metro-comfort-style'; document.head.appendChild(style); } style.innerHTML = '\(css)';"
        
        uiView.evaluateJavaScript(js, completionHandler: nil)
    }
}
#endif
