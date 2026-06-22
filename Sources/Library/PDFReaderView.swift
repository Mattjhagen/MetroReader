import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let url: URL
    
    var body: some View {
        PDFKitRepresentedView(url: url)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .ignoresSafeArea(edges: .bottom)
    }
}

#if os(iOS)
struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
#elseif os(macOS)
struct PDFKitRepresentedView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {}
}
#endif
