import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    
    @State private var isImporting = false
    @State private var libraryStore: LibraryStore?

    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(books) { book in
                        if let fileURL = LibraryStore.getURL(for: book) {
                            NavigationLink(destination: PDFReaderView(url: fileURL)) {
                                BookTileView(book: book)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // File missing
                            BookTileView(book: book)
                                .opacity(0.5)
                        }
                    }
                }
                .padding()
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

struct BookTileView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading) {
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(0.7, contentMode: .fit)
        .background(Color.accentColor) // Metro tile aesthetic
        .cornerRadius(12)
        .shadow(radius: 4, y: 2)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Book.self, inMemory: true)
}
