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
            .filter { $0.lastOpenedAt != nil && !$0.isDamaged }
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
                    
                    if searchText.isEmpty && sortMode != .unread && !allBooks.isEmpty {
                        SectionHeader(title: "Continue Reading")
                        if let heroBook = continueReadingBook {
                            heroTile(for: heroBook)
                        } else {
                            fallbackHeroTile
                        }
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
                
#if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { triggerChaosMode() }) {
                        Image(systemName: "ladybug.fill")
                            .foregroundColor(.orange)
                    }
                }
#endif
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
            .task {
                // Background reconciliation pass
                // We use a slight delay to ensure UI is completely rendered first
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let store = libraryStore {
                    store.reconcileLibrary(books: allBooks)
                }
            }
        }
    }
    
    @ViewBuilder
    private func heroTile(for book: Book) -> some View {
        MetroTile(
            size: .wide,
            backgroundColor: MetroTheme.Colors.color(for: book.id.uuidString),
            state: stateFor(book: book),
            action: {
                open(book)
            }
        ) {
            HStack {
                BookTileContent(book: book, isActive: true)
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
            state: stateFor(book: book),
            action: {
                open(book)
            }
        ) {
            BookTileContent(book: book, isActive: false)
        }
        .contextMenu {
            Button(role: .destructive) { delete(book) } label: { Label("Delete", systemImage: "trash") }
        }
        .opacity(calculateOpacity(for: book))
        .animation(.spring(), value: allBooks)
    }
    
    private var fallbackHeroTile: some View {
        let hasDamagedBooks = allBooks.contains { $0.isDamaged }
        
        return MetroTile(
            size: .wide,
            backgroundColor: hasDamagedBooks ? Color.orange.opacity(0.8) : MetroTheme.Colors.blue,
            state: .normal,
            action: { }
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: hasDamagedBooks ? "exclamationmark.triangle.fill" : "books.vertical.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text(hasDamagedBooks ? "Library needs attention" : "Ready to read")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(hasDamagedBooks ? "Some books in your library are missing or damaged." : "Pick a book from your library below.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        VStack(spacing: 24) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.title2.bold())
                Text("Let's get you started. Import your first EPUB or PDF, or check out these samples.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { isImporting = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Import Book")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: 240)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            
            Button(action: { loadSampleBooks() }) {
                Text("Load Sample Books")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadSampleBooks() {
        // Just mock some books for cold start demo.
        let b1 = Book(title: "The Art of Reading", author: "Sample Press", filename: "sample1.epub")
        let b2 = Book(title: "Designing Systems", author: "Sample Press", filename: "sample2.pdf")
        let b3 = Book(title: "Metro Typography", author: "Sample Press", filename: "sample3.epub")
        modelContext.insert(b1)
        modelContext.insert(b2)
        modelContext.insert(b3)
        try? modelContext.save()
    }
    
#if DEBUG
    private func triggerChaosMode() {
        for i in 1...250 {
            // Mix of different failures
            let failureTypeChoice = Int.random(in: 0...5)
            let title: String
            let failureType: BookFailureType
            let filename: String
            
            switch failureTypeChoice {
            case 0:
                title = "Malformed EPUB \(i)"
                filename = "missing_file_\(i).epub"
                failureType = .partialParse
            case 1:
                title = "Corrupted PDF \(i)"
                filename = "corrupt_\(i).pdf"
                failureType = .corruptFile
            case 2:
                // Duplicate filename but different metadata
                title = "Duplicate Content \(i)"
                filename = "sample1.epub"
                failureType = .none
            case 3:
                title = "Missing File \(i)"
                filename = "does_not_exist_\(i).epub"
                failureType = .missingFile
            case 4:
                title = "Unsupported Format \(i)"
                filename = "unsupported_\(i).txt"
                failureType = .unsupportedFormat
            default:
                title = "Normal Book \(i)"
                filename = "sample\(i%3 + 1).epub"
                failureType = .none
            }
            
            let book = Book(
                title: title,
                author: "Chaos Monkey",
                filename: filename
            )
            book.failureType = failureType
            book.readingPosition = Double.random(in: 0...1)
            book.lastKnownGoodPosition = book.readingPosition
            if Bool.random() {
                book.lastOpenedAt = Date().addingTimeInterval(-Double.random(in: 0...86400 * 30))
            }
            modelContext.insert(book)
        }
        try? modelContext.save()
    }
#endif
    
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
    
    private func stateFor(book: Book) -> MetroTileState {
        switch book.failureType {
        case .none: return .normal
        case .missingFile: return .missing
        case .corruptFile, .unreadableMetadata, .unsupportedFormat: return .corrupted
        case .partialParse: return .incomplete
        }
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
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if book.isDamaged {
                Image(systemName: iconFor(failureType: book.failureType))
                    .font(.largeTitle)
                    .foregroundColor(colorFor(failureType: book.failureType).opacity(0.8))
                    .padding(.bottom, 8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(book.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if book.isDamaged {
                    Text(failureDescription(for: book.failureType))
                        .font(.subheadline)
                        .foregroundColor(colorFor(failureType: book.failureType))
                        .lineLimit(1)
                } else {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 6)
            
            // Momentum signal (progress bar)
            ProgressIndicator(progress: book.readingPosition, isDamaged: book.isDamaged)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func iconFor(failureType: BookFailureType) -> String {
        switch failureType {
        case .missingFile: return "doc.text.magnifyingglass"
        case .corruptFile, .unreadableMetadata: return "doc.badge.gearshape"
        case .partialParse: return "doc.text.fill.viewfinder"
        case .unsupportedFormat: return "doc.badge.xmark"
        default: return "exclamationmark.triangle.fill"
        }
    }
    
    private func colorFor(failureType: BookFailureType) -> Color {
        switch failureType {
        case .missingFile: return .white.opacity(0.7)
        case .corruptFile, .unreadableMetadata: return .white
        case .partialParse: return .yellow
        case .unsupportedFormat: return .red
        default: return .white
        }
    }

    private func failureDescription(for failureType: BookFailureType) -> String {
        switch failureType {
        case .none: return ""
        case .missingFile: return "File is missing"
        case .corruptFile, .unreadableMetadata: return "File appears damaged"
        case .unsupportedFormat: return "Format not supported"
        case .partialParse: return "Could not read safely"
        }
    }
}

private struct ProgressIndicator: View {
    let progress: Double
    let isDamaged: Bool
    
    var body: some View {
        GeometryReader { geo in
            if isDamaged {
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 4)
                    .frame(width: geo.size.width, alignment: .leading)
            } else if progress > 0 {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 2)
                    .overlay(
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(progress), height: 2),
                        alignment: .leading
                    )
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Book.self, inMemory: true)
}
