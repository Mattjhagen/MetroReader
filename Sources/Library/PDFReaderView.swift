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
            
            // Resume from last page
            if let lastPageIndex = book.lastPage, lastPageIndex < document.pageCount {
                if let page = document.page(at: lastPageIndex) {
                    pdfView.go(to: page)
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
    
    class Coordinator: NSObject {
        let book: Book
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
                
                if self.book.lastPage != pageIndex {
                    self.book.lastPage = pageIndex
                    // SwiftData implicitly autosaves, but we rely on the Book instance being tracked by the context.
                    try? self.book.modelContext?.save()
                }
            }
        }
        
        deinit {
            saveTask?.cancel()
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
            
            if let lastPageIndex = book.lastPage, lastPageIndex < document.pageCount {
                if let page = document.page(at: lastPageIndex) {
                    pdfView.go(to: page)
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {}
    
    class Coordinator: NSObject {
        let book: Book
        private var saveTask: Task<Void, Never>?
        
        init(book: Book) {
            self.book = book
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let pageIndex = document.index(for: currentPage)
            
            saveTask?.cancel()
            saveTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                
                if self.book.lastPage != pageIndex {
                    self.book.lastPage = pageIndex
                    try? self.book.modelContext?.save()
                }
            }
        }
        
        deinit {
            saveTask?.cancel()
        }
    }
}
#endif
