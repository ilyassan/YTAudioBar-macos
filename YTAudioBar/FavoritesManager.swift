//
//  FavoritesManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import Foundation
import CoreData
import Combine

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var selectedPlaylist: Playlist?
    
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        setupDefaultPlaylists()
    }
    
    // MARK: - Playlist Management
    
    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(context: viewContext)
        playlist.id = UUID()
        playlist.name = name
        playlist.createdDate = Date()
        playlist.isSystemPlaylist = false
        
        do {
            try viewContext.save()
            print("✅ Created playlist: \(name)")
        } catch {
            print("❌ Failed to create playlist: \(error)")
        }
        
        return playlist
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        guard !playlist.isSystemPlaylist else {
            print("❌ Cannot delete system playlist")
            return
        }
        
        viewContext.delete(playlist)
        
        do {
            try viewContext.save()
            print("✅ Deleted playlist: \(playlist.name ?? "Unknown")")
        } catch {
            print("❌ Failed to delete playlist: \(error)")
        }
    }
    
    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        guard !playlist.isSystemPlaylist else {
            print("❌ Cannot rename system playlist")
            return
        }
        
        playlist.name = newName
        
        do {
            try viewContext.save()
            print("✅ Renamed playlist to: \(newName)")
        } catch {
            print("❌ Failed to rename playlist: \(error)")
        }
    }
    
    // MARK: - Track Management
    
    func addTrackToFavorites(_ videoInfo: YTVideoInfo) {
        // Check if track already exists
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", videoInfo.id)
        
        do {
            let existingTracks = try viewContext.fetch(request)
            
            if let existingTrack = existingTracks.first {
                // Track exists, just mark as favorite
                existingTrack.isFavorite = true
            } else {
                // Create new track
                let newTrack = Track(context: viewContext)
                newTrack.id = videoInfo.id
                newTrack.title = videoInfo.title
                newTrack.author = videoInfo.uploader
                newTrack.duration = Int32(videoInfo.duration)
                newTrack.thumbnailURL = videoInfo.thumbnailURL
                newTrack.addedDate = Date()
                newTrack.isFavorite = true
                newTrack.isDownloaded = false
                
                // Add to "All Favorites" playlist by default
                if let favoritesPlaylist = getFavoritesPlaylist() {
                    newTrack.playlist = favoritesPlaylist
                }
            }
            
            try viewContext.save()
            print("✅ Added to favorites: \(videoInfo.title)")
            
        } catch {
            print("❌ Failed to add to favorites: \(error)")
        }
    }
    
    func addTrackToPlaylist(_ videoInfo: YTVideoInfo, playlist: Playlist) {
        // Check if track already exists
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", videoInfo.id)
        
        do {
            let existingTracks = try viewContext.fetch(request)
            
            let track: Track
            if let existingTrack = existingTracks.first {
                track = existingTrack
            } else {
                // Create new track
                track = Track(context: viewContext)
                track.id = videoInfo.id
                track.title = videoInfo.title
                track.author = videoInfo.uploader
                track.duration = Int32(videoInfo.duration)
                track.thumbnailURL = videoInfo.thumbnailURL
                track.addedDate = Date()
                track.isFavorite = false
                track.isDownloaded = false
            }
            
            // Check if track is already in this playlist
            if let currentPlaylist = track.playlist, currentPlaylist == playlist {
                print("⚠️ Track already in playlist: \(playlist.name ?? "Unknown")")
                return
            }
            
            // Add to playlist
            track.playlist = playlist
            
            // Only mark as favorite if adding to the "All Favorites" system playlist
            if playlist.name == "All Favorites" && playlist.isSystemPlaylist {
                track.isFavorite = true
            }
            
            try viewContext.save()
            print("✅ Added to playlist '\(playlist.name ?? "Unknown")': \(videoInfo.title)")
            
        } catch {
            print("❌ Failed to add to playlist: \(error)")
        }
    }
    
    func removeTrackFromPlaylist(_ track: Track) {
        // Find the track in our context to ensure we're working with the right object
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", track.id ?? "")
        
        do {
            let foundTracks = try viewContext.fetch(request)
            
            if let foundTrack = foundTracks.first {
                // Clear playlist and favorite status
                foundTrack.playlist = nil
                foundTrack.isFavorite = false
                
                try viewContext.save()
                viewContext.processPendingChanges()
                
                print("✅ Successfully removed track from favorites: \(track.title ?? "Unknown")")
            } else {
                print("❌ Track not found in context!")
            }
        } catch {
            print("❌ Failed to remove from playlist: \(error)")
        }
    }
    
    func moveTrackToPlaylist(_ track: Track, to playlist: Playlist) {
        track.playlist = playlist
        
        do {
            try viewContext.save()
            print("✅ Moved to playlist '\(playlist.name ?? "Unknown")': \(track.title ?? "Unknown")")
        } catch {
            print("❌ Failed to move to playlist: \(error)")
        }
    }
    
    // MARK: - Utility Functions
    
    private func setupDefaultPlaylists() {
        // Check if "All Favorites" playlist exists
        let request: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        request.predicate = NSPredicate(format: "isSystemPlaylist == YES AND name == %@", "All Favorites")
        
        do {
            let existingPlaylists = try viewContext.fetch(request)
            
            if existingPlaylists.isEmpty {
                // Create default "All Favorites" playlist
                let favoritesPlaylist = Playlist(context: viewContext)
                favoritesPlaylist.id = UUID()
                favoritesPlaylist.name = "All Favorites"
                favoritesPlaylist.createdDate = Date()
                favoritesPlaylist.isSystemPlaylist = true
                
                try viewContext.save()
                print("✅ Created default 'All Favorites' playlist")
            }
        } catch {
            print("❌ Failed to setup default playlists: \(error)")
        }
    }
    
    func getFavoritesPlaylist() -> Playlist? {
        let request: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        request.predicate = NSPredicate(format: "isSystemPlaylist == YES AND name == %@", "All Favorites")
        
        do {
            let playlists = try viewContext.fetch(request)
            return playlists.first
        } catch {
            print("❌ Failed to fetch favorites playlist: \(error)")
            return nil
        }
    }
    
    func getAllPlaylists() -> [Playlist] {
        let request: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Playlist.isSystemPlaylist, ascending: false), // System playlists first
            NSSortDescriptor(keyPath: \Playlist.createdDate, ascending: true)
        ]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ Failed to fetch playlists: \(error)")
            return []
        }
    }
    
    func getTracksInPlaylist(_ playlist: Playlist) -> [Track] {
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "playlist == %@", playlist)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Track.addedDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ Failed to fetch tracks in playlist: \(error)")
            return []
        }
    }
    
    func getAllFavorites() -> [Track] {
        let request: NSFetchRequest<Track> = Track.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Track.addedDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ Failed to fetch all favorites: \(error)")
            return []
        }
    }
}