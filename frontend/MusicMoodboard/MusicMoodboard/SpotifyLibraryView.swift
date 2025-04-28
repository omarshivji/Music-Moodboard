import SwiftUI

struct SpotifyLibraryView: View {
    @EnvironmentObject var authManager: SpotifyAuthManager
    @StateObject private var playbackManager = SpotifyPlaybackManager()
    
    @State private var likedSongs: [Track] = []
    @State private var playlists: [Playlist] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if let token = authManager.accessToken {
                // 1) Refresh
                HStack {
                    Button("🔄 Refresh") {
                        loadAll(authToken: token)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
                .padding(.top, 8)
                
                // 2) Loading & errors
                if isLoading {
                    ProgressView()
                        .padding(.horizontal)
                }
                if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                if let deviceErr = playbackManager.errorMessage {
                    Text(deviceErr)
                        .foregroundColor(.orange)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Divider()
                    .padding(.vertical, 8)
                
                // 3) Liked Songs
                if !likedSongs.isEmpty {
                    Text("Your Top Tracks")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button("▶️ Play All Liked Songs") {
                        playbackManager.playTracks(
                            authToken: token,
                            trackURIs: likedSongs.map { $0.uri }
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(likedSongs) { track in
                                TrackRow(track: track)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                }
                
                // 4) Playlists
                if !playlists.isEmpty {
                    Text("Your Playlists")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(playlists) { pl in
                                HStack {
                                    Text(pl.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Button("▶️ Play") {
                                        playbackManager.playPlaylist(
                                            authToken: token,
                                            playlistURI: pl.uri
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 4)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                }
                
            } else {
                // Not authenticated
                VStack(spacing: 12) {
                    Text("Not logged in to Spotify")
                        .foregroundColor(.secondary)
                    
                    Button("Log in to Spotify") {
                        authManager.startAuthorization()
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
                .padding()
            }
        }
        .onAppear {
            if let token = authManager.accessToken {
                loadAll(authToken: token)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func loadAll(authToken: String) {
        isLoading = true
        errorMessage = nil

        // Fetch active device
        playbackManager.fetchActiveDevice(authToken: authToken)

        // Fetch liked songs
        fetchLikedSongs(authToken: authToken) { songs, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Songs fetch error: \(error.localizedDescription)"
                } else {
                    self.likedSongs = songs ?? []
                }
            }
        }

        // Fetch playlists
        fetchPlaylists(authToken: authToken) { pls, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Playlists fetch error: \(error.localizedDescription)"
                } else {
                    self.playlists = pls ?? []
                }
            }
        }
    }
}

// MARK: - Track Row View

private struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = track.album.images.first?.url,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 48, height: 48)
                .cornerRadius(4)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(track.artists.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
