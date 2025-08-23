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
    @StateObject private var audioManager = AudioManager.shared
    @State private var searchText = ""
    @State private var currentTrack: Track?
    @State private var selectedTab = 0
    @State private var isSearching = false
    @State private var isMusicMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search bar
            HeaderView(searchText: $searchText, isSearching: $isSearching, isMusicMode: $isMusicMode)
            
            // Current track display - show immediately when track is set, even if loading
            if let currentYTTrack = audioManager.currentTrack {
                CurrentTrackView(track: nil, ytTrack: currentYTTrack, audioManager: audioManager)
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
                SearchResultsView(searchText: searchText, currentTrack: $currentTrack, isSearching: $isSearching, isMusicMode: isMusicMode, audioManager: audioManager)
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(0)
                
                QueueView(currentTrack: $currentTrack, audioManager: audioManager)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Queue")
                    }
                    .tag(1)
                
                PlaylistsView(currentTrack: $currentTrack, audioManager: audioManager)
                    .tabItem {
                        Image(systemName: "heart.fill")
                        Text("Playlists")
                    }
                    .tag(2)
                
                DownloadsView(currentTrack: $currentTrack, audioManager: audioManager)
                    .tabItem {
                        Image(systemName: "arrow.down.circle")
                        Text("Downloads")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(4)
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
    let track: Track?
    let ytTrack: YTVideoInfo?
    @ObservedObject var audioManager: AudioManager
    @State private var isSeekingManually = false
    @State private var seekPosition: Double = 0
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedPlayerView()
            } else {
                minimizedPlayerView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    @ViewBuilder
    private func minimizedPlayerView() -> some View {
        HStack(spacing: 12) {
            // Left: Audio wave visualization
            AudioWaveView(isPlaying: audioManager.isPlaying)
                .frame(width: 50, height: 20)
            
            // Center: Track info with scrolling title
            VStack(alignment: .leading, spacing: 0) {
                ScrollingText(text: ytTrack?.title ?? track?.title ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let artist = ytTrack?.uploader ?? track?.author {
                    Text(artist)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Essential controls (positioned lower)
            VStack {
                Spacer(minLength: 25)
                
                HStack(spacing: 6) {
                    Button(action: {
                        Task { @MainActor in
                            await audioManager.playPrevious()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    .disabled(!audioManager.canPlayPrevious())
                    .buttonStyle(.plain)
                    .opacity(audioManager.canPlayPrevious() ? 1.0 : 0.4)
                    
                    Button(action: {
                        audioManager.togglePlayPause()
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .disabled(audioManager.currentTrack == nil)
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Task { @MainActor in
                            await audioManager.playNext()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    .disabled(!audioManager.canPlayNext())
                    .buttonStyle(.plain)
                    .opacity(audioManager.canPlayNext() ? 1.0 : 0.4)
                    
                    Divider()
                        .frame(height: 16)
                        .foregroundColor(.white.opacity(0.3))
                    
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .frame(height: 44)
    }
    
    @ViewBuilder
    private func expandedPlayerView() -> some View {
        VStack(spacing: 8) {
            // Header with minimize button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ytTrack?.title ?? track?.title ?? "Unknown")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(ytTrack?.uploader ?? track?.author ?? "Unknown Artist")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if audioManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                }
                
                // Minimize button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Playback controls
            HStack(spacing: 12) {
                Button(action: {
                    Task { @MainActor in
                        await audioManager.playPrevious()
                    }
                }) {
                    Image(systemName: "backward.fill")
                }
                .disabled(!audioManager.canPlayPrevious())
                
                Button(action: {
                    audioManager.togglePlayPause()
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(audioManager.currentTrack == nil)
                
                Button(action: {
                    Task { @MainActor in
                        await audioManager.playNext()
                    }
                }) {
                    Image(systemName: "forward.fill")
                }
                .disabled(!audioManager.canPlayNext())
            }
            .foregroundColor(.primary)
            
            // Progress bar with seek functionality
            if audioManager.currentTrack != nil {
                VStack(spacing: 4) {
                    if audioManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(height: 20)
                    } else {
                        Slider(
                            value: Binding(
                                get: { isSeekingManually ? seekPosition : audioManager.currentPosition },
                                set: { seekPosition = $0 }
                            ),
                            in: 0...max(1, audioManager.duration)
                        ) { editing in
                            if editing {
                                isSeekingManually = true
                            } else {
                                isSeekingManually = false
                                audioManager.seek(to: seekPosition)
                            }
                        }
                        .disabled(audioManager.duration == 0)
                    }
                    
                    HStack {
                        Text(audioManager.isLoading ? "--:--" : formatTime(audioManager.currentPosition))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Playback speed control
                        HStack(spacing: 4) {
                            Button(action: {
                                let newRate = max(0.25, audioManager.playbackRate - 0.25)
                                audioManager.setPlaybackRate(newRate)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(audioManager.isLoading ? .secondary.opacity(0.5) : .secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(audioManager.isLoading)
                            
                            Text("\(String(format: "%.2fx", audioManager.playbackRate))")
                                .font(.caption2)
                                .foregroundColor(audioManager.isLoading ? .secondary.opacity(0.5) : .secondary)
                                .frame(width: 40, alignment: .center)
                            
                            Button(action: {
                                let newRate = min(2.0, audioManager.playbackRate + 0.25)
                                audioManager.setPlaybackRate(newRate)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(audioManager.isLoading ? .secondary.opacity(0.5) : .secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(audioManager.isLoading)
                        }
                        
                        Spacer()
                        
                        Text(audioManager.isLoading ? "--:--" : formatTime(audioManager.duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(12)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Audio Wave Visualization
struct AudioWaveView: View {
    let isPlaying: Bool
    @State private var animationTimer: Timer?
    @State private var waveHeights: [CGFloat] = Array(repeating: 1, count: 8)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<waveHeights.count, id: \.self) { index in
                Capsule()
                    .fill(isPlaying ? 
                          Color.accentColor.opacity(0.8) : 
                          Color.secondary.opacity(0.3))
                    .frame(width: 3, height: waveHeights[index])
                    .animation(.easeInOut(duration: 0.15), value: waveHeights[index])
            }
        }
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.12)) {
                for i in 0..<waveHeights.count {
                    let baseHeight: CGFloat = 3
                    let maxHeight: CGFloat = 18
                    let randomness = CGFloat.random(in: 0.4...1.0)
                    let wavePhase = sin(Double(i) * 0.9 + Date().timeIntervalSince1970 * 6.0)
                    let height = baseHeight + (maxHeight - baseHeight) * randomness * CGFloat(abs(wavePhase))
                    waveHeights[i] = max(baseHeight, height)
                }
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        withAnimation(.easeOut(duration: 0.4)) {
            for i in 0..<waveHeights.count {
                waveHeights[i] = 3
            }
        }
    }
}

// Scrolling Text Component
struct ScrollingText: View {
    let text: String
    @State private var scrollOffset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var scrollTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // First copy of text
                Text(text)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: scrollOffset)
                
                // Second copy for seamless loop (only if text is longer than container)
                if textWidth > 0 && textWidth > containerWidth {
                    Text(text)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: scrollOffset + textWidth + 30) // 30px gap between copies
                }
            }
            .background(
                Text(text)
                    .fixedSize(horizontal: true, vertical: false)
                    .opacity(0)
                    .background(GeometryReader { textGeo in
                        Color.clear.onAppear {
                            textWidth = textGeo.size.width
                            containerWidth = geometry.size.width
                            startScrolling()
                        }
                    })
            )
            .clipped()
        }
        .onAppear {
            startScrolling()
        }
        .onDisappear {
            stopScrolling()
        }
        .onChange(of: text) { _ in
            stopScrolling()
            scrollOffset = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startScrolling()
            }
        }
    }
    
    private func startScrolling() {
        guard textWidth > containerWidth else { return }
        
        scrollTimer?.invalidate()
        scrollOffset = 0
        
        _ = textWidth + 30 // Text width + gap for calculation reference
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            scrollOffset -= 25 * 0.016 // 25 pixels per second
            
            if scrollOffset <= -(textWidth + 30) {
                scrollOffset = 0 // Reset for infinite loop
            }
        }
    }
    
    private func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
}

// Enhanced tab views
struct SearchResultsView: View {
    let searchText: String
    @Binding var currentTrack: Track?
    @Binding var isSearching: Bool
    let isMusicMode: Bool
    @ObservedObject var audioManager: AudioManager
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
                    SearchResultsList(results: searchResults, currentTrack: $currentTrack, audioManager: audioManager)
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
    @ObservedObject var audioManager: AudioManager
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
                SearchResultRow(result: result, currentTrack: $currentTrack, audioManager: audioManager)
            }
            .listStyle(.plain)
        }
    }
}

struct SearchResultRow: View {
    let result: YTVideoInfo
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        UnifiedTrackRow(
            track: result,
            context: .searchResult(isCurrentTrack: audioManager.currentTrack?.id == result.id),
            audioManager: audioManager
        )
    }
}

struct QueueView: View {
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    @StateObject private var queueManager = QueueManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Queue header with controls
            QueueHeaderView(queueManager: queueManager, audioManager: audioManager)
            
            if queueManager.queue.isEmpty {
                EmptyQueueView()
            } else {
                QueueListView(queueManager: queueManager, audioManager: audioManager, currentTrack: $currentTrack)
            }
        }
    }
}

struct QueueHeaderView: View {
    @ObservedObject var queueManager: QueueManager
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Queue")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !queueManager.queue.isEmpty {
                    Button(action: {
                        queueManager.clearQueue()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !queueManager.queue.isEmpty {
                HStack {
                    Text(queueManager.queueInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            queueManager.toggleShuffle()
                        }) {
                            Image(systemName: queueManager.shuffleMode ? "shuffle.circle.fill" : "shuffle")
                                .foregroundColor(queueManager.shuffleMode ? .blue : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            queueManager.cycleRepeatMode()
                        }) {
                            Image(systemName: repeatIcon)
                                .foregroundColor(queueManager.repeatMode != .off ? .blue : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.secondary.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    private var repeatIcon: String {
        switch queueManager.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat.circle.fill"
        case .one:
            return "repeat.1.circle.fill"
        }
    }
}

struct EmptyQueueView: View {
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

struct QueueListView: View {
    @ObservedObject var queueManager: QueueManager
    @ObservedObject var audioManager: AudioManager
    @Binding var currentTrack: Track?
    
    var body: some View {
        List(queueManager.queue.indices, id: \.self) { index in
            QueueTrackRow(
                track: queueManager.queue[index],
                index: index,
                isCurrentTrack: index == queueManager.currentIndex,
                queueManager: queueManager,
                audioManager: audioManager,
                currentTrack: $currentTrack
            )
            .onDrag {
                NSItemProvider(object: "\(index)" as NSString)
            }
            .onDrop(of: [.text], delegate: QueueDropDelegate(
                queueManager: queueManager,
                currentIndex: index
            ))
        }
        .listStyle(.plain)
    }
}

struct QueueDropDelegate: DropDelegate {
    let queueManager: QueueManager
    let currentIndex: Int
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let sourceIndexString = String(data: data, encoding: .utf8),
                  let sourceIndex = Int(sourceIndexString) else { return }
            
            DispatchQueue.main.async {
                queueManager.moveTrack(from: sourceIndex, to: currentIndex)
            }
        }
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback when dragging over
    }
    
    func dropExited(info: DropInfo) {
        // Optional: Remove visual feedback
    }
}

struct QueueTrackRow: View {
    let track: YTVideoInfo
    let index: Int
    let isCurrentTrack: Bool
    @ObservedObject var queueManager: QueueManager
    @ObservedObject var audioManager: AudioManager
    @Binding var currentTrack: Track?
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        UnifiedTrackRow(
            track: track,
            context: .queue(
                index: index,
                isCurrentTrack: isCurrentTrack,
                onPlay: { playTrackFromQueue(track, at: index) },
                onRemove: { queueManager.removeFromQueue(at: index) }
            ),
            audioManager: audioManager
        )
    }
    
    private func playTrackFromQueue(_ videoInfo: YTVideoInfo, at index: Int) {
        if isCurrentTrack && audioManager.isPlaying {
            audioManager.togglePlayPause()
        } else {
            // Play track from queue
            if let track = queueManager.playTrack(at: index) {
                Task { @MainActor in
                    await audioManager.play(track: track)
                }
            }
        }
    }
}

struct FavoritesView: View {
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Track.addedDate, ascending: false)],
        predicate: NSPredicate(format: "ANY playlistMemberships.playlist.name == %@ AND ANY playlistMemberships.playlist.isSystemPlaylist == YES", "All Favorites"),
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
                    FavoriteTrackRow(track: track, currentTrack: $currentTrack, audioManager: audioManager)
                }
                .listStyle(.plain)
            }
        }
    }
}

struct FavoriteTrackRow: View {
    let track: Track
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        let videoInfo = YTVideoInfo(
            id: track.id ?? "",
            title: track.title ?? "Unknown",
            uploader: track.author ?? "Unknown Artist",
            duration: Int(track.duration),
            thumbnailURL: track.thumbnailURL,
            audioURL: nil,
            description: nil
        )
        
        let isCurrentTrack = audioManager.currentTrack?.id == track.id
        
        UnifiedTrackRow(
            track: videoInfo,
            context: .favorite(
                onRemove: { removeFavorite(track) },
                isCurrentTrack: isCurrentTrack
            ),
            audioManager: audioManager
        )
    }
    
    private func removeFavorite(_ track: Track) {
        // Remove from favorites playlist
        FavoritesManager.shared.removeTrackFromPlaylist(track)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to remove favorite: \(error)")
        }
    }
}



struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var defaultDownloadPath = "~/Music/YTAudioBar"
    @State private var preferredAudioQuality = "best"
    @State private var autoUpdateYTDLP = true
    @StateObject private var notificationManager = NotificationManager.shared
    
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
                
                // Notification Settings
                SettingsSection(title: "Notifications", icon: "bell") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Notifications", isOn: $notificationManager.isEnabled)
                            .font(.subheadline)
                            .onChange(of: notificationManager.isEnabled) { _, newValue in
                                if newValue {
                                    notificationManager.toggleEnabled()
                                } else {
                                    notificationManager.saveSettings()
                                }
                            }
                        
                        if notificationManager.isEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Track Changes", isOn: $notificationManager.showTrackChange)
                                    .font(.caption)
                                    .onChange(of: notificationManager.showTrackChange) { _, _ in
                                        notificationManager.saveSettings()
                                    }
                                
                                Toggle("Download Complete", isOn: $notificationManager.showDownloadComplete)
                                    .font(.caption)
                                    .onChange(of: notificationManager.showDownloadComplete) { _, _ in
                                        notificationManager.saveSettings()
                                    }
                                
                                Toggle("Download Failed", isOn: $notificationManager.showDownloadFailed)
                                    .font(.caption)
                                    .onChange(of: notificationManager.showDownloadFailed) { _, _ in
                                        notificationManager.saveSettings()
                                    }
                            }
                            .padding(.leading, 16)
                        }
                        
                        Text("Get notified about playback and download events")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                                openURL("https://github.com/anthropics/ytaudiobar")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Report Issue") {
                                openURL("https://github.com/anthropics/ytaudiobar/issues")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: defaultDownloadPath) { _, _ in saveSettings() }
        .onChange(of: preferredAudioQuality) { _, _ in saveSettings() }
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
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
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
