//
//  NotificationManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isEnabled = true
    @Published var showTrackChange = true
    @Published var showDownloadComplete = true
    @Published var showDownloadFailed = true
    
    private init() {
        loadSettings()
        requestPermission()
    }
    
    // MARK: - Permission Management
    
    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            
            DispatchQueue.main.async {
                self.isEnabled = granted
                self.saveSettings()
            }
        }
    }
    
    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Methods
    
    func showTrackStarted(_ track: YTVideoInfo) {
        guard isEnabled && showTrackChange else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Now Playing"
        content.body = "\(track.title) - \(track.uploader)"
        content.sound = .default
        
        // Add thumbnail if available
        if let thumbnailURL = track.thumbnailURL,
           let url = URL(string: thumbnailURL) {
            downloadImageForNotification(url: url, content: content, identifier: "track-started-\(track.id)")
        } else {
            scheduleNotification(content: content, identifier: "track-started-\(track.id)")
        }
    }
    
    func showTrackEnded(_ track: YTVideoInfo, hasNext: Bool) {
        guard isEnabled && showTrackChange else { return }
        
        let content = UNMutableNotificationContent()
        content.title = hasNext ? "Track Ended" : "Playback Finished"
        content.body = hasNext ? "Moving to next track..." : "\(track.title) finished playing"
        content.sound = .default
        
        scheduleNotification(content: content, identifier: "track-ended-\(track.id)")
    }
    
    func showDownloadCompleted(_ track: YTVideoInfo) {
        guard isEnabled && showDownloadComplete else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = "\(track.title) - \(track.uploader)"
        content.sound = .default
        
        scheduleNotification(content: content, identifier: "download-complete-\(track.id)")
    }
    
    func showDownloadFailed(_ track: YTVideoInfo, error: String) {
        guard isEnabled && showDownloadFailed else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.body = "\(track.title) - \(error)"
        content.sound = .default
        
        scheduleNotification(content: content, identifier: "download-failed-\(track.id)")
    }
    
    func showQueueEmpty() {
        guard isEnabled && showTrackChange else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Queue Empty"
        content.body = "No more tracks to play"
        content.sound = .default
        
        scheduleNotification(content: content, identifier: "queue-empty")
    }
    
    // MARK: - Helper Methods
    
    private func scheduleNotification(content: UNMutableNotificationContent, identifier: String) {
        // Remove any existing notification with same identifier
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    private func downloadImageForNotification(url: URL, content: UNMutableNotificationContent, identifier: String) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  error == nil,
                  let image = NSImage(data: data) else {
                self.scheduleNotification(content: content, identifier: identifier)
                return
            }
            
            // Save image to temporary directory
            let tempDir = FileManager.default.temporaryDirectory
            let imageURL = tempDir.appendingPathComponent("\(identifier).png")
            
            do {
                // Convert NSImage to PNG data
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    self.scheduleNotification(content: content, identifier: identifier)
                    return
                }
                
                try pngData.write(to: imageURL)
                
                // Create attachment
                let attachment = try UNNotificationAttachment(identifier: "image", url: imageURL, options: nil)
                content.attachments = [attachment]
                
                self.scheduleNotification(content: content, identifier: identifier)
            } catch {
                print("Failed to create notification attachment: \(error)")
                self.scheduleNotification(content: content, identifier: identifier)
            }
        }.resume()
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: "NotificationEnabled") as? Bool ?? true
        showTrackChange = defaults.object(forKey: "NotificationTrackChange") as? Bool ?? true
        showDownloadComplete = defaults.object(forKey: "NotificationDownloadComplete") as? Bool ?? true
        showDownloadFailed = defaults.object(forKey: "NotificationDownloadFailed") as? Bool ?? true
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "NotificationEnabled")
        defaults.set(showTrackChange, forKey: "NotificationTrackChange")
        defaults.set(showDownloadComplete, forKey: "NotificationDownloadComplete")
        defaults.set(showDownloadFailed, forKey: "NotificationDownloadFailed")
    }
    
    // MARK: - Settings Toggle Methods
    
    func toggleEnabled() {
        if !isEnabled {
            requestPermission()
        } else {
            isEnabled = false
            saveSettings()
        }
    }
    
    func toggleTrackChange() {
        showTrackChange.toggle()
        saveSettings()
    }
    
    func toggleDownloadComplete() {
        showDownloadComplete.toggle()
        saveSettings()
    }
    
    func toggleDownloadFailed() {
        showDownloadFailed.toggle()
        saveSettings()
    }
    
    // MARK: - Clear Notifications
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}