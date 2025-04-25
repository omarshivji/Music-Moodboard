import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ app: NSApplication, open urls: [URL]) {
        print("💥 open urls triggered – received:", urls)
        
        guard let url = urls.first else {
            print("❌ No URL received")
            return
        }
        
        print("▶️ Full URL:", url.absoluteString)
        
        if url.scheme == "MusicMoodboard" {
            print("✅ URL scheme matches")
        } else {
            print("❌ URL scheme mismatch: expected 'MusicMoodboard'")
        }
        
        // Extract the code from the URL query
        if let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value {
            print("🔑 Authorization Code:", code)
            SpotifyAuthManager.shared.exchangeCodeForToken(code: code) { success in
                print(success ? "✅ Token fetched" : "❌ Token fetch failed")
            }
        } else {
            print("❌ Authorization code not found in URL")
        }
    }
}
