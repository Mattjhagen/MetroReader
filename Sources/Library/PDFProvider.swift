import SwiftUI
import PDFKit

@MainActor
class PDFProvider: ContentProvider {
    let book: Book
    let fileURL: URL
    
    required init(book: Book, fileURL: URL) {
        self.book = book
        self.fileURL = fileURL
    }
    
    var totalUnits: Int {
        // We will post notification or just rely on PDFKit internally 
        // For ContentProvider, we might need a reference to the PDFDocument.
        // Actually, since ReaderContainerView handles normalization, we need totalUnits.
        // We can store a reference to totalUnits once loaded.
        return _totalUnits
    }
    
    private var _totalUnits: Int = 1
    private var _currentUnit: Int = 0
    
    var capabilities: ReaderCapabilities {
        ReaderCapabilities(canChangeTypography: false, canChangeTheme: false)
    }
    
    var currentUnit: Int {
        return _currentUnit
    }
    
    func go(to unitIndex: Int) {
        _currentUnit = unitIndex
        NotificationCenter.default.post(name: .init("ProviderNavigateToUnit"), object: nil, userInfo: ["unitIndex": unitIndex, "bookId": book.id])
    }
    
    func advance(forward: Bool) {
        let newIndex = _currentUnit + (forward ? 1 : -1)
        if newIndex >= 0 && newIndex < _totalUnits {
            go(to: newIndex)
        }
    }
    
    func load() async throws {
        if let doc = PDFDocument(url: fileURL) {
            self._totalUnits = max(1, doc.pageCount)
        }
    }
    
    func renderView() -> AnyView {
        AnyView(PDFReaderView(book: book, url: fileURL))
    }
}
