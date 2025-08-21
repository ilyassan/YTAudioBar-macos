//
//  AppDelegate.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: NSStatusBar!
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon to make it a proper menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status bar item
        statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        // Set the status bar button
        if let statusBarButton = statusBarItem.button {
            // Use a custom music note icon that's more visible
            let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "YTAudioBar")
            image?.size = NSSize(width: 18, height: 18)
            statusBarButton.image = image
            statusBarButton.imagePosition = .imageOnly
            statusBarButton.action = #selector(togglePopover(_:))
            statusBarButton.target = self
            statusBarButton.toolTip = "YTAudioBar - Click to open"
        }
        
        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        )
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if statusBarItem.button != nil {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    func showPopover() {
        guard let button = statusBarItem.button else { return }
        
        // Activate the app when showing popover
        NSApp.activate(ignoringOtherApps: true)
        
        // Show popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        
        // Visual feedback - highlight the status bar button
        button.highlight(true)
    }
    
    func closePopover() {
        popover.performClose(nil)
        
        // Remove highlight from status bar button
        if let button = statusBarItem.button {
            button.highlight(false)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
}