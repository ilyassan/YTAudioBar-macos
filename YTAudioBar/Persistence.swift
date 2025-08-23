//
//  Persistence.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create default playlist
        let favoritesPlaylist = Playlist(context: viewContext)
        favoritesPlaylist.id = UUID()
        favoritesPlaylist.name = "All Favorites"
        favoritesPlaylist.createdDate = Date()
        favoritesPlaylist.isSystemPlaylist = true
        
        // Create sample tracks
        let sampleTrack = Track(context: viewContext)
        sampleTrack.id = "sample_id"
        sampleTrack.title = "Sample Track"
        sampleTrack.author = "Sample Author"
        sampleTrack.duration = 180
        sampleTrack.addedDate = Date()
        
        // Create membership to add track to favorites
        let membership = PlaylistMembership(context: viewContext)
        membership.id = UUID()
        membership.addedDate = Date()
        membership.track = sampleTrack
        membership.playlist = favoritesPlaylist
        membership.isFavorite = true
        
        // Create app settings
        let settings = AppSettings(context: viewContext)
        settings.id = UUID()
        settings.defaultDownloadPath = "~/Music/YTAudioBar"
        settings.preferredAudioQuality = "best"
        settings.autoUpdateYTDLP = true
        settings.showMiniPlayer = false
        settings.darkMode = false
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "YTAudioBar")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
