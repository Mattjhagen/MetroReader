import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var allBooks: [Book]
    
    @State private var isImporting = false
    @State private var libraryStore: LibraryStore?
    @State private var selectedBook: Book?

    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: MetroTheme.spacing)
    ]
    
    var recentlyOpened: [Book] {
        allBooks
            .filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }
    
    var libraryBooks: [Book] {
        allBooks.filter { $0.lastOpenedAt == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MetroTheme.spacing * 2) {
                    
                    if !recentlyOpened.isEmpty {
                        SectionHeader(title: "Recently Opened")
                        LazyVGrid(columns: columns, spacing: MetroTheme.spacing) {
                            ForEach(recentlyOpened) { book in
                                bookTile(for: book)
                            }
                        }
                    }
                    
                    if !libraryBooks.isEmpty {
                        SectionHeader(title: "Library")
                        LazyVGrid(columns: columns, spacing: MetroTheme.spacing) {
                            ForEach(libraryBooks) { book in
                                bookTile(for: book)
                            }
                        }
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
            .navigationDestination(item: $selectedBook) { book in
                ReaderContainerView(book: book)
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
    
    @ViewBuilder
    private func bookTile(for book: Book) -> some View {
        MetroTile(
            size: .medium,
            backgroundColor: MetroTheme.Colors.color(for: book.id.uuidString),
            action: {
                if LibraryStore.getURL(for: book) != nil {
                    selectedBook = book
                    book.lastOpenedAt = .now
                    try? modelContext.save()
                }
            }
        ) {
            BookTileContent(book: book)
        }
        .contextMenu {
            Button(role: .destructive) {
                delete(book)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .opacity(calculateOpacity(for: book))
        // Smooth out layout shifts when a book is deleted or moved
        .animation(.spring(), value: allBooks)
    }

    private func importBook(from url: URL) {
        do {
            _ = try libraryStore?.importPDF(from: url)
        } catch {
            print("Failed to import book: \(error.localizedDescription)")
        }
    }
    
    private func delete(_ book: Book) {
        withAnimation(.spring) {
            try? libraryStore?.deleteBook(book)
        }
    }
    
    private func calculateOpacity(for book: Book) -> Double {
        guard let url = LibraryStore.getURL(for: book) else {
            return 0.5 // Missing file
        }
        
        guard let lastOpened = book.lastOpenedAt else {
            return 1.0 // Never opened, full opacity
        }
        
        // Decay opacity based on days since last opened
        let daysSinceOpen = Calendar.current.dateComponents([.day], from: lastOpened, to: .now).day ?? 0
        if daysSinceOpen > 30 {
            return 0.6
        } else if daysSinceOpen > 7 {
            return 0.8
        }
        return 1.0
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.top, MetroTheme.spacing)
    }
}

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
