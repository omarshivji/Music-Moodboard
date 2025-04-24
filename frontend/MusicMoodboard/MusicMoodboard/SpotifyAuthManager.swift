import Foundation
import AppKit

class SpotifyAuthManager: ObservableObject {
    static let shared = SpotifyAuthManager()

    let clientId = "58ed93f704e94eb78e73e6f72f8238c2"  // Replace with your actual client ID
    let clientSecret = "7df7d4ddb19b4717b0736ac262b83564"  // Replace with your actual client secret
    let redirectUri = "MusicMoodboard://callback"  // Replace with your app's redirect URI
    let scopes = "user-library-read"  // Adjust as needed for your app's required scopes

    var accessToken: String?

    // Spotify Authorization URL (where user will authenticate)
    var authURL: URL? {
        // Use URLComponents to build the URL
        var urlComponents = URLComponents(string: "https://accounts.spotify.com/authorize")
        urlComponents?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        
        guard let url = urlComponents?.url else {
            print("Error: Failed to generate the URL from components")
            return nil
        }
        
        print("Final URL String: \(url)")  // Log the final URL string
        return url
    }

    // Start the authorization process
    func startAuthorization() {
        if let authURL = authURL {
            print("Authorization URL: \(authURL)")  // Debugging line
            NSWorkspace.shared.open(authURL)
        } else {
            print("Error: Failed to generate the authorization URL")
        }
    }


    // Handle the redirect URL after Spotify authorization
    func handleRedirect(url: URL, completion: @escaping (Bool) -> Void) {
        // Ensure the URL starts with the redirect URI
        guard url.absoluteString.starts(with: redirectUri) else { return }
        
        // Extract the code from the URL's query parameters
        let queryItems = URLComponents(string: url.absoluteString)?.queryItems
        guard let code = queryItems?.first(where: { $0.name == "code" })?.value else {
            print("Error: Authorization code not found")
            completion(false)
            return
        }
        
        // Exchange the code for the access token
        exchangeCodeForToken(code: code, completion: completion)
    }

    // Exchange the authorization code for an access token
    func exchangeCodeForToken(code: String, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        
        let bodyParams = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectUri)"
        request.httpBody = bodyParams.data(using: .utf8)

        // Create the authorization header using client ID and secret
        let authString = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Perform the network request to get the token
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else {
                print("Error: Failed to exchange code for access token.")
                completion(false)
                return
            }

            // Save the access token
            self.accessToken = token
            print("✅ Spotify Access Token: \(token)")
            completion(true)
        }.resume()
    }
}
