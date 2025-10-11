//
//  SilentUpdaterDriver.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import Foundation
import Sparkle

class SilentUpdaterDriver: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        // Automatically handle updates silently
        print("🔄 Silent update available: \(update.displayVersionString)")
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        // Always handle updates silently without UI
        print("📅 Scheduled update check - handling silently: \(update.displayVersionString)")
        return true
    }

    func standardUserDriverWillFinishUpdateSession() {
        print("✅ Update session finished")
    }
}
