import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register Apple Event handler for custom URL scheme
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    // ✅ This is the only place where we handle incoming Spotify auth callback
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            print("❌ Invalid URL received")
            return
        }

        print("💥 open urls triggered – received: \(url)")
        NSApplication.shared.activate(ignoringOtherApps: true)

        SpotifyAuthManager.shared.handleRedirect(url: url) { success in
            if success {
                print("✅ Successfully authenticated with Spotify")
            } else {
                print("❌ Failed to authenticate with Spotify")
            }
        }
    }

}
