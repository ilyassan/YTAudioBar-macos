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
        // Create the status bar item
        statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        // Set the status bar button
        if let statusBarButton = statusBarItem.button {
            statusBarButton.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "YTAudioBar")
            statusBarButton.action = #selector(togglePopover(_:))
            statusBarButton.target = self
        }
        
        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        )
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
}