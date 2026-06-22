import SwiftUI

public class PDFProvider: ContentProvider {
    public let book: Book
    public let fileURL: URL
    
    public required init(book: Book, fileURL: URL) {
        self.book = book
        self.fileURL = fileURL
    }
    
    public var totalUnits: Int {
        book.totalPages ?? 0
    }
    
    public var capabilities: ReaderCapabilities {
        ReaderCapabilities(canChangeTypography: false, canChangeTheme: false)
    }
    
    public var currentUnit: Int {
        book.lastPage ?? 0
    }
    
    public func go(to unitIndex: Int) {
        // We can communicate with PDFReaderView via Notification for now, 
        // or let the View observe book.lastPage directly.
        // For phase 1, we just update the book model and let the view react if we wire it up.
        book.lastPage = unitIndex
        NotificationCenter.default.post(name: .init("ProviderNavigateToUnit"), object: nil, userInfo: ["unitIndex": unitIndex, "bookId": book.id])
    }
    
    public func load() async throws {
        // PDFKit handles loading internally when the view is created, 
        // but we could perform pre-flight checks here if needed.
    }
    
    @MainActor
    public func renderView() -> AnyView {
        AnyView(PDFReaderView(book: book, url: fileURL))
    }
}
