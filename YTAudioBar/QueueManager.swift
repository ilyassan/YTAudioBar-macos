//
//  QueueManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import Foundation
import Combine

class QueueManager: ObservableObject {
    static let shared = QueueManager()
    
    @Published var queue: [YTVideoInfo] = []
    @Published var currentIndex: Int = -1
    @Published var shuffleMode: Bool = false
    @Published var repeatMode: RepeatMode = .off
    
    private var originalQueue: [YTVideoInfo] = [] // Store original order for shuffle
    
    private init() {}
    
    // MARK: - Queue Operations
    
    func addToQueue(_ track: YTVideoInfo) {
        queue.append(track)
        if shuffleMode {
            originalQueue.append(track)
        }
        print("➕ Added to queue: \(track.title)")
    }
    
    func addToQueue(_ tracks: [YTVideoInfo]) {
        queue.append(contentsOf: tracks)
        if shuffleMode {
            originalQueue.append(contentsOf: tracks)
        }
        print("➕ Added \(tracks.count) tracks to queue")
    }
    
    func insertNext(_ track: YTVideoInfo) {
        let insertIndex = currentIndex + 1
        if insertIndex < queue.count {
            queue.insert(track, at: insertIndex)
        } else {
            queue.append(track)
        }
        
        if shuffleMode {
            originalQueue.append(track)
        }
        print("⏭️ Inserted next: \(track.title)")
    }
    
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        
        let removedTrack = queue.remove(at: index)
        
        // Update current index if necessary
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex && currentIndex >= queue.count {
            currentIndex = queue.count - 1
        }
        
        // Remove from original queue if shuffling
        if shuffleMode {
            if let originalIndex = originalQueue.firstIndex(where: { $0.id == removedTrack.id }) {
                originalQueue.remove(at: originalIndex)
            }
        }
        
        print("➖ Removed from queue: \(removedTrack.title)")
    }
    
    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < queue.count &&
              destinationIndex >= 0 && destinationIndex < queue.count else { return }
        
        let track = queue.remove(at: sourceIndex)
        queue.insert(track, at: destinationIndex)
        
        // Update current index
        if sourceIndex == currentIndex {
            currentIndex = destinationIndex
        } else if sourceIndex < currentIndex && destinationIndex >= currentIndex {
            currentIndex -= 1
        } else if sourceIndex > currentIndex && destinationIndex <= currentIndex {
            currentIndex += 1
        }
        
        print("🔄 Moved track from \(sourceIndex) to \(destinationIndex)")
    }
    
    func clearQueue() {
        queue.removeAll()
        originalQueue.removeAll()
        currentIndex = -1
        print("🗑️ Queue cleared")
    }
    
    // MARK: - Playback Navigation
    
    func playTrack(at index: Int) -> YTVideoInfo? {
        guard index >= 0 && index < queue.count else { return nil }
        currentIndex = index
        let track = queue[index]
        print("▶️ Playing queue track \(index + 1)/\(queue.count): \(track.title)")
        return track
    }
    
    func playNext() -> YTVideoInfo? {
        guard !queue.isEmpty else { return nil }
        
        switch repeatMode {
        case .off:
            if currentIndex + 1 < queue.count {
                currentIndex += 1
                let track = queue[currentIndex]
                print("⏭️ Next track: \(track.title)")
                return track
            }
        case .one:
            // Repeat current track
            if currentIndex >= 0 && currentIndex < queue.count {
                let track = queue[currentIndex]
                print("🔂 Repeating track: \(track.title)")
                return track
            }
        case .all:
            currentIndex = (currentIndex + 1) % queue.count
            let track = queue[currentIndex]
            print("⏭️ Next track (repeat all): \(track.title)")
            return track
        }
        
        return nil
    }
    
    func playPrevious() -> YTVideoInfo? {
        guard !queue.isEmpty else { return nil }
        
        switch repeatMode {
        case .off:
            if currentIndex > 0 {
                currentIndex -= 1
                let track = queue[currentIndex]
                print("⏮️ Previous track: \(track.title)")
                return track
            }
        case .one:
            // Repeat current track
            if currentIndex >= 0 && currentIndex < queue.count {
                let track = queue[currentIndex]
                print("🔂 Repeating track: \(track.title)")
                return track
            }
        case .all:
            currentIndex = currentIndex <= 0 ? queue.count - 1 : currentIndex - 1
            let track = queue[currentIndex]
            print("⏮️ Previous track (repeat all): \(track.title)")
            return track
        }
        
        return nil
    }
    
    func getCurrentTrack() -> YTVideoInfo? {
        guard currentIndex >= 0 && currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
    
    func hasNext() -> Bool {
        switch repeatMode {
        case .off:
            return currentIndex + 1 < queue.count
        case .one, .all:
            return !queue.isEmpty
        }
    }
    
    func hasPrevious() -> Bool {
        switch repeatMode {
        case .off:
            return currentIndex > 0
        case .one, .all:
            return !queue.isEmpty
        }
    }
    
    // MARK: - Shuffle & Repeat
    
    func toggleShuffle() {
        shuffleMode.toggle()
        
        if shuffleMode {
            // Store original order
            originalQueue = queue
            
            // Shuffle queue but keep current track at current position
            var shuffledQueue = queue
            if currentIndex >= 0 && currentIndex < queue.count {
                let currentTrack = shuffledQueue.remove(at: currentIndex)
                shuffledQueue.shuffle()
                shuffledQueue.insert(currentTrack, at: 0)
                currentIndex = 0
            } else {
                shuffledQueue.shuffle()
            }
            queue = shuffledQueue
            
            print("🔀 Shuffle enabled")
        } else {
            // Restore original order
            if !originalQueue.isEmpty {
                let currentTrack = getCurrentTrack()
                queue = originalQueue
                
                // Find current track in original order
                if let track = currentTrack,
                   let newIndex = queue.firstIndex(where: { $0.id == track.id }) {
                    currentIndex = newIndex
                } else {
                    currentIndex = -1
                }
            }
            originalQueue.removeAll()
            
            print("🔀 Shuffle disabled")
        }
    }
    
    func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
            print("🔁 Repeat all enabled")
        case .all:
            repeatMode = .one
            print("🔂 Repeat one enabled")
        case .one:
            repeatMode = .off
            print("🔁 Repeat disabled")
        }
    }
    
    // MARK: - Queue Info
    
    var queueInfo: String {
        guard !queue.isEmpty else { return "Queue is empty" }
        
        let currentPosition = currentIndex + 1
        let totalTracks = queue.count
        
        var info = "Track \(max(1, currentPosition))/\(totalTracks)"
        
        if shuffleMode {
            info += " • Shuffled"
        }
        
        switch repeatMode {
        case .all:
            info += " • Repeat All"
        case .one:
            info += " • Repeat One"
        case .off:
            break
        }
        
        return info
    }
}

// MARK: - Repeat Mode

enum RepeatMode {
    case off
    case all
    case one
}