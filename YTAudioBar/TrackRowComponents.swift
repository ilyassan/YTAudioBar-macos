//
//  TrackRowComponents.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import SwiftUI
import CoreData

// MARK: - Unified Track Row Component

struct UnifiedTrackRow: View {
    let track: YTVideoInfo
    let context: TrackRowContext
    @ObservedObject var audioManager: AudioManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isFavorite = false
    @State private var isAnimating = false
    @State private var showingPlaylistSelection = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Optional leading element (track number for queue, etc.)
            if let leadingElement = context.leadingElement {
                leadingElement
                    .frame(width: 20)
            }
            
            // Thumbnail
            TrackThumbnail(track: track, size: context.thumbnailSize)
            
            // Track info
            TrackInfo(track: track, isCurrentTrack: context.isCurrentTrack)
            
            Spacer()
            
            // Action buttons
            TrackActionButtons(
                track: track,
                context: context,
                audioManager: audioManager,
                isFavorite: isFavorite,
                isAnimating: isAnimating,
                onToggleFavorite: { toggleFavorite() },
                onPlay: { playTrack() },
                onAddToQueue: { QueueManager.shared.addToQueue(track) },
                onRemove: context.onRemove
            )
        }
        .padding(.vertical, context.verticalPadding)
        .background(context.backgroundColor)
        .cornerRadius(context.cornerRadius)
        .contentShape(Rectangle())
        .contextMenu {
            PlaylistContextMenu(track: track, isFavorite: isFavorite)
        }
        .playlistSelectionSheet(isPresented: $showingPlaylistSelection, track: track)
        .onAppear {
            checkIfFavorite()
        }
        .onChange(of: showingPlaylistSelection) { isPresented in
            // Refresh favorite status when sheet is dismissed
            if !isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkIfFavorite()
                }
            }
        }
    }
    
    private func getThumbnailURL(from thumbnailString: String?) -> URL? {
        guard let thumbnailString = thumbnailString,
              !thumbnailString.isEmpty else {
            return URL(string: "https://i.ytimg.com/vi/\(track.id)/hqdefault.jpg")
        }
        
        let cleanedString = thumbnailString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: cleanedString), url.scheme != nil {
            return url
        }
        
        return URL(string: "https://i.ytimg.com/vi/\(track.id)/hqdefault.jpg")
    }
    
    private func playTrack() {
        if let customPlayAction = context.onPlay {
            customPlayAction()
        } else {
            // Default play behavior
            defaultPlayTrack()
        }
    }
    
    private func defaultPlayTrack() {
        // Show loading immediately for instant feedback
        audioManager.currentTrack = track
        audioManager.isLoading = true
        audioManager.isPlaying = false
        
        // Add to queue if not already there
        let queueManager = QueueManager.shared
        if !queueManager.queue.contains(where: { $0.id == track.id }) {
            queueManager.addToQueue(track)
            queueManager.currentIndex = queueManager.queue.count - 1
        } else {
            // Find and set current index
            if let index = queueManager.queue.firstIndex(where: { $0.id == track.id }) {
                queueManager.currentIndex = index
            }
        }
        
        // Start audio playback
        Task { @MainActor in
            await audioManager.play(track: track)
        }
    }
    
    private func checkIfFavorite() {
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND isFavorite == YES", track.id)
        
        do {
            let existingTracks = try viewContext.fetch(request)
            isFavorite = !existingTracks.isEmpty
        } catch {
            print("Failed to check favorite status: \(error)")
        }
    }
    
    private func toggleFavorite() {
        // Trigger animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation {
                isAnimating = false
            }
        }
        
        // Show playlist selection popup
        showingPlaylistSelection = true
    }
}

// MARK: - Supporting Components

struct TrackThumbnail: View {
    let track: YTVideoInfo
    let size: CGSize
    
    var body: some View {
        AsyncImage(url: getThumbnailURL(from: track.thumbnailURL)) { phase in
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
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func getThumbnailURL(from thumbnailString: String?) -> URL? {
        guard let thumbnailString = thumbnailString,
              !thumbnailString.isEmpty else {
            return URL(string: "https://i.ytimg.com/vi/\(track.id)/hqdefault.jpg")
        }
        
        let cleanedString = thumbnailString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: cleanedString), url.scheme != nil {
            return url
        }
        
        return URL(string: "https://i.ytimg.com/vi/\(track.id)/hqdefault.jpg")
    }
}

struct TrackInfo: View {
    let track: YTVideoInfo
    let isCurrentTrack: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(isCurrentTrack ? .blue : .primary)
            
