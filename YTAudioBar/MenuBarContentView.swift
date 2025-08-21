//
//  MenuBarContentView.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import SwiftUI
import CoreData

struct MenuBarContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var currentTrack: Track?
    @State private var isPlaying = false
    @State private var selectedTab = 0
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search bar
            HeaderView(searchText: $searchText, isSearching: $isSearching)
            
            // Current track display
            if let track = currentTrack {
                CurrentTrackView(track: track, isPlaying: $isPlaying)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3)),
                        alignment: .bottom
                    )
            }
            
            // Main content area
            TabView(selection: $selectedTab) {
                SearchResultsView(searchText: searchText, currentTrack: $currentTrack, isSearching: $isSearching)
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(0)
                
                QueueView(currentTrack: $currentTrack, isPlaying: $isPlaying)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Queue")
                    }
                    .tag(1)
                
                FavoritesView(currentTrack: $currentTrack)
                    .tabItem {
                        Image(systemName: "heart.fill")
                        Text("Favorites")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 12)
        }
        .frame(width: 420, height: 520)
        .background(Color(.windowBackgroundColor))
    }
}

struct HeaderView: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // App title
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.accentColor)
                Text("YTAudioBar")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search YouTube music...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit {
                        if !searchText.isEmpty {
                            isSearching = true
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearching = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .background(Color(.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.secondary.opacity(0.2)),
            alignment: .bottom
        )
    }
}

struct CurrentTrackView: View {
    let track: Track
    @Binding var isPlaying: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(track.author ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                }
                
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                }
            }
            .foregroundColor(.primary)
        }
    }
}

// Enhanced tab views
struct SearchResultsView: View {
    let searchText: String
    @Binding var currentTrack: Track?
    @Binding var isSearching: Bool
    @State private var searchResults: [SearchResult] = []
    
    var body: some View {
        VStack(spacing: 0) {
            if searchText.isEmpty {
                EmptySearchView()
            } else {
                if isSearching {
                    LoadingSearchView(searchText: searchText)
                } else {
                    SearchResultsList(results: searchResults, currentTrack: $currentTrack)
                }
            }
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                // TODO: Implement actual search when yt-dlp is integrated
                simulateSearch()
            }
        }
    }
    
    private func simulateSearch() {
        // Simulate search delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            searchResults = [
                SearchResult(id: "1", title: "Sample Song 1", author: "Artist 1", duration: 180),
                SearchResult(id: "2", title: "Sample Song 2", author: "Artist 2", duration: 240),
            ]
            isSearching = false
        }
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Search YouTube Music")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Enter a song, artist, or album name to find music")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct LoadingSearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Searching for '\(searchText)'...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct SearchResultsList: View {
    let results: [SearchResult]
    @Binding var currentTrack: Track?
    
    var body: some View {
        List(results, id: \.id) { result in
            SearchResultRow(result: result, currentTrack: $currentTrack)
        }
        .listStyle(.plain)
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    @Binding var currentTrack: Track?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(result.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(formatDuration(result.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                // TODO: Implement play functionality
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct QueueView: View {
    @Binding var currentTrack: Track?
    @Binding var isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Queue is Empty")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Add songs to your queue from search results")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct FavoritesView: View {
    @Binding var currentTrack: Track?
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Track.addedDate, ascending: false)],
        predicate: NSPredicate(format: "isFavorite == YES"),
        animation: .default)
    private var favoritesTracks: FetchedResults<Track>
    
    var body: some View {
        VStack {
            if favoritesTracks.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "heart.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("No Favorites Yet")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Heart songs you love to add them to your favorites")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(favoritesTracks, id: \.objectID) { track in
                    FavoriteTrackRow(track: track, currentTrack: $currentTrack)
                }
                .listStyle(.plain)
            }
        }
    }
}

