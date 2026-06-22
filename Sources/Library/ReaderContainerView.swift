import SwiftUI
import SwiftUI

public enum ReaderTheme: String, CaseIterable { case system, light, dark, sepia }
public enum ReaderFontSize: String, CaseIterable { case small, medium, large }
public enum ReaderMargin: String, CaseIterable { case compact, comfortable, spacious }
public struct ReaderContainerView: View {
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
                    // Distraction suppression: Disable default swipe-to-back
                    .navigationBarBackButtonHidden(true)
                    // Unified tap zones
                    .simultaneousGesture(SpatialTapGesture().onEnded { event in
                        let x = event.location.x
                        let width = UIScreen.main.bounds.width
                        
                        if x < width * 0.3 {
                            provider.go(to: provider.currentUnit - 1)
                        } else if x > width * 0.7 {
                            provider.go(to: provider.currentUnit + 1)
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
