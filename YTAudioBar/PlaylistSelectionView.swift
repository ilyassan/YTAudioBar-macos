//
//  PlaylistSelectionView.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import SwiftUI
import CoreData

struct PlaylistSelectionView: View {
    let track: YTVideoInfo
    let onDismiss: () -> Void
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var playlists: [Playlist] = []
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var animateIn = false
    
    var body: some View {
        // Centered modal popup
        ZStack {
            VStack(spacing: 0) {
                // Clean Header
                HStack {
                    Text("Add to Playlist")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color(NSColor.windowBackgroundColor))
                
                // Track title
                Text(track.title)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                
                Divider()
                
                // Compact playlists list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(playlists, id: \.objectID) { playlist in
                            CompactPlaylistRow(
                                playlist: playlist,
                                track: track,
                                onSelected: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        addTrackToPlaylist(playlist)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 240)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Create new playlist button
                Button(action: { isCreatingPlaylist = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.accentColor))
                        
                        Text("Create New Playlist")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(NSColor.windowBackgroundColor))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
            )
            .scaleEffect(animateIn ? 1.0 : 0.95)
            .opacity(animateIn ? 1.0 : 0.0)
        }
        .onAppear {
            loadPlaylists()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                animateIn = true
            }
        }
        .alert("Create Playlist", isPresented: $isCreatingPlaylist) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Create & Add") {
                createPlaylistAndAdd()
            }
            .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                newPlaylistName = ""
            }
        } message: {
            Text("Enter a name for your new playlist")
        }
    }
    
    private func loadPlaylists() {
        playlists = favoritesManager.getAllPlaylists()
    }
    
    private func addTrackToPlaylist(_ playlist: Playlist) {
        if playlist.name == "All Favorites" {
            favoritesManager.addTrackToFavorites(track)
        } else {
            favoritesManager.addTrackToPlaylist(track, playlist: playlist)
        }
        onDismiss()
    }
    
    private func createPlaylistAndAdd() {
        let trimmedName = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newPlaylist = favoritesManager.createPlaylist(name: trimmedName)
        favoritesManager.addTrackToPlaylist(track, playlist: newPlaylist)
        newPlaylistName = ""
        onDismiss()
    }
}

struct CompactPlaylistRow: View {
    let playlist: Playlist
    let track: YTVideoInfo
    let onSelected: () -> Void
    
    @State private var isTrackInPlaylist = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            if !isTrackInPlaylist {
                onSelected()
            }
        }) {
            HStack(spacing: 12) {
                // Simple icon - only show filled heart if track is actually in favorites
                Image(systemName: playlist.isSystemPlaylist ? (isTrackInPlaylist ? "heart.fill" : "heart") : "music.note.list")
                    .font(.system(size: 16))
                    .foregroundColor(playlist.isSystemPlaylist ? .red : .accentColor)
                    .frame(width: 20)
                
                // Playlist info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name ?? "Unknown")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(playlist.tracks?.count ?? 0) tracks")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                if isTrackInPlaylist {
                    Text("✓")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .fill(
                        isTrackInPlaylist 
                        ? Color.green.opacity(0.08)
                        : (isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isTrackInPlaylist)
        .onHover { hovering in
            isHovered = hovering && !isTrackInPlaylist
        }
        .onAppear {
            checkIfTrackInPlaylist()
        }
    }
    
    private func checkIfTrackInPlaylist() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        
        if playlist.name == "All Favorites" {
            request.predicate = NSPredicate(format: "id == %@ AND isFavorite == YES", track.id)
        } else {
            request.predicate = NSPredicate(format: "id == %@ AND playlist == %@", track.id, playlist)
        }
        
        do {
            let existingTracks = try context.fetch(request)
            isTrackInPlaylist = !existingTracks.isEmpty
        } catch {
            print("Failed to check if track is in playlist: \(error)")
            isTrackInPlaylist = false
        }
    }
}

