import SwiftUI
import SwiftData
import PDFKit

struct PDFReaderView: View {
    let book: Book
    let url: URL
    
    var body: some View {
        PDFKitRepresentedView(book: book, url: url)
            .ignoresSafeArea(edges: .bottom)
    }
}

#if os(iOS)
struct PDFKitRepresentedView: UIViewRepresentable {
    let book: Book
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(book: book)
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
            
            // Resume from normalized reading position
            let pageCount = max(1, document.pageCount)
            let pageIndex = Int(book.readingPosition * Double(pageCount))
            if pageIndex >= 0 && pageIndex < document.pageCount {
                if let page = document.page(at: pageIndex) {
                    pdfView.go(to: page)
                }
            }
        }
        
        context.coordinator.pdfView = pdfView
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.programmaticNavigation(_:)),
            name: .init("ProviderNavigateToUnit"),
            object: nil
        )
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
    
    @MainActor class Coordinator: NSObject {
        let book: Book
        weak var pdfView: PDFView?
        private var saveTask: Task<Void, Never>?
        
        init(book: Book) {
            self.book = book
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let pageIndex = document.index(for: currentPage)
            
            // Debounced Save
            saveTask?.cancel()
            saveTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
                guard !Task.isCancelled else { return }
                
                let pageCount = max(1, document.pageCount)
                let newPosition = Double(pageIndex) / Double(pageCount)
                
                if abs(self.book.readingPosition - newPosition) > 0.0001 {
                    self.book.readingPosition = newPosition
                    self.book.lastKnownGoodPosition = newPosition
                    try? self.book.modelContext?.save()
                }
            }
        }
        
        @objc func programmaticNavigation(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let bookId = userInfo["bookId"] as? UUID,
                  bookId == book.id,
                  let unitIndex = userInfo["unitIndex"] as? Int,
                  let pdfView = self.pdfView,
                  let document = pdfView.document else { return }
            
            if let page = document.page(at: unitIndex) {
                pdfView.go(to: page)
            }
        }
        
        deinit {
            saveTask?.cancel()
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#elseif os(macOS)
struct PDFKitRepresentedView: NSViewRepresentable {
    let book: Book
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(book: book)
    }
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
            
            let pageCount = max(1, document.pageCount)
            let pageIndex = Int(book.readingPosition * Double(pageCount))
            if pageIndex >= 0 && pageIndex < document.pageCount {
                if let page = document.page(at: pageIndex) {
                    pdfView.go(to: page)
                }
            }
        }
        
        context.coordinator.pdfView = pdfView
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {}
    
    @MainActor class Coordinator: NSObject {
        let book: Book
        weak var pdfView: PDFView?
        private var saveTask: Task<Void, Never>?
        
        init(book: Book) {
            self.book = book
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let pageIndex = document.index(for: currentPage)
            
            let pageCount = max(1, document.pageCount)
            let newPosition = Double(pageIndex) / Double(pageCount)
            
            saveTask?.cancel()
            saveTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                
                if abs(self.book.readingPosition - newPosition) > 0.0001 {
                    self.book.readingPosition = newPosition
                    self.book.lastKnownGoodPosition = newPosition
                    try? self.book.modelContext?.save()
                }
            }
        }
        
        @objc func programmaticNavigation(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let bookId = userInfo["bookId"] as? UUID,
                  bookId == book.id,
                  let unitIndex = userInfo["unitIndex"] as? Int,
                  let pdfView = self.pdfView,
                  let document = pdfView.document else { return }
            
            if let page = document.page(at: unitIndex) {
                pdfView.go(to: page)
            }
        }
        
        deinit {
            saveTask?.cancel()
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#endif
