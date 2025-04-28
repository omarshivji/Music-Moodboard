import Foundation
import Combine

class SpotifyPlaybackManager: ObservableObject {
    @Published var activeDeviceId: String? = nil
    @Published var deviceAvailable: Bool = false
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
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
            }, receiveValue: { resp in
                if let device = resp.devices.first(where: { $0.is_active }) {
                    self.activeDeviceId = device.id
                    self.deviceAvailable = true
                    self.errorMessage = "Device connected: \(device.name)"  // Success message
                } else {
                    self.errorMessage = "No active Spotify device found. Please open the Spotify app."
                    self.deviceAvailable = false
                }
                print("▶️ Active device:", self.activeDeviceId ?? "none")
            })
            .store(in: &cancellables)
    }

    func playPlaylist(authToken: String, playlistURI: String) {
        // 1) Ensure we have an active device
        guard let deviceId = activeDeviceId else {
            DispatchQueue.main.async {
                self.errorMessage = "⚠️ No active device. Open the Spotify app and tap Refresh."
            }
            return
        }
        
        // 2) Build the URL including the device_id query
        let urlString = "https://api.spotify.com/v1/me/player/play?device_id=\(deviceId)"
        guard let url = URL(string: urlString) else { return }
        
        // 3) Create request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 4) JSON body
        let body: [String: Any] = [
            "context_uri": playlistURI,
            "offset": ["position": 0],
            "position_ms": 0
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // 5) Send & log response
        print("▶️ Sending playPlaylist to URL:", urlString)
        URLSession.shared.dataTask(with: request) { _, response, error in
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
    
    func playLikedSongs(authToken: String, likedTrackURIs: [String]) {
        playTracks(authToken: authToken, trackURIs: likedTrackURIs)
    }

    func playTracks(authToken: String, trackURIs: [String]) {
        guard let deviceId = activeDeviceId else {
            DispatchQueue.main.async {
                self.errorMessage = """
                No active Spotify device found.
                Please open the Spotify app or web player, start playing something, then tap Refresh.
                """
            }
            return
        }
        
        let urlString = "https://api.spotify.com/v1/me/player/play?device_id=\(deviceId)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "uris": trackURIs,
            "position_ms": 0
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("▶️ Sending playTracks to URL:", urlString)
        URLSession.shared.dataTask(with: request) { _, response, error in
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
}

// MARK: - Devices

struct DevicesResponse: Codable {
  let devices: [Device]
}

struct Device: Codable, Identifiable {
  let id: String
  let is_active: Bool
  let name: String
  let type: String
}
