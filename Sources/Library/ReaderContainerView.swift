import SwiftUI
import SwiftUI

enum ReaderTheme: String, CaseIterable { case system, light, dark, sepia }
enum ReaderFontSize: String, CaseIterable { case small, medium, large }
enum ReaderMargin: String, CaseIterable { case compact, comfortable, spacious }
struct ReaderContainerView: View {
    let book: Book
    @State private var provider: ContentProvider?
    @State private var error: Error?
    
    // Immersive focus mode state
    @State private var isImmersiveMode = false
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss
    
    // Preferences
    @AppStorage("readerTheme") var theme: ReaderTheme = .system
    @AppStorage("readerFontSize") var fontSize: ReaderFontSize = .medium
    @AppStorage("readerMargin") var margin: ReaderMargin = .comfortable
    
    init(book: Book) {
        self.book = book
    }
    
    var body: some View {
        Group {
            if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                    Text(failureTitle(for: book.failureType))
                        .font(.title2.bold())
                    Text(failureMessage(for: book.failureType))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: { dismiss() }) {
                        Text("Return to Library")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: 240)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 12)
                }
                .navigationBarBackButtonHidden(true)
            } else if let provider = provider {
                provider.renderView()
                    // Distraction suppression: Disable default swipe-to-back
                    .navigationBarBackButtonHidden(true)
                    // Unified tap zones
                    .simultaneousGesture(SpatialTapGesture().onEnded { event in
                        let x = event.location.x
                        let width = UIScreen.main.bounds.width
                        
                        if x < width * 0.3 {
                            provider.advance(forward: false)
                        } else if x > width * 0.7 {
                            provider.advance(forward: true)
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isImmersiveMode.toggle()
                            }
                        }
                    })
                    // Toggle the Navigation Bar
                    #if os(iOS)
                    .toolbar(isImmersiveMode ? .hidden : .visible, for: .navigationBar)
                    .toolbar(isImmersiveMode ? .hidden : .visible, for: .tabBar)
                    .persistentSystemOverlays(isImmersiveMode ? .hidden : .visible)
                    // Custom toolbar
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { dismiss() }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Library")
                                }
                            }
                            .opacity(isImmersiveMode ? 0 : 1)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showSettings.toggle() }) {
                                Image(systemName: "textformat.size")
                            }
                            .opacity(isImmersiveMode ? 0 : 1)
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        ComfortSettingsView(capabilities: provider.capabilities, theme: $theme, fontSize: $fontSize, margin: $margin)
                            .presentationDetents([.height(250)])
                    }
                    #endif
            } else {
                ProgressView("Loading...")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ProviderNavigateToUnit"))) { notification in
            guard let userInfo = notification.userInfo,
                  let bookId = userInfo["bookId"] as? UUID,
                  bookId == book.id,
                  let unitIndex = userInfo["unitIndex"] as? Int,
                  let provider = provider else { return }
            
            // Normalize to 0.0 - 1.0
            let total = Double(max(1, provider.totalUnits))
            let position = Double(unitIndex) / total
            
            if book.readingPosition != position {
                book.readingPosition = position
                try? book.modelContext?.save()
            }
        }
        .task {
            do {
                let newProvider = try ContentProviderFactory.provider(for: book)
                try await newProvider.load()
                
                // Map global readingPosition -> internal format unit
                let initialUnit = Int(book.readingPosition * Double(newProvider.totalUnits))
                newProvider.go(to: initialUnit)
                
                self.provider = newProvider
            } catch {
                var newFailureType: BookFailureType = .corruptFile
                
                if let contentError = error as? ContentProviderError {
                    switch contentError {
                    case .fileNotFound: newFailureType = .missingFile
                    case .unsupportedFormat: newFailureType = .unsupportedFormat
                    }
                } else if let epubError = error as? EPUBParserError {
                    switch epubError {
                    case .missingContainer, .missingOPF: newFailureType = .unreadableMetadata
                    case .parsingFailed, .invalidArchive: newFailureType = .partialParse
                    }
                }
                
                if book.failureType != newFailureType {
                    book.failureType = newFailureType
                    try? book.modelContext?.save()
                }
                self.error = error
            }
        }
    }
    
    private func failureTitle(for type: BookFailureType) -> String {
        switch type {
        case .none: return "Unknown Error"
        case .missingFile: return "File Missing"
        case .corruptFile: return "Corrupted File"
        case .unsupportedFormat: return "Unsupported Format"
        case .unreadableMetadata: return "Unreadable Metadata"
        case .partialParse: return "Incomplete File"
        }
    }
    
    private func failureMessage(for type: BookFailureType) -> String {
        switch type {
        case .none: return "An unknown error occurred while loading this book."
        case .missingFile: return "The physical file for this book has been moved or deleted from your device."
        case .corruptFile: return "This file appears to be corrupted and cannot be safely opened."
        case .unsupportedFormat: return "This document format is not supported by the reader."
        case .unreadableMetadata: return "The structural metadata for this book is missing or unreadable."
        case .partialParse: return "The book could only be partially parsed. Its contents might be malformed."
        }
    }
}

struct ComfortSettingsView: View {
    let capabilities: ReaderCapabilities
    @Binding var theme: ReaderTheme
    @Binding var fontSize: ReaderFontSize
    @Binding var margin: ReaderMargin
    
    var body: some View {
        NavigationView {
            Form {
                if capabilities.canChangeTheme {
                    Picker("Theme", selection: $theme) {
                        ForEach(ReaderTheme.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if capabilities.canChangeTypography {
                    Picker("Font Size", selection: $fontSize) {
                        ForEach(ReaderFontSize.allCases, id: \.self) { f in
                            Text(f.rawValue.capitalized).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Margin", selection: $margin) {
                        ForEach(ReaderMargin.allCases, id: \.self) { m in
                            Text(m.rawValue.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if !capabilities.canChangeTheme && !capabilities.canChangeTypography {
                    Text("Formatting controls are not available for this document format.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .navigationTitle("Reading Comfort")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