            Text(track.uploader)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if track.duration > 0 {
                Text(formatDuration(track.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("--:--")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct TrackActionButtons: View {
    let track: YTVideoInfo
    let context: TrackRowContext
    @ObservedObject var audioManager: AudioManager
    let isFavorite: Bool
    let isAnimating: Bool
    let onToggleFavorite: () -> Void
    let onPlay: () -> Void
    let onAddToQueue: () -> Void
    let onRemove: (() -> Void)?
    
    @StateObject private var downloadManager = MultiDownloadManager.shared
    @State private var isRemoving = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Play/Pause button
            Button(action: {
                if audioManager.currentTrack?.id == track.id && audioManager.isPlaying {
                    audioManager.togglePlayPause()
                } else {
                    onPlay()
                }
            }) {
                Group {
                    if audioManager.currentTrack?.id == track.id && audioManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if audioManager.currentTrack?.id == track.id && audioManager.isPlaying {
                        Image(systemName: "pause.circle.fill")
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                }
                .font(context.buttonFont)
                .foregroundColor(downloadManager.isDownloaded(track.id) ? .green : .accentColor)
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            
            // Add to queue button (if enabled)
            if context.showAddToQueue {
                Button(action: onAddToQueue) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Favorite button (if enabled)
            if context.showFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(isFavorite ? .red : .secondary)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                        .animation(.easeInOut(duration: 0.2), value: isFavorite)
                }
                .buttonStyle(.plain)
            }
            
            // Download button (if enabled and not already downloaded)
            if context.showDownload && !downloadManager.isDownloaded(track.id) {
                DownloadButton(track: track, downloadManager: downloadManager)
            }
            
            // Remove button (if provided)
            if let removeAction = onRemove {
                Button(action: {
                    guard !isRemoving else { return }
                    isRemoving = true
                    
                    withAnimation(.easeOut(duration: 0.2)) {
                        removeAction()
                    }
                    
                    // Reset the removing state after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isRemoving = false
                    }
                }) {
                    Group {
                        if isRemoving {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: context.removeButtonIcon)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(isRemoving ? .secondary : context.removeButtonColor)
                }
                .buttonStyle(.plain)
                .disabled(isRemoving)
            }
        }
    }
}

// MARK: - Context Configuration

struct TrackRowContext {
    let showAddToQueue: Bool
    let showFavorite: Bool
    let showDownload: Bool
    let thumbnailSize: CGSize
    let buttonFont: Font
    let verticalPadding: CGFloat
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let isCurrentTrack: Bool
    let leadingElement: AnyView?
    let onPlay: (() -> Void)?
    let onRemove: (() -> Void)?
    let removeButtonIcon: String
    let removeButtonColor: Color
    
    // Predefined contexts
    static func searchResult(isCurrentTrack: Bool = false) -> TrackRowContext {
        TrackRowContext(
            showAddToQueue: true,
            showFavorite: true,
            showDownload: true,
            thumbnailSize: CGSize(width: 64, height: 36),
            buttonFont: .title2,
            verticalPadding: 8,
            backgroundColor: .clear,
            cornerRadius: 0,
            isCurrentTrack: isCurrentTrack,
            leadingElement: nil,
            onPlay: nil,
            onRemove: nil,
            removeButtonIcon: "trash",
            removeButtonColor: .red
        )
    }
    
    static func favorite(onRemove: @escaping () -> Void, isCurrentTrack: Bool = false) -> TrackRowContext {
        TrackRowContext(
            showAddToQueue: true,
            showFavorite: false, // Don't show favorite button in favorites list
            showDownload: true,
            thumbnailSize: CGSize(width: 56, height: 32),
            buttonFont: .title3,
            verticalPadding: 6,
            backgroundColor: .clear,
            cornerRadius: 0,
            isCurrentTrack: isCurrentTrack,
            leadingElement: nil,
            onPlay: nil,
            onRemove: onRemove,
            removeButtonIcon: "trash",
            removeButtonColor: .red
        )
    }
    
    static func queue(
        index: Int,
        isCurrentTrack: Bool,
        onPlay: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) -> TrackRowContext {
        let leadingElement: AnyView
        if isCurrentTrack {
            leadingElement = AnyView(
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
            )
        } else {
            leadingElement = AnyView(
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
        }
        
        return TrackRowContext(
            showAddToQueue: false,
            showFavorite: false,
            showDownload: false, // No download in queue
            thumbnailSize: CGSize(width: 40, height: 24),
            buttonFont: .system(size: 18),
            verticalPadding: 4,
            backgroundColor: isCurrentTrack ? Color.blue.opacity(0.1) : .clear,
            cornerRadius: 6,
            isCurrentTrack: isCurrentTrack,
            leadingElement: leadingElement,
            onPlay: onPlay,
            onRemove: onRemove,
            removeButtonIcon: "minus.circle",
            removeButtonColor: .red
        )
    }
    
    static func download(
        isSelected: Bool,
        isSelectionMode: Bool,
        isCurrentTrack: Bool = false,
        onPlay: @escaping () -> Void,
        onToggleSelection: @escaping () -> Void
    ) -> TrackRowContext {
        let leadingElement: AnyView? = isSelectionMode ? AnyView(
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        ) : nil
        
        return TrackRowContext(
            showAddToQueue: true,
            showFavorite: true,
            showDownload: false, // Already downloaded
            thumbnailSize: CGSize(width: 64, height: 36),
            buttonFont: .title2,
            verticalPadding: 8,
            backgroundColor: isSelected ? Color.blue.opacity(0.1) : .clear,
            cornerRadius: 8,
            isCurrentTrack: isCurrentTrack,
            leadingElement: leadingElement,
            onPlay: onPlay,
            onRemove: nil,
            removeButtonIcon: "trash",
            removeButtonColor: .red
        )
    }
}

// MARK: - Download Button Component

struct DownloadButton: View {
    let track: YTVideoInfo
    @ObservedObject var downloadManager: MultiDownloadManager
    
    var body: some View {
        Button(action: {
            handleDownloadAction()
        }) {
            Group {
                if let progress = downloadManager.activeDownloads[track.id] {
                    // Show progress while downloading
                    if progress.error != nil {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    } else {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                            Circle()
                                .trim(from: 0, to: progress.progress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            
                            if progress.progress < 0.01 {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Text("\(Int(progress.progress * 100))")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(width: 16, height: 16)
                    }
                } else if downloadManager.isDownloaded(track.id) {
                    // Downloaded - show play from local file option
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                } else {
                    // Not downloaded
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                }
            }
            .font(.system(size: 16))
        }
        .buttonStyle(.plain)
        .disabled(downloadManager.isDownloading(track.id) && downloadManager.activeDownloads[track.id]?.error == nil)
    }
    
    private func handleDownloadAction() {
        if downloadManager.isDownloaded(track.id) {
            // Already downloaded - play local file directly
            if let localFilePath = downloadManager.findDownloadedFile(for: track.id) {
                print("🚀 Playing downloaded track from download button: \(track.title)")
                Task { @MainActor in
                    await AudioManager.shared.playLocalFile(track: track, filePath: localFilePath)
                }
            } else {
                print("❌ Track marked as downloaded but file not found: \(track.title)")
            }
        } else if downloadManager.isDownloading(track.id) {
            // Cancel download
            downloadManager.cancelDownload(for: track.id)
        } else {
            // Start download
            Task { @MainActor in
                do {
                    try await downloadManager.downloadTrack(track)
                } catch {
                    print("Download failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Playlist Context Menu

struct PlaylistContextMenu: View {
    let track: YTVideoInfo
    let isFavorite: Bool
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var playlists: [Playlist] = []
    
    var body: some View {
        Group {
            // Play action
            Button("Play") {
                Task { @MainActor in
                    await AudioManager.shared.play(track: track)
                }
            }
            
            // Add to Queue
            Button("Add to Queue") {
                QueueManager.shared.addToQueue(track)
            }
            
            Divider()
            
            // Favorite toggle
            if isFavorite {
                Button("Remove from Favorites") {
                    removeFavorite()
                }
            } else {
                Button("Add to Favorites") {
                    addToFavorites()
                }
            }
            
            // Add to playlist submenu
            if !playlists.isEmpty {
                Menu("Add to Playlist") {
                    ForEach(playlists, id: \.objectID) { playlist in
                        Button(playlist.name ?? "Unknown") {
                            addToPlaylist(playlist)
                        }
                    }
                }
            }
            
            Divider()
            
            // Download action
            if !MultiDownloadManager.shared.isDownloaded(track.id) {
                Button("Download") {
                    downloadTrack()
                }
            }
        }
        .onAppear {
            loadPlaylists()
        }
    }
    
    private func loadPlaylists() {
        playlists = favoritesManager.getAllPlaylists().filter { !$0.isSystemPlaylist }
    }
    
    private func addToFavorites() {
        favoritesManager.addTrackToFavorites(track)
    }
    
    private func removeFavorite() {
        // Find and remove the track from Core Data
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", track.id)
        
        do {
            let existingTracks = try context.fetch(request)
            if let existingTrack = existingTracks.first {
                favoritesManager.removeTrackFromPlaylist(existingTrack)
            }
        } catch {
            print("Failed to remove favorite: \(error)")
        }
    }
    
    private func addToPlaylist(_ playlist: Playlist) {
        favoritesManager.addTrackToPlaylist(track, playlist: playlist)
    }
    
    private func downloadTrack() {
        Task { @MainActor in
            do {
                try await MultiDownloadManager.shared.downloadTrack(track)
            } catch {
                print("Download failed: \(error)")
            }
        }
    }
}