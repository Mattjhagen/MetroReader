import SwiftUI

public class EPUBProvider: ContentProvider {
    public let book: Book
    public let fileURL: URL
    
    private var parser: EPUBParser?
    
    public required init(book: Book, fileURL: URL) {
        self.book = book
        self.fileURL = fileURL
    }
    
    public var totalUnits: Int {
        book.totalPages ?? 0
    }
    
    public var capabilities: ReaderCapabilities {
        ReaderCapabilities(canChangeTypography: true, canChangeTheme: true)
    }
    
    public var currentUnit: Int {
        book.lastPage ?? 0
    }
    
    public func go(to unitIndex: Int) {
        book.lastPage = unitIndex
        NotificationCenter.default.post(name: .init("ProviderNavigateToUnit"), object: nil, userInfo: ["unitIndex": unitIndex, "bookId": book.id])
    }
    
    public func load() async throws {
        let parsed = try await EPUBParser(fileURL: fileURL)
        self.parser = parsed
        
        // Capture total units (spine items)
        if book.totalPages == nil || book.totalPages != parsed.spineItems.count {
            await MainActor.run {
                book.totalPages = parsed.spineItems.count
                try? book.modelContext?.save()
            }
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
    
    @State private var currentIndex: Int
    
    @AppStorage("readerTheme") var theme: ReaderTheme = .system
    @AppStorage("readerFontSize") var fontSize: ReaderFontSize = .medium
    @AppStorage("readerMargin") var margin: ReaderMargin = .comfortable
    
    init(book: Book, spineItems: [URL]) {
        self.book = book
        self.spineItems = spineItems
        self._currentIndex = State(initialValue: book.lastPage ?? 0)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            EPUBWebView(book: book, spineItems: spineItems, theme: theme, fontSize: fontSize, margin: margin)
                .ignoresSafeArea(edges: .bottom)
            
            HStack {
                Button(action: { navigate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .padding()
                        .background(Material.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .disabled(currentIndex <= 0)
                
                Spacer()
                
                Text("Chapter \(currentIndex + 1) of \(spineItems.count)")
                    .font(.caption)
                    .padding(8)
                    .background(Material.ultraThinMaterial)
                    .cornerRadius(8)
                
                Spacer()
                
                Button(action: { navigate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .padding()
                        .background(Material.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .disabled(currentIndex >= spineItems.count - 1)
            }
            .padding()
        }
    }
    
    private func navigate(by offset: Int) {
        let newIndex = currentIndex + offset
        if newIndex >= 0 && newIndex < spineItems.count {
            currentIndex = newIndex
            book.lastPage = currentIndex
            try? book.modelContext?.save()
            NotificationCenter.default.post(name: .init("ProviderNavigateToUnit"), object: nil, userInfo: ["unitIndex": currentIndex, "bookId": book.id])
        }
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
        
        // Load initial
        let initialUnit = book.lastPage ?? 0
        if initialUnit >= 0 && initialUnit < spineItems.count {
            webView.loadFileURL(spineItems[initialUnit], allowingReadAccessTo: spineItems[initialUnit].deletingLastPathComponent())
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
