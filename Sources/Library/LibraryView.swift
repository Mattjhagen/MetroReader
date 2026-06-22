import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    
    @State private var isImporting = false
    @State private var libraryStore: LibraryStore?
    @State private var selectedBookURL: URL?

    // Using grid columns that match our base unit structure
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: MetroTheme.spacing)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: MetroTheme.spacing) {
                    ForEach(books) { book in
                        // We use the new MetroTile which encapsulates the layout and animation
                        MetroTile(
                            size: .medium,
                            backgroundColor: MetroTheme.Colors.color(for: book.id.uuidString),
                            action: {
                                if let url = LibraryStore.getURL(for: book) {
                                    selectedBookURL = url
                                    
                                    // Update last opened time
                                    book.lastOpenedAt = .now
                                    try? modelContext.save()
                                }
                            }
                        ) {
                            BookTileContent(book: book)
                        }
                        // Handle missing files gracefully
                        .opacity(LibraryStore.getURL(for: book) == nil ? 0.5 : 1.0)
                    }
                }
                .padding(MetroTheme.spacing)
            }
            .navigationTitle("MetroReader")
            .toolbar {
                ToolbarItem {
                    Button(action: { isImporting = true }) {
                        Label("Import PDF", systemImage: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            // Navigation destination for reading
            .navigationDestination(item: $selectedBookURL) { url in
                PDFReaderView(url: url)
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importBook(from: url)
                case .failure(let error):
                    print("Error importing: \(error.localizedDescription)")
                }
            }
            .onAppear {
                libraryStore = LibraryStore(modelContext: modelContext)
            }
        }
    }

    private func importBook(from url: URL) {
        do {
            _ = try libraryStore?.importPDF(from: url)
        } catch {
            print("Failed to import book: \(error.localizedDescription)")
        }
    }
}

/// The actual data presentation for a book inside a tile.
struct BookTileContent: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            Text(book.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text(book.author)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Book.self, inMemory: true)
}
