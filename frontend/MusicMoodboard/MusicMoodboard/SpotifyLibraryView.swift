// SpotifyLibraryView.swift
import SwiftUI

struct SpotifyLibraryView: View {
  @EnvironmentObject var authManager: SpotifyAuthManager
  @State private var likedSongs: [Track] = []
  @State private var playlists: [Playlist] = []

  var body: some View {
    VStack(spacing: 16) {
      // only show the buttons once you're authenticated
      if let token = authManager.accessToken {
        HStack {
          Button("Fetch Liked Songs") {
            fetchLikedSongs(authToken: token) { songs, error in
              DispatchQueue.main.async {
                self.likedSongs = songs ?? []
              }
            }
          }
          Button("Fetch Playlists") {
            fetchPlaylists(authToken: token) { pls, error in
              DispatchQueue.main.async {
                self.playlists = pls ?? []
              }
            }
          }
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding(.bottom, 8)

        // Show your Liked Songs
        if !likedSongs.isEmpty {
          Text("Your Top Tracks")
            .font(.headline)
          ForEach(likedSongs) { track in
            HStack(spacing: 12) {
              // album art
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

        Divider().padding(.vertical, 8)

        // Show your Playlists
        if !playlists.isEmpty {
          Text("Your Playlists")
            .font(.headline)
          ForEach(playlists) { pl in
            Text(pl.name)
              .font(.subheadline)
          }
        }

      } else {
        Text("Log in to Spotify above to fetch your library.")
          .foregroundColor(.secondary)
      }
    }
    .padding()
  }
}
