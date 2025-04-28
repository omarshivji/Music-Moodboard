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
                // ── Refresh Device ──
                HStack {
                    Button("🔄 Refresh") {
                        isLoading = true
                        playbackManager.fetchActiveDevice(authToken: token)
                        loadLibrary(authToken: token)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
                
                // ── Status & Errors ──
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
                if let devErr = playbackManager.errorMessage {
                    Text(devErr)
                        .foregroundColor(.orange)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Divider().padding(.vertical, 8)

                // ── Liked Songs ──
                if !likedSongs.isEmpty {
                    Text("Your Top Tracks")
                        .font(.headline)
                        .padding(.horizontal)

                    // Play / Pause / Skip Controls
                    HStack(spacing: 20) {
                        Button("⏮️") {
                            playbackManager.goBack(authToken: token)
                        }
                        .buttonStyle(.plain)

                        Button("⏯️") {
                            playbackManager.togglePlayback(authToken: token)
                        }
                        .buttonStyle(.plain)

                        Button("⏭️") {
                            playbackManager.skipToNextTrack(authToken: token)
                        }
                        .buttonStyle(.plain)
                    }

                    // Play All Liked Songs
                    Button("▶️ Play All Liked Songs") {
                        playbackManager.playTracks(
                            authToken: token,
                            trackURIs: likedSongs.map(\.uri)
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

                    Divider().padding(.vertical, 8)
                }

                // ── Playlists ──
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
                                    Button("▶️") {
                                        playbackManager.playPlaylist(
                                            authToken: token,
                                            playlistURI: pl.uri
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    Divider().padding(.vertical, 8)
                }

            } else {
                // ── Not Authenticated ──
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
                loadLibrary(authToken: token)
                playbackManager.fetchActiveDevice(authToken: token)
            }
        }
    }

    private func loadLibrary(authToken: String) {
        isLoading = true
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

// MARK: – TrackRow

private struct TrackRow: View {
    let track: Track
    var body: some View {
        HStack(spacing: 12) {
            if let url = URL(string: track.album.images.first?.url ?? "") {
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
