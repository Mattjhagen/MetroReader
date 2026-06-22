import SwiftUI

public struct ReaderContainerView: View {
    let book: Book
    @State private var provider: ContentProvider?
    @State private var error: Error?
    
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