struct FavoriteTrackRow: View {
    let track: Track
    @Binding var currentTrack: Track?
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(track.author ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                currentTrack = track
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

// Helper struct for search results
struct SearchResult {
    let id: String
    let title: String
    let author: String
    let duration: Int
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var defaultDownloadPath = "~/Music/YTAudioBar"
    @State private var preferredAudioQuality = "best"
    @State private var autoUpdateYTDLP = true
    @State private var showMiniPlayer = false
    @State private var darkMode = false
    
    let audioQualities = ["best", "320", "256", "192", "128"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Download Settings
                SettingsSection(title: "Downloads", icon: "arrow.down.circle") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Download Location:")
                                .font(.subheadline)
                            Spacer()
                            Button("Choose...") {
                                chooseDownloadLocation()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        Text(defaultDownloadPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        Divider()
                        
                        HStack {
                            Text("Audio Quality:")
                                .font(.subheadline)
                            Spacer()
                            Picker("Quality", selection: $preferredAudioQuality) {
                                ForEach(audioQualities, id: \.self) { quality in
                                    Text(quality == "best" ? "Best Available" : "\(quality) kbps")
                                        .tag(quality)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                        }
                    }
                }
                
                // Player Settings
                SettingsSection(title: "Player", icon: "play.circle") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Show Mini Player", isOn: $showMiniPlayer)
                            .font(.subheadline)
                        
                        Text("Keep a floating player window open for detailed controls")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Appearance Settings
                SettingsSection(title: "Appearance", icon: "paintbrush") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Dark Mode", isOn: $darkMode)
                            .font(.subheadline)
                        
                        Text("Override system appearance setting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Update Settings
                SettingsSection(title: "Updates", icon: "arrow.triangle.2.circlepath") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Auto-update yt-dlp", isOn: $autoUpdateYTDLP)
                            .font(.subheadline)
                        
                        Text("Automatically update the YouTube downloader when new versions are available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("yt-dlp Version")
                                    .font(.subheadline)
                                Text("2024.01.01")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Check for Updates") {
                                // TODO: Implement update check
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                // About Section
                SettingsSection(title: "About", icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("YTAudioBar")
                                .font(.headline)
                            Spacer()
                            Text("v1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("A menu bar app for streaming and downloading YouTube audio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        HStack(spacing: 12) {
                            Button("GitHub") {
                                // TODO: Open GitHub URL
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Report Issue") {
                                // TODO: Open issue reporting
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear(perform: loadSettings)
        .onChange(of: defaultDownloadPath) { _ in saveSettings() }
        .onChange(of: preferredAudioQuality) { _ in saveSettings() }
        .onChange(of: autoUpdateYTDLP) { _ in saveSettings() }
        .onChange(of: showMiniPlayer) { _ in saveSettings() }
        .onChange(of: darkMode) { _ in saveSettings() }
    }
    
    private func chooseDownloadLocation() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { result in
            if result == .OK, let url = panel.url {
                defaultDownloadPath = url.path
            }
        }
    }
    
    private func loadSettings() {
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        
        do {
            let settings = try viewContext.fetch(request)
            if let appSettings = settings.first {
                defaultDownloadPath = appSettings.defaultDownloadPath ?? "~/Music/YTAudioBar"
                preferredAudioQuality = appSettings.preferredAudioQuality ?? "best"
                autoUpdateYTDLP = appSettings.autoUpdateYTDLP
                showMiniPlayer = appSettings.showMiniPlayer
                darkMode = appSettings.darkMode
            } else {
                createDefaultSettings()
            }
        } catch {
            print("Failed to load settings: \(error)")
            createDefaultSettings()
        }
    }
    
    private func createDefaultSettings() {
        let settings = AppSettings(context: viewContext)
        settings.id = UUID()
        settings.defaultDownloadPath = defaultDownloadPath
        settings.preferredAudioQuality = preferredAudioQuality
        settings.autoUpdateYTDLP = autoUpdateYTDLP
        settings.showMiniPlayer = showMiniPlayer
        settings.darkMode = darkMode
        
        saveContext()
    }
    
    private func saveSettings() {
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        
        do {
            let settings = try viewContext.fetch(request)
            let appSettings = settings.first ?? AppSettings(context: viewContext)
            
            if appSettings.id == nil {
                appSettings.id = UUID()
            }
            
            appSettings.defaultDownloadPath = defaultDownloadPath
            appSettings.preferredAudioQuality = preferredAudioQuality
            appSettings.autoUpdateYTDLP = autoUpdateYTDLP
            appSettings.showMiniPlayer = showMiniPlayer
            appSettings.darkMode = darkMode
            
            saveContext()
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16))
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
                .padding(.leading, 24)
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    MenuBarContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}