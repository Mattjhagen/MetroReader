import SwiftUI
import SwiftData

struct BookDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [LibraryEvent]
    
    let book: Book
    let onDelete: () -> Void
    
    init(book: Book, onDelete: @escaping () -> Void) {
        self.book = book
        self.onDelete = onDelete
        let bookId = book.id
        self._events = Query(filter: #Predicate<LibraryEvent> { event in
            event.bookId == bookId
        }, sort: \.timestamp, order: .reverse)
    }
    
    var provenanceHint: String {
        guard let latest = events.first else {
            return "Ready to read"
        }
        switch latest.eventType {
        case .imported:
            return "Imported recently"
        case .repaired:
            return "Recovered after file was restored"
        case .merged:
            return "Reading progress merged"
        case .removed:
            return "Marked for removal"
        }
    }
    
    var fileSizeString: String {
        guard let url = LibraryStore.getURL(for: book),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return "Unknown"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var formatString: String {
        guard let url = LibraryStore.getURL(for: book) else {
            return "Unknown"
        }
        return url.pathExtension.uppercased()
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(book.author)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Details") {
                    LabeledContent("Format", value: formatString)
                    LabeledContent("Size", value: fileSizeString)
                    if let opened = book.lastOpenedAt {
                        LabeledContent("Last Opened", value: opened.formatted(date: .abbreviated, time: .shortened))
                    }
                    LabeledContent("Reading Progress", value: "\((book.readingPosition * 100).formatted(.number.precision(.fractionLength(0))))%")
                }
                
                Section("System Status") {
                    Text(provenanceHint)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        dismiss()
                        // Small delay to allow sheet to dismiss before deleting
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDelete()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete from Library")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
