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
    @State private var isMusicMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search bar
            HeaderView(searchText: $searchText, isSearching: $isSearching, isMusicMode: $isMusicMode)
            
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
                SearchResultsView(searchText: searchText, currentTrack: $currentTrack, isSearching: $isSearching, isMusicMode: isMusicMode)
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
    @Binding var isMusicMode: Bool
    
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
            
            // Search bar with mode toggle
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    TextField(isMusicMode ? "Search YouTube Music..." : "Search YouTube...", text: $searchText)
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
                
                // Music mode toggle
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: isMusicMode ? "music.note" : "play.rectangle")
                            .font(.system(size: 12))
                            .foregroundColor(isMusicMode ? .blue : .secondary)
                        
                        Text(isMusicMode ? "Music Mode" : "General")
                            .font(.caption)
                            .foregroundColor(isMusicMode ? .blue : .secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isMusicMode)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .scaleEffect(0.8)
                }
                .padding(.horizontal, 4)
            }
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
    let isMusicMode: Bool
    @State private var searchResults: [YTVideoInfo] = []
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @StateObject private var ytdlpManager = YTDLPManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if searchText.isEmpty {
                EmptySearchView(isMusicMode: isMusicMode)
            } else {
                if isSearching {
                    LoadingSearchView(searchText: searchText)
                } else if let error = errorMessage {
                    ErrorSearchView(error: error) {
                        retrySearch()
                    }
                } else {
                    SearchResultsList(results: searchResults, currentTrack: $currentTrack)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            // Cancel any existing search task
            searchTask?.cancel()
            
            if !newValue.isEmpty {
                // Set searching state immediately for UI feedback
                isSearching = true
                errorMessage = nil
                
                // Create new debounced search task
                searchTask = Task {
                    // Wait for 800ms before performing search
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    
                    // Check if task was cancelled (user kept typing)
                    if !Task.isCancelled {
                        await performSearchTask()
                    }
                }
            } else {
                searchResults = []
                errorMessage = nil
                isSearching = false
            }
        }
        .onChange(of: isMusicMode) { _, _ in
            // Re-search when mode changes (with debounce)
            if !searchText.isEmpty {
                searchTask?.cancel()
                isSearching = true
                errorMessage = nil
                
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // Shorter delay for mode change
                    
                    if !Task.isCancelled {
                        await performSearchTask()
                    }
                }
            }
        }
        .onDisappear {
            // Cancel any pending search when view disappears
            searchTask?.cancel()
        }
    }
    
    private func retrySearch() {
        // Cancel any existing search task
        searchTask?.cancel()
        
        if !searchText.isEmpty {
            isSearching = true
            errorMessage = nil
            
            searchTask = Task {
                await performSearchTask()
            }
        }
    }
    
    private func performSearchTask() async {
        guard !searchText.isEmpty else { return }
        
        do {
            let results = try await ytdlpManager.search(query: searchText, musicMode: isMusicMode)
            
            await MainActor.run {
                // Only update if this search wasn't cancelled
                if !Task.isCancelled {
                    self.searchResults = results
                    self.isSearching = false
                }
            }
        } catch {
            await MainActor.run {
                // Only update if this search wasn't cancelled
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }
}

struct EmptySearchView: View {
    let isMusicMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isMusicMode ? "music.note.list" : "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(isMusicMode ? "Search YouTube Music" : "Search YouTube")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(isMusicMode ? 
                     "Search for songs, artists, albums, or playlists" : 
                     "Search for any YouTube video to play its audio")
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

struct ErrorSearchView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Search Error")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct SearchResultsList: View {
    let results: [YTVideoInfo]
    @Binding var currentTrack: Track?
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        if results.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.6))
                
                Text("No Results Found")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List(results, id: \.id) { result in
                SearchResultRow(result: result, currentTrack: $currentTrack)
            }
            .listStyle(.plain)
        }
    }
}

struct SearchResultRow: View {
    let result: YTVideoInfo
    @Binding var currentTrack: Track?
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isFavorite = false
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: getThumbnailURL(from: result.thumbnailURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                case .empty:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                @unknown default:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(result.uploader)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(formatDuration(result.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    playTrack(result)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    toggleFavorite(result)
                }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(isFavorite ? .red : .secondary)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                        .animation(.easeInOut(duration: 0.2), value: isFavorite)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onAppear {
            checkIfFavorite()
        }
    }
    
    private func getThumbnailURL(from thumbnailString: String?) -> URL? {
        guard let thumbnailString = thumbnailString,
              !thumbnailString.isEmpty else {
            // Fallback to constructed URL if we have the video ID
            return URL(string: "https://i.ytimg.com/vi/\(result.id)/hqdefault.jpg")
        }
        
        // Clean the URL string and create URL
        let cleanedString = thumbnailString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: cleanedString), 
           url.scheme != nil {
            return url
        }
        
        // Fallback to constructed URL
        return URL(string: "https://i.ytimg.com/vi/\(result.id)/hqdefault.jpg")
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func playTrack(_ videoInfo: YTVideoInfo) {
        // Create or update track in Core Data
        let track = Track(context: viewContext)
        track.id = videoInfo.id
        track.title = videoInfo.title
        track.author = videoInfo.uploader
        track.duration = Int32(videoInfo.duration)
        track.thumbnailURL = videoInfo.thumbnailURL
        track.addedDate = Date()
        track.isFavorite = false
        track.isDownloaded = false
        
        do {
            try viewContext.save()
            currentTrack = track
            
            // TODO: Audio streaming will be implemented in Phase 4
            print("▶️ Track set as current: \(videoInfo.title)")
            print("🔄 Audio streaming not yet implemented - Phase 4")
        } catch {
            print("Failed to save track: \(error)")
        }
    }
    
    private func checkIfFavorite() {
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND isFavorite == YES", result.id)
        
        do {
            let existingTracks = try viewContext.fetch(request)
            isFavorite = !existingTracks.isEmpty
        } catch {
            print("Failed to check favorite status: \(error)")
        }
    }
    
    private func toggleFavorite(_ videoInfo: YTVideoInfo) {
        // Trigger animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation {
                isAnimating = false
            }
        }
        
        // Check if track already exists
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", videoInfo.id)
        
        do {
            let existingTracks = try viewContext.fetch(request)
            let track: Track
            
            if let existingTrack = existingTracks.first {
                track = existingTrack
            } else {
                track = Track(context: viewContext)
                track.id = videoInfo.id
                track.title = videoInfo.title
                track.author = videoInfo.uploader
                track.duration = Int32(videoInfo.duration)
                track.thumbnailURL = videoInfo.thumbnailURL
                track.addedDate = Date()
                track.isDownloaded = false
            }
            
            // Toggle favorite status
            track.isFavorite = !isFavorite
            
            // Update UI state
            withAnimation(.easeInOut(duration: 0.2)) {
                isFavorite = track.isFavorite
            }
            
            try viewContext.save()
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
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
        .onChange(of: defaultDownloadPath) { _, _ in saveSettings() }
        .onChange(of: preferredAudioQuality) { _, _ in saveSettings() }
        .onChange(of: autoUpdateYTDLP) { _, _ in saveSettings() }
        .onChange(of: showMiniPlayer) { _, _ in saveSettings() }
        .onChange(of: darkMode) { _, _ in saveSettings() }
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