//
//  ContentView.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Track.addedDate, ascending: true)],
        animation: .default)
    private var tracks: FetchedResults<Track>

    var body: some View {
        NavigationView {
            List {
                ForEach(tracks) { track in
                    NavigationLink {
                        VStack(alignment: .leading) {
                            Text(track.title ?? "Unknown Title")
                                .font(.headline)
                            Text(track.author ?? "Unknown Author")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Added: \(track.addedDate ?? Date(), formatter: itemFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(track.title ?? "Unknown Title")
                                .font(.headline)
                            Text(track.author ?? "Unknown Author")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTracks)
            }
            .toolbar {
                ToolbarItem {
                    Button(action: addSampleTrack) {
                        Label("Add Sample Track", systemImage: "plus")
                    }
                }
            }
            Text("Select a track")
        }
    }

    private func addSampleTrack() {
        withAnimation {
            let newTrack = Track(context: viewContext)
            newTrack.id = UUID().uuidString
            newTrack.title = "Sample Track \(Date().timeIntervalSince1970)"
            newTrack.author = "Sample Author"
            newTrack.duration = Int32.random(in: 120...300)
            newTrack.addedDate = Date()
            newTrack.isDownloaded = false

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteTracks(offsets: IndexSet) {
        withAnimation {
            offsets.map { tracks[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
