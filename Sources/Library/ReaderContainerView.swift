import SwiftUI

public struct ReaderContainerView: View {
    let book: Book
    @State private var provider: ContentProvider?
    @State private var error: Error?
    
    // Immersive focus mode state
    @State private var isImmersiveMode = false
    
    public init(book: Book) {
        self.book = book
    }
    
    public var body: some View {
        Group {
            if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load book")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let provider = provider {
                provider.renderView()
                    // Use simultaneousGesture to catch taps without breaking PDFKit's internal gestures
                    .simultaneousGesture(TapGesture().onEnded {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isImmersiveMode.toggle()
                        }
                    })
                    // Toggle the Navigation Bar
                    #if os(iOS)
                    .toolbar(isImmersiveMode ? .hidden : .visible, for: .navigationBar)
                    .toolbar(isImmersiveMode ? .hidden : .visible, for: .tabBar)
                    // Optionally hide the home indicator and status bar
                    .persistentSystemOverlays(isImmersiveMode ? .hidden : .visible)
                    #endif
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            do {
                let newProvider = try ContentProviderFactory.provider(for: book)
                try await newProvider.load()
                self.provider = newProvider
            } catch {
                self.error = error
            }
        }
    }
}
