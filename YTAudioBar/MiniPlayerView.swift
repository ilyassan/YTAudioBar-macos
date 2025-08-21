//
//  MiniPlayerView.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import SwiftUI
import CoreData

struct MiniPlayerView: View {
    @Binding var currentTrack: Track?
    @Binding var isPlaying: Bool
    @State private var currentPosition: Double = 0
    @State private var duration: Double = 0
    @State private var volume: Double = 0.7
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text("Now Playing")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.controlBackgroundColor))
            
            if let track = currentTrack {
                VStack(spacing: 20) {
                    // Album art placeholder and track info
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            )
                        
                        VStack(spacing: 6) {
                            Text(track.title ?? "Unknown Track")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            Text(track.author ?? "Unknown Artist")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Progress bar
                    VStack(spacing: 8) {
                        Slider(value: $currentPosition, in: 0...duration) { editing in
                            if !editing {
                                // TODO: Seek to position
                            }
                        }
                        .disabled(duration == 0)
                        
                        HStack {
                            Text(formatTime(currentPosition))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formatTime(duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Playback controls
                    HStack(spacing: 30) {
                        Button(action: {
                            // TODO: Previous track
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            isPlaying.toggle()
                            // TODO: Implement actual play/pause
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // TODO: Next track
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Volume control
                    HStack(spacing: 12) {
                        Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        Slider(value: $volume, in: 0...1) { _ in
                            // TODO: Update volume
                        }
                        
                        Text("\(Int(volume * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            // TODO: Toggle favorite
                        }) {
                            Image(systemName: (track.isFavorite ? "heart.fill" : "heart"))
                                .foregroundColor(track.isFavorite ? .red : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // TODO: Add to queue
                        }) {
                            Image(systemName: "text.badge.plus")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // TODO: Download track
                        }) {
                            Image(systemName: track.isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .foregroundColor(track.isDownloaded ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // TODO: Share track
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.title2)
                }
                .padding(20)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("No Track Playing")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Select a track from the menu bar to start playing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }
        }
        .frame(width: 320, height: 480)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            // TODO: Load current track duration
            duration = Double(currentTrack?.duration ?? 0)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

class MiniPlayerWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "YTAudioBar Mini Player"
        window.setFrameAutosaveName("MiniPlayer")
        window.isRestorable = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Center the window
        window.center()
        
        self.init(window: window)
        
        // Set up the SwiftUI content
        let hostingController = NSHostingController(rootView: 
            MiniPlayerView(currentTrack: .constant(nil), isPlaying: .constant(false))
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        )
        
        window.contentViewController = hostingController
    }
    
    func updateTrack(_ track: Track?, isPlaying: Bool) {
        let newView = MiniPlayerView(
            currentTrack: .constant(track),
            isPlaying: .constant(isPlaying)
        )
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        
        let newHostingController = NSHostingController(rootView: newView)
        window?.contentViewController = newHostingController
    }
}

#Preview {
    MiniPlayerView(currentTrack: .constant(nil), isPlaying: .constant(false))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}