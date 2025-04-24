import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.scheme == "MusicMoodboard" else { return }

        print("URL received: \(url)")  // Debugging the received URL
        if let code = URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value {
            print("Authorization Code: \(code)")
            
            // Now exchange the code for the access token
            SpotifyAuthManager.shared.exchangeCodeForToken(code: code) { success in
                if success {
                    print("Successfully obtained access token")
                } else {
                    print("Failed to obtain access token")
                }
            }
        } else {
            print("Authorization code not found in the URL")
        }
    }
}
