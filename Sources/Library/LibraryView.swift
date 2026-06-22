import SwiftUI
import SwiftData

enum SortMode: String, CaseIterable, Identifiable {
    case recent = "Recently Added"
    case oldest = "Oldest First"
    case unread = "Unread"
    var id: String { rawValue }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var allBooks: [Book]
    
    @State private var isImporting = false
    @State private var libraryStore: LibraryStore?
    @State private var selectedBook: Book?
    @State private var searchText = ""
    @State private var hasAutoResumed = false
    @AppStorage("librarySortMode") private var sortMode: SortMode = .recent

    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: MetroTheme.spacing)
    ]
    
    // Derived Data
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return allBooks
        }
        return allBooks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var continueReadingBook: Book? {
        // Must be recently opened (e.g., within 30 days) and be the absolute most recent.
        guard searchText.isEmpty, sortMode != .unread else { return nil }
        
        return allBooks
            .filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .first(where: { book in
                guard let lastOpened = book.lastOpenedAt else { return false }
                let daysSinceOpen = Calendar.current.dateComponents([.day], from: lastOpened, to: .now).day ?? 0
                return daysSinceOpen <= 30
            })
    }
    
    var librarySectionBooks: [Book] {
        var section = filteredBooks
        
        // Remove the hero book so it doesn't duplicate
        if let hero = continueReadingBook {
            section.removeAll(where: { $0.id == hero.id })
        }
        
        switch sortMode {
        case .recent:
            section.sort { $0.dateAdded > $1.dateAdded }
        case .oldest:
            section.sort { $0.dateAdded < $1.dateAdded }
        case .unread:
            section.removeAll(where: { $0.lastOpenedAt != nil })
            section.sort { $0.dateAdded > $1.dateAdded }
        }
        
        return section
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MetroTheme.spacing * 2) {
                    
                    if let heroBook = continueReadingBook {
                        SectionHeader(title: "Continue Reading")
                        heroTile(for: heroBook)
                    }
                    
                    if !librarySectionBooks.isEmpty {
                        SectionHeader(title: "Library")
                        LazyVGrid(columns: columns, spacing: MetroTheme.spacing) {
                            ForEach(librarySectionBooks) { book in
                                bookTile(for: book)
                            }
                        }
                    } else if allBooks.isEmpty {
                        emptyStateView
                    } else {
                        noSearchResultsView
                    }
                }
                .padding(MetroTheme.spacing)
            }
            .navigationTitle("MetroReader")
            .searchable(text: $searchText, prompt: "Search title or author")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $sortMode) {
                            ForEach(SortMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isImporting = true }) {
                        Label("Import PDF", systemImage: "plus.circle.fill")
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
                
                // Auto-resume logic
                if !hasAutoResumed {
                    hasAutoResumed = true
                    // Find the single most eligible book for auto-resume
                    if let resumeBook = allBooks.filter({ $0.shouldAutoResume })
                        .sorted(by: { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) })
                        .first {
                        
                        // We use a slight delay so the UI doesn't jump aggressively before the view hierarchy settles
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            open(resumeBook)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func heroTile(for book: Book) -> some View {
        MetroTile(
            size: .wide,
            backgroundColor: MetroTheme.Colors.color(for: book.id.uuidString),
            action: {
                open(book)
            }
        ) {
            HStack {
                BookTileContent(book: book)
                Spacer()
                Image(systemName: "book.pages")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .contextMenu {
            Button(role: .destructive) { delete(book) } label: { Label("Delete", systemImage: "trash") }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.8), lineWidth: 2)
        )
        .shadow(color: Color.accentColor.opacity(0.2), radius: 10, x: 0, y: 5)
        .animation(.spring(), value: allBooks)
    }
    
    @ViewBuilder
    private func bookTile(for book: Book) -> some View {
        MetroTile(
            size: .medium,
            backgroundColor: MetroTheme.Colors.color(for: book.id.uuidString),
            action: {
                open(book)
            }
        ) {
            BookTileContent(book: book)
        }
        .contextMenu {
            Button(role: .destructive) { delete(book) } label: { Label("Delete", systemImage: "trash") }
        }
        .opacity(calculateOpacity(for: book))
        .animation(.spring(), value: allBooks)
    }

    private func open(_ book: Book) {
        if LibraryStore.getURL(for: book) != nil {
            selectedBook = book
            book.lastOpenedAt = .now
            try? modelContext.save()
        }
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
        guard LibraryStore.getURL(for: book) != nil else { return 0.5 } // Missing file
        
        // Semantic decay
        if book.isCompleted {
            return 0.5 // Muted
        } else if book.readingProgress > 0 {
            return 0.85 // Partially read, slightly dimmed
        } else {
            return 1.0 // Unread, full opacity
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer().frame(height: 100)
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("Your library is empty")
                .font(.headline)
                .padding(.top)
            Text("Tap + to import a document.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var noSearchResultsView: some View {
        VStack {
            Spacer().frame(height: 100)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No results found")
                .font(.headline)
                .padding(.top)
        }
        .frame(maxWidth: .infinity)
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
        VStack(alignment: .leading, spacing: 0) {
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
            .padding(.bottom, 6)
            
            // Momentum signal (invisible progress bar)
            if book.readingProgress > 0 && !book.isCompleted {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                        .overlay(
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geo.size.width * CGFloat(book.readingProgress), height: 2),
                            alignment: .leading
                        )
                }
                .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Book.self, inMemory: true)
}
