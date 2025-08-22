//
//  PlaylistsView.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import SwiftUI
import CoreData

struct PlaylistsView: View {
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedPlaylist: Playlist?
    @State private var navigationPath = NavigationPath()
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
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Playlists & Favorites")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: { isCreatingPlaylist = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Create New Playlist")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Playlists grid/list
                if playlists.isEmpty {
                    EmptyPlaylistsView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(playlists, id: \.objectID) { playlist in
                                PlaylistCard(
                                    playlist: playlist,
                                    onTap: { 
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            openPlaylist(playlist)
                                        }
                                    },
                                    onShowOptions: { showingPlaylistOptions = playlist }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(
                    playlist: playlist,
                    currentTrack: $currentTrack,
                    audioManager: audioManager
                )
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
        .confirmationDialog(
            "Playlist Options",
            isPresented: Binding(
                get: { showingPlaylistOptions != nil },
                set: { if !$0 { showingPlaylistOptions = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let playlist = showingPlaylistOptions, !playlist.isSystemPlaylist {
                Button("Rename") {
                    renamingPlaylistName = playlist.name ?? ""
                    isRenamingPlaylist = true
                    showingPlaylistOptions = nil
                }
                
                Button("Delete", role: .destructive) {
                    deletePlaylist(playlist)
                }
            }
            
            Button("Cancel", role: .cancel) {
                showingPlaylistOptions = nil
            }
        }
    }
    
    private func openPlaylist(_ playlist: Playlist) {
        navigationPath.append(playlist)
    }
    
    private func createNewPlaylist() {
        let trimmedName = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newPlaylist = favoritesManager.createPlaylist(name: trimmedName)
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
        showingPlaylistOptions = nil
    }
}

struct PlaylistCard: View {
    let playlist: Playlist
    let onTap: () -> Void
    let onShowOptions: () -> Void
    
    // Real-time track count using @FetchRequest for "All Favorites"
    @FetchRequest private var favoriteTracksCount: FetchedResults<Track>
    
    // Custom playlist tracks are handled through the playlist.tracks relationship
    var trackCount: Int {
        if playlist.name == "All Favorites" {
            return favoriteTracksCount.count
        } else {
            return playlist.tracks?.count ?? 0
        }
    }
    
    init(playlist: Playlist, onTap: @escaping () -> Void, onShowOptions: @escaping () -> Void) {
        self.playlist = playlist
        self.onTap = onTap
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
                predicate: NSPredicate(value: false) // Always returns 0 results
            )
        }
    }
    
    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                // Icon
                VStack {
                    Image(systemName: playlist.isSystemPlaylist ? "heart.circle.fill" : "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(playlist.isSystemPlaylist ? .red : .accentColor)
                    
                    Spacer()
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name ?? "Unknown Playlist")
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("\(trackCount) track\(trackCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let createdDate = playlist.createdDate, !playlist.isSystemPlaylist {
                        Text("Created \(createdDate, formatter: relativeDateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            
            // Three dots button positioned in top-right
            if !playlist.isSystemPlaylist {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onShowOptions) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .animation(.easeInOut(duration: 0.15), value: trackCount)
    }
}

struct EmptyPlaylistsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Playlists Yet")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Create your first playlist to organize your favorite songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch tracks for this specific playlist
    @FetchRequest private var tracks: FetchedResults<Track>
    
    init(playlist: Playlist, currentTrack: Binding<Track?>, audioManager: AudioManager) {
        self.playlist = playlist
        self._currentTrack = currentTrack
        self.audioManager = audioManager
        
        // Set up the fetch request based on playlist type
        if playlist.name == "All Favorites" {
            self._tracks = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \Track.addedDate, ascending: false)],
                predicate: NSPredicate(format: "isFavorite == YES")
            )
        } else {
            self._tracks = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \Track.addedDate, ascending: false)],
                predicate: NSPredicate(format: "playlist == %@", playlist)
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header with back button
            HStack {
                // Back button
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("Playlists")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .help("Back to Playlists (Esc)")
                
                Spacer()
                
                // Playlist info (centered)
                VStack(spacing: 4) {
                    Text(playlist.name ?? "Unknown Playlist")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text("\(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Playlist icon
                Image(systemName: playlist.isSystemPlaylist ? "heart.circle.fill" : "music.note.list")
                    .font(.system(size: 20))
                    .foregroundColor(playlist.isSystemPlaylist ? .red : .accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Tracks list content area with solid background
            if tracks.isEmpty {
                EmptyPlaylistTracksView(playlistName: playlist.name ?? "playlist")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(tracks, id: \.objectID) { track in
                            PlaylistTrackRow(
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
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("")
        .toolbar(.hidden)
    }
    
    private func removeTrackFromPlaylist(_ track: Track) {
        withAnimation(.easeInOut(duration: 0.25)) {
            FavoritesManager.shared.removeTrackFromPlaylist(track)
        }
    }
}

struct EmptyPlaylistTracksView: View {
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
                
                Text("Add tracks to \"\(playlistName)\" by using the heart button on any track")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PlaylistTrackRow: View {
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

private let relativeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
}()