// MARK: - Sheet View for Native Presentation

struct PlaylistSelectionSheetView: View {
    let track: YTVideoInfo
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var playlists: [Playlist] = []
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Text("Add to Playlist")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("New Playlist") {
                    isCreatingPlaylist = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Track info
            VStack(spacing: 8) {
                Text(track.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Select a playlist to add this track")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Playlists list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(playlists, id: \.objectID) { playlist in
                        SheetPlaylistRow(
                            playlist: playlist,
                            track: track,
                            onSelected: {
                                addTrackToPlaylist(playlist)
                                dismiss()
                            }
                        )
                    }
                }
            }
        }
        .frame(width: 450, height: 400)
        .onAppear {
            loadPlaylists()
        }
        .alert("Create Playlist", isPresented: $isCreatingPlaylist) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Create & Add") {
                createPlaylistAndAdd()
                dismiss()
            }
            .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                newPlaylistName = ""
            }
        } message: {
            Text("Enter a name for your new playlist")
        }
    }
    
    private func loadPlaylists() {
        playlists = favoritesManager.getAllPlaylists()
    }
    
    private func addTrackToPlaylist(_ playlist: Playlist) {
        if playlist.name == "All Favorites" {
            favoritesManager.addTrackToFavorites(track)
        } else {
            favoritesManager.addTrackToPlaylist(track, playlist: playlist)
        }
    }
    
    private func createPlaylistAndAdd() {
        let trimmedName = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newPlaylist = favoritesManager.createPlaylist(name: trimmedName)
        favoritesManager.addTrackToPlaylist(track, playlist: newPlaylist)
        newPlaylistName = ""
    }
}

struct SheetPlaylistRow: View {
    let playlist: Playlist
    let track: YTVideoInfo
    let onSelected: () -> Void
    
    @State private var isTrackInPlaylist = false
    
    // Real-time track count using @FetchRequest for "All Favorites"
    @FetchRequest private var favoriteTracksCount: FetchedResults<Track>
    
    var trackCount: Int {
        if playlist.name == "All Favorites" {
            return favoriteTracksCount.count
        } else {
            return playlist.tracks?.count ?? 0
        }
    }
    
    init(playlist: Playlist, track: YTVideoInfo, onSelected: @escaping () -> Void) {
        self.playlist = playlist
        self.track = track
        self.onSelected = onSelected
        
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
        Button(action: {
            if !isTrackInPlaylist {
                onSelected()
            }
        }) {
            HStack(spacing: 12) {
                // Playlist icon
                Image(systemName: playlist.isSystemPlaylist ? (isTrackInPlaylist ? "heart.fill" : "heart") : "music.note.list")
                    .font(.system(size: 18))
                    .foregroundColor(playlist.isSystemPlaylist ? .red : .accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name ?? "Unknown")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(trackCount) tracks")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isTrackInPlaylist {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                        Text("Added")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(isTrackInPlaylist ? Color.green.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isTrackInPlaylist)
        .onAppear {
            checkIfTrackInPlaylist()
        }
    }
    
    private func checkIfTrackInPlaylist() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        
        if playlist.name == "All Favorites" {
            request.predicate = NSPredicate(format: "id == %@ AND isFavorite == YES", track.id)
        } else {
            request.predicate = NSPredicate(format: "id == %@ AND playlist == %@", track.id, playlist)
        }
        
        do {
            let existingTracks = try context.fetch(request)
            isTrackInPlaylist = !existingTracks.isEmpty
        } catch {
            print("Failed to check if track is in playlist: \(error)")
            isTrackInPlaylist = false
        }
    }
}

// MARK: - Native SwiftUI Sheet Extension

extension View {
    func playlistSelectionSheet(isPresented: Binding<Bool>, track: YTVideoInfo) -> some View {
        self.sheet(isPresented: isPresented) {
            PlaylistSelectionSheetView(track: track)
        }
    }
}