import Foundation

// MARK: - Fetch Liked Songs
func fetchLikedSongs(authToken: String, completion: @escaping ([Track]?, Error?) -> Void) {
    let url = URL(string: "https://api.spotify.com/v1/me/top/tracks")! // Endpoint for top tracks (liked songs)

    var request = URLRequest(url: url)
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("API error:", error)
            completion(nil, error)
            return
        }
        
        guard let data = data else {
            print("No data returned")
            completion(nil, nil)
            return
        }
        
        // Debug: print the raw JSON
//        print("Raw JSON:", String(data: data, encoding: .utf8) ?? "Couldn't decode")
        
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(SpotifyTopTracksResponse.self, from: data)
            completion(result.items, nil)
        } catch {
            print("Decoding error:", error)
            completion(nil, error)
        }
    }
    
    task.resume()
}

// MARK: - Fetch Playlists
func fetchPlaylists(authToken: String, completion: @escaping ([Playlist]?, Error?) -> Void) {
    let url = URL(string: "https://api.spotify.com/v1/me/playlists")!

    var request = URLRequest(url: url)
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            completion(nil, error)
            return
        }

        guard let data = data else {
            completion(nil, nil)
            return
        }

        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(SpotifyPlaylistsResponse.self, from: data)
            completion(result.items, nil)
        } catch {
            completion(nil, error)
        }
    }

    task.resume()
}

// MARK: - Data Models for Parsing API Responses

struct SpotifyTopTracksResponse: Codable {
    let items: [Track]
}

struct Track: Identifiable, Codable {
    let id: String               // Spotify’s track ID
    let name: String
    let uri: String
    let album: Album
    let artists: [Artist]
}

struct Album: Codable {
    let images: [SpotifyImage]   // They come largest→smallest
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

struct Artist: Identifiable, Codable {
    let id: String               // Spotify’s artist ID
    let name: String
}

struct SpotifyPlaylistsResponse: Codable {
    let items: [Playlist]
}

struct Playlist: Identifiable, Codable {
    let id: String               // Spotify’s playlist ID
    let name: String
    let uri: String
}
