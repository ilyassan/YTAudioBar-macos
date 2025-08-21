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
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBarView(searchText: $searchText)
            
            // Current track display
            if let track = currentTrack {
                CurrentTrackView(track: track, isPlaying: $isPlaying)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
            }
            
            // Main content area
            TabView {
                SearchResultsView(searchText: searchText, currentTrack: $currentTrack)
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                
                QueueView()
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Queue")
                    }
                
                FavoritesView()
                    .tabItem {
                        Image(systemName: "heart.fill")
                        Text("Favorites")
                    }
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 500)
    }
}

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search YouTube...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.top, 12)
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

// Placeholder views for the tab content
struct SearchResultsView: View {
    let searchText: String
    @Binding var currentTrack: Track?
    
    var body: some View {
        VStack {
            if searchText.isEmpty {
                Text("Enter a search term to find YouTube content")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Text("Search results for: \(searchText)")
                    .padding()
                // TODO: Implement actual search results
            }
            Spacer()
        }
    }
}

struct QueueView: View {
    var body: some View {
        VStack {
            Text("Queue")
                .font(.headline)
                .padding()
            Text("No tracks in queue")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct FavoritesView: View {
    var body: some View {
        VStack {
            Text("Favorites")
                .font(.headline)
                .padding()
            Text("No favorites yet")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.headline)
                .padding()
            Text("Settings will be available here")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

#Preview {
    MenuBarContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}