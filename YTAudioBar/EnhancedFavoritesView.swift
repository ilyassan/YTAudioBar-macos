//
//  EnhancedFavoritesView.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import SwiftUI
import CoreData

struct EnhancedFavoritesView: View {
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedPlaylist: Playlist?
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var showingPlaylistOptions: Playlist?
    @State private var isRenamingPlaylist = false
    @State private var renamingPlaylistName = ""
    
    // Fetch all playlists
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Playlist.isSystemPlaylist, ascending: false),
            NSSortDescriptor(keyPath: \Playlist.createdDate, ascending: true)
        ],
        animation: .default)
    private var playlists: FetchedResults<Playlist>
    
    // Fetch tracks for selected playlist
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Track.addedDate, ascending: false)],
        predicate: NSPredicate(format: "isFavorite == YES"), // Default predicate
        animation: .default)
    private var tracks: FetchedResults<Track>
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with playlists
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Playlists")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: { isCreatingPlaylist = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("Create New Playlist")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // Playlists list
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(playlists, id: \.objectID) { playlist in
                            PlaylistRow(
                                playlist: playlist,
                                isSelected: selectedPlaylist?.objectID == playlist.objectID,
                                onSelect: { selectPlaylist(playlist) },
                                onShowOptions: { showingPlaylistOptions = playlist }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
            .frame(minWidth: 200, maxWidth: 250)
            .background(Color(NSColor.controlBackgroundColor))
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                if let playlist = selectedPlaylist {
                    // Playlist header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlist.name ?? "Unknown Playlist")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("\(tracks.count) tracks")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !playlist.isSystemPlaylist {
                            Menu {
                                Button("Rename Playlist") {
                                    renamingPlaylistName = playlist.name ?? ""
                                    showingPlaylistOptions = playlist
                                    isRenamingPlaylist = true
                                }
                                
                                Divider()
                                
                                Button("Delete Playlist", role: .destructive) {
                                    deletePlaylist(playlist)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Playlist Options")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Tracks list
                    if tracks.isEmpty {
                        EmptyPlaylistView(playlistName: playlist.name ?? "playlist")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(tracks, id: \.objectID) { track in
                                    EnhancedFavoriteTrackRow(
                                        track: track,
                                        currentTrack: $currentTrack,
                                        audioManager: audioManager,
                                        playlist: playlist,
                                        onRemove: { removeTrackFromPlaylist(track) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                } else {
                    // No playlist selected
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("Select a Playlist")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Choose a playlist from the sidebar to view your favorite tracks")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
        }
        .onAppear {
            // Select "All Favorites" by default
            if selectedPlaylist == nil {
                selectedPlaylist = playlists.first { $0.name == "All Favorites" }
                updateTracksFilter()
            }
        }
        .alert("Create Playlist", isPresented: $isCreatingPlaylist) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Create") {
                createNewPlaylist()
            }
            .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                newPlaylistName = ""
            }
        } message: {
            Text("Enter a name for your new playlist")
        }
        .alert("Rename Playlist", isPresented: $isRenamingPlaylist) {
            TextField("Playlist name", text: $renamingPlaylistName)
            Button("Rename") {
                if let playlist = showingPlaylistOptions {
                    renamePlaylist(playlist)
                }
            }
            .disabled(renamingPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                renamingPlaylistName = ""
                showingPlaylistOptions = nil
            }
        } message: {
            Text("Enter a new name for your playlist")
        }
    }
    
    private func selectPlaylist(_ playlist: Playlist) {
        selectedPlaylist = playlist
        updateTracksFilter()
    }
    
    private func updateTracksFilter() {
        guard let playlist = selectedPlaylist else { return }
        
        // Update the fetch request predicate
        if playlist.name == "All Favorites" {
            tracks.nsPredicate = NSPredicate(format: "isFavorite == YES")
        } else {
            tracks.nsPredicate = NSPredicate(format: "playlist == %@", playlist)
        }
    }
    
    private func createNewPlaylist() {
        let trimmedName = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newPlaylist = favoritesManager.createPlaylist(name: trimmedName)
        selectedPlaylist = newPlaylist
        updateTracksFilter()
        newPlaylistName = ""
    }
    
    private func renamePlaylist(_ playlist: Playlist) {
        let trimmedName = renamingPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        favoritesManager.renamePlaylist(playlist, to: trimmedName)
        renamingPlaylistName = ""
        showingPlaylistOptions = nil
    }
    
    private func deletePlaylist(_ playlist: Playlist) {
        favoritesManager.deletePlaylist(playlist)
        
        // Select "All Favorites" if the deleted playlist was selected
        if selectedPlaylist?.objectID == playlist.objectID {
            selectedPlaylist = playlists.first { $0.name == "All Favorites" }
            updateTracksFilter()
        }
    }
    
    private func removeTrackFromPlaylist(_ track: Track) {
        withAnimation(.easeInOut(duration: 0.25)) {
            favoritesManager.removeTrackFromPlaylist(track)
        }
    }
}

struct PlaylistRow: View {
    let playlist: Playlist
    let isSelected: Bool
    let onSelect: () -> Void
    let onShowOptions: () -> Void
    
    // Real-time track count using @FetchRequest for "All Favorites"
    @FetchRequest private var favoriteTracksCount: FetchedResults<Track>
    
    var trackCount: Int {
        if playlist.name == "All Favorites" {
            return favoriteTracksCount.count
        } else {
            return playlist.tracks?.count ?? 0
        }
    }
    
    init(playlist: Playlist, isSelected: Bool, onSelect: @escaping () -> Void, onShowOptions: @escaping () -> Void) {
        self.playlist = playlist
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onShowOptions = onShowOptions
        
        // Set up real-time fetch request for favorites count
        if playlist.name == "All Favorites" {
            self._favoriteTracksCount = FetchRequest(
                sortDescriptors: [],
                predicate: NSPredicate(format: "isFavorite == YES")
            )
        } else {
            // For non-favorite playlists, use empty fetch request (won't be used)
            self._favoriteTracksCount = FetchRequest(
                sortDescriptors: [],
                predicate: NSPredicate(value: false)
            )
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: playlist.isSystemPlaylist ? "heart.fill" : "music.note.list")
                .font(.system(size: 14))
                .foregroundColor(playlist.isSystemPlaylist ? .red : .primary)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name ?? "Unknown")
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .primary)
                    .lineLimit(1)
                
                if trackCount > 0 {
                    Text("\(trackCount) track\(trackCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !playlist.isSystemPlaylist {
                Button(action: onShowOptions) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isSelected ? 1.0 : 0.0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct EmptyPlaylistView: View {
    let playlistName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Empty Playlist")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Add tracks to \"\(playlistName)\" by hearting them from search results or other tabs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct EnhancedFavoriteTrackRow: View {
    let track: Track
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    let playlist: Playlist
    let onRemove: () -> Void
    
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
                onRemove: onRemove,
                isCurrentTrack: isCurrentTrack
            ),
            audioManager: audioManager
        )
    }
}