//
//  YTAudioBarApp.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import SwiftUI

@main
struct YTAudioBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
