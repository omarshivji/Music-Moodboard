import Foundation
import Combine

class SpotifyPlaybackManager: ObservableObject {
    @Published var activeDeviceId: String? = nil
    @Published var deviceAvailable: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentTrackName: String? = nil
    @Published var currentArtistName: String? = nil

    private var trackUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func fetchCurrentTrack(authToken: String) {
        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🎵 Current track fetch error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data,
                      let http = response as? HTTPURLResponse,
                      http.statusCode == 200 else {
                    print("🎵 No current track or not playing.")
                    self.currentTrackName = nil
                    self.currentArtistName = nil
                    return
                }
                
                do {
                    let currentlyPlaying = try JSONDecoder().decode(CurrentlyPlayingResponse.self, from: data)
                    self.currentTrackName = currentlyPlaying.item.name
                    self.currentArtistName = currentlyPlaying.item.artists.first?.name
                } catch {
                    print("🎵 Failed to decode current track: \(error)")
                }
            }
        }.resume()
    }
    
    func startUpdatingCurrentTrack(authToken: String) {
        // Invalidate any existing timer first
        trackUpdateTimer?.invalidate()
        
        trackUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.fetchCurrentTrack(authToken: authToken)
        }
        trackUpdateTimer?.fire()  // Optionally fetch immediately
    }

    func stopUpdatingCurrentTrack() {
        trackUpdateTimer?.invalidate()
        trackUpdateTimer = nil
    }


    func goBack(authToken: String) {
           guard let deviceId = activeDeviceId else {
               self.errorMessage = "⚠️ No active device. Open Spotify and tap Refresh."
               return
           }
           let urlString = "https://api.spotify.com/v1/me/player/previous?device_id=\(deviceId)"
           var req = URLRequest(url: URL(string: urlString)!)
           req.httpMethod = "POST"
           req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
           
           URLSession.shared.dataTask(with: req) { _, response, error in
               DispatchQueue.main.async {
                   if let error = error {
                       // Log errors only if they are critical
                       self.errorMessage = "Go Back error: \(error.localizedDescription)"
                       return
                   }
                   if let http = response as? HTTPURLResponse {
                       if http.statusCode != 200 {
                           // Show only error if it's not a 200 status
                           self.errorMessage = "Go Back failed: HTTP \(http.statusCode)"
                       }
                       // Success, no need to show error message
                   }
               }
           }.resume()
       }
    
    func fetchActiveDevice(authToken: String) {
        let url = URL(string: "https://api.spotify.com/v1/me/player/devices")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTaskPublisher(for: req)
            .tryMap { out -> Data in
                guard let resp = out.response as? HTTPURLResponse, resp.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return out.data
            }
            .decode(type: DevicesResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { comp in
                if case .failure(let err) = comp {
                    self.errorMessage = "Devices fetch error: \(err.localizedDescription)"
                    self.deviceAvailable = false
                }
            }, receiveValue: { (resp: DevicesResponse) in
                if let device = resp.devices.first(where: { $0.is_active }) {
                    self.activeDeviceId = device.id
                    self.deviceAvailable = true
                    self.errorMessage = "Device connected: \(device.name)"
                } else {
                    self.errorMessage = "No active Spotify device found.\nPlease open Spotify and tap Refresh."
                    self.deviceAvailable = false
                }
                print("▶️ Active device:", self.activeDeviceId ?? "none")
            })
            .store(in: &cancellables)
    }

    // MARK: – Playback Actions

    /// Play a full playlist
    func playPlaylist(authToken: String, playlistURI: String) {
        guard let deviceId = activeDeviceId else {
            self.errorMessage = "⚠️ No active device. Open Spotify and hit Refresh."
            return
        }
        let urlString = "https://api.spotify.com/v1/me/player/play?device_id=\(deviceId)"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "context_uri": playlistURI,
            "offset": ["position": 0],
            "position_ms": 0
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("▶️ Sending playPlaylist to URL:", urlString)
        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Playback error: \(error.localizedDescription)"
                    return
                }
                if let http = response as? HTTPURLResponse {
                    print("▶️ playPlaylist statusCode:", http.statusCode)
                    self.errorMessage = http.statusCode == 204
                        ? nil
                        : "Playback failed: HTTP \(http.statusCode)"
                }
            }
        }.resume()
    }

    /// Play an array of tracks (e.g. liked songs)
    func playTracks(authToken: String, trackURIs: [String]) {
        guard let deviceId = activeDeviceId else {
            self.errorMessage = "No active Spotify device.\nOpen Spotify and tap Refresh."
            return
        }
        let urlString = "https://api.spotify.com/v1/me/player/play?device_id=\(deviceId)"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "uris": trackURIs,
            "position_ms": 0
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("▶️ Sending playTracks to URL:", urlString)
        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Playback error: \(error.localizedDescription)"
                    return
                }
                if let http = response as? HTTPURLResponse {
                    print("▶️ playTracks statusCode:", http.statusCode)
                    self.errorMessage = http.statusCode == 204
                        ? nil
                        : "Playback failed: HTTP \(http.statusCode)"
                }
            }
        }.resume()
    }

    /// Pause playback
    func pausePlayback(authToken: String) {
        guard let deviceId = activeDeviceId else {
            self.errorMessage = "⚠️ No active device. Open Spotify and tap Refresh."
            return
        }
        let urlString = "https://api.spotify.com/v1/me/player/pause?device_id=\(deviceId)"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Log errors only if they are critical
                    self.errorMessage = "Pause error: \(error.localizedDescription)"
                    return
                }
                if let http = response as? HTTPURLResponse {
                    if http.statusCode != 200 {
                        // Show only error if it's not a 200 status
                        self.errorMessage = "Pause failed: HTTP \(http.statusCode)"
                    }
                    // Success, no need to show error message
                }
            }
        }.resume()
    }

    /// Skip to next track
    func skipToNextTrack(authToken: String) {
        guard let deviceId = activeDeviceId else {
            self.errorMessage = "⚠️ No active device. Open Spotify and tap Refresh."
            return
        }
        let urlString = "https://api.spotify.com/v1/me/player/next?device_id=\(deviceId)"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        print("⏭️ Sending skipToNextTrack to URL:", urlString)
        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Skip error: \(error.localizedDescription)"
                    return
                }
                if let http = response as? HTTPURLResponse {
                    if http.statusCode != 200 {
                        // Show only error if it's not a 200 status
                        self.errorMessage = "Skip failed: HTTP \(http.statusCode)"
                    }
                    // Success, no need to show error message
                }
            }
        }.resume()
    }
    /// Resume playback (no body, just resumes on the active device)
       func resumePlayback(authToken: String) {
           guard let deviceId = activeDeviceId else {
               self.errorMessage = "⚠️ No active device. Open Spotify and tap Refresh."
               return
           }
           let urlString = "https://api.spotify.com/v1/me/player/play?device_id=\(deviceId)"
           var req = URLRequest(url: URL(string: urlString)!)
           req.httpMethod = "PUT"
           req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
           // no body
           
           print("▶️ Sending resumePlayback to URL:", urlString)
           URLSession.shared.dataTask(with: req) { _, response, error in
               DispatchQueue.main.async {
                   if let error = error {
                       self.errorMessage = "Resume error: \(error.localizedDescription)"
                       return
                   }
                   if let http = response as? HTTPURLResponse {
                       if http.statusCode != 200 {
                           // Show only error if it's not a 200 status
                           self.errorMessage = "Resume failed: HTTP \(http.statusCode)"
                       }
                       // Success, no need to show error message
                   }
               }
           }.resume()
       }

       /// Toggle between play and pause based on current playback state
       func togglePlayback(authToken: String) {
           guard let deviceId = activeDeviceId else {
               self.errorMessage = "⚠️ No active device. Open Spotify and tap Refresh."
               return
           }
           let urlString = "https://api.spotify.com/v1/me/player?device_id=\(deviceId)"
           var req = URLRequest(url: URL(string: urlString)!)
           req.httpMethod = "GET"
           req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

           URLSession.shared.dataTask(with: req) { data, response, error in
               DispatchQueue.main.async {
                   if let error = error {
                       self.errorMessage = "Status error: \(error.localizedDescription)"
                       return
                   }
                   guard
                       let data = data,
                       let state = try? JSONDecoder().decode(PlayerState.self, from: data)
                   else {
                       self.errorMessage = "Failed to decode playback state."
                       return
                   }

                   if state.is_playing {
                       // currently playing → pause
                       self.pausePlayback(authToken: authToken)
                   } else {
                       // currently paused → resume
                       self.resumePlayback(authToken: authToken)
                   }
               }
           }.resume()
       }
   }


// MARK: – Models

struct DevicesResponse: Codable {
    let devices: [Device]
}

struct Device: Codable, Identifiable {
    let id: String
    let is_active: Bool
    let name: String
    let type: String
}

// Simple struct to decode { "is_playing": Bool, ... }
private struct PlayerState: Codable {
    let is_playing: Bool
}

struct CurrentlyPlayingResponse: Codable {
    let item: TrackItem
}

struct TrackItem: Codable {
    let name: String
    let artists: [SpotifyArtist]
}

struct SpotifyArtist: Codable {
    let name: String
}
