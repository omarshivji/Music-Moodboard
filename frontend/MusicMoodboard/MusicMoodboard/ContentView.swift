import SwiftUI
import AVFoundation

struct FileSaveData {
    let title: String
    let timestamp: Date
}

struct ContentView: View {
    @State private var mood: String = "Chill"
    @State private var notes: String = ""
    @State private var song: String = ""
    @State private var timeRemaining: Int? = nil
    @State private var timer: Timer? = nil
    @State private var timerMinutes: Int? = nil
    @State private var colorScheme: ColorScheme = .light
    @State private var placeholderText: String = "Begin writing your thoughts..."
    @State private var showSavedMessage = false
    @State private var fileList: [URL] = []
    @State private var selectedFile: URL?
    @State private var showingFile = false
    @State private var showHistory = false
    @State private var showHistoryPicker = false
    @State private var selectedHistoryEntry: String? = nil
    @State private var audioPlayer: AVAudioPlayer? // Audio Player instance
    @State private var isPlaying: Bool = false // Track whether audio is playing
    @State private var showingFileImporter = false
    @State private var showHistoryPanel = false
    @State private var text: String = ""
    @State private var saveMessage: String? = nil
    @StateObject private var authManager = SpotifyAuthManager.shared



    let moods = ["Chill", "Focused", "Reflective", "Angsty", "Joyful"]
    let timerOptions: [Int?] = [nil, 15, 30, 60]

    var body: some View {
      GeometryReader { geo in
        HStack(spacing: 0) {
          // ─────────── Main Writing Area ───────────
            ZStack(alignment: .bottom) {
                (colorScheme == .light ? Color("Cream") : Color.black)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading) {
                        // 🎵 Currently Listening To
                        VStack(alignment: .leading) {
                            Text("Currently Listening To:")
                                .font(.headline)
                                .foregroundColor(.gray.opacity(1.8))
                                .padding(.leading, 10)
                                .padding(.top, 10)
                            
                            TextField("Enter song name...", text: $song)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.title3)
                                .foregroundColor(.gray.opacity(1.8))
                                .padding([.leading, .trailing], 10)
                        }
                        .padding(.bottom, 15)
                        
                        // 🌈 Mood Suggestions
                        if !moodBasedSuggestions(for: mood).isEmpty {
                            Text("Suggestions for '\(mood)' mood:")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(1.8))
                                .padding(.leading, 10)
                            
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(moodBasedSuggestions(for: mood), id: \.self) { suggestion in
                                        Text(suggestion)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                            .foregroundColor(.gray.opacity(1.8))
                                    }
                                }
                                .padding(.leading, 10)
                            }
                            .padding(.bottom, 15)
                        }
                        
                        // ▶️ Spotify Login / Status
                            if let token = authManager.accessToken {
                              Text("🔑 Authenticated! Token: \(token)")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .padding(.vertical, 4)
                            } else {
                              Button("Log in to Spotify") {
                                authManager.startAuthorization()
                              }
                              .padding(.vertical, 6)
                              .padding(.horizontal, 12)
                              .background(Color.green)
                              .foregroundColor(.white)
                              .cornerRadius(6)
                            }


                        // ✍️ Notes
                        TextEditor(text: $notes)
                            .font(fontForMood(mood: mood))  // Apply font to the TextEditor text
                            .padding(EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8))  // Adjust the padding here
                            .frame(minHeight: 1000)
                            .scrollContentBackground(.hidden)
                            .background(colorScheme == .light ? Color("Cream") : Color.black)
                            .foregroundColor(.gray.opacity(1.8))
                            .overlay(alignment: .topLeading) {
                                if notes.isEmpty {
                                    Text(placeholderText)  // Placeholder text
                                        .font(fontForMood(mood: mood))  // Ensure the same font as the TextEditor
                                        .foregroundColor(colorScheme == .light
                                                         ? .gray.opacity(0.7)
                                                         : .white.opacity(0.7))
                                        .padding(EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)) // Match padding with TextEditor
                                }
                            }
                        
                            .border(Color.clear)
                    }
                }
                
                // 🔽 Bottom Bar (Restored)
                HStack {
                    Button(action: cycleMood) {
                        Text(mood)
                            .foregroundColor(.gray.opacity(1.8))
                        // Removed padding here
                    }
                    .buttonStyle(.plain)  // Added this to remove the pill shape
                    
                    Spacer()
                    
                    Button(action: cycleTimer) {
                        Text(timerMinutes == nil ? "Timer" : "\(timerMinutes!) min")
                            .foregroundColor(.gray.opacity(1.8))
                        // Removed padding here
                    }
                    .buttonStyle(.plain)
                    
                    if let time = timeRemaining {
                        Text("⏱ \(formatTime(time))")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(1.8))
                            .padding(.leading)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            showHistoryPanel.toggle()
                        }
                    }) {
                        Text("History")
                            .foregroundColor(.gray.opacity(1.8))
                        // Removed padding here
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Play/Pause button
                    Button(action: {
                        if isPlaying {
                            audioPlayer?.pause()
                        } else {
                            audioPlayer?.play()
                        }
                        isPlaying.toggle()
                    }) {
                        Image(systemName: "music.note")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 10) // You can adjust this to suit the design
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Import MP3 button
                    Button(action: {
                        showingFileImporter = true
                    }) {
                        Label("Import MP3", systemImage: "square.and.arrow.down")
                            .foregroundColor(.gray.opacity(1.8))
                        // Removed padding here
                    }
                    .buttonStyle(.plain)
                    .fileImporter(
                        isPresented: $showingFileImporter,
                        allowedContentTypes: [.mp3],
                        allowsMultipleSelection: false
                    ) { result in
                        do {
                            guard let url = try result.get().first else { return }
                            selectedFile = url
                            song = url.deletingPathExtension().lastPathComponent
                            audioPlayer = try AVAudioPlayer(contentsOf: url)
                            audioPlayer?.prepareToPlay()
                            audioPlayer?.play()
                            isPlaying = true
                            embedSimpleMetadata(from: url)
                        } catch {
                            print("Import failed:", error)
                        }
                    }
                    
                    Spacer()
                    
                    // Dark/Light mode toggle button
                    Button(action: {
                        colorScheme = (colorScheme == .light) ? .dark : .light
                    }) {
                        Image(systemName: colorScheme == .light ? "sun.max.fill" : "moon.fill")
                            .foregroundColor(.gray.opacity(1.8))
                            .padding(.horizontal) // You can keep or remove this depending on spacing preference
                    }
                    .buttonStyle(.plain)
                    
                    // Save button
                    Button(action: saveEntryToFile) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.gray.opacity(1.8))
                        // Removed .padding(.vertical, 10) and .padding(.horizontal, 20) for minimalism
                            .cornerRadius(10)  // Optional: only if you still want rounded corners
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal) // You can keep this for spacing around the button group
                }
                .padding()  // Outer padding around the HStack
                .background((colorScheme == .light ? Color("Cream") : Color.black).opacity(0.8))
            }
            
            Button("Login with Spotify") {
                // Safely unwrap the authURL from SpotifyAuthManager
                if let authURL = SpotifyAuthManager.shared.authURL {
                    NSWorkspace.shared.open(authURL)
                } else {
                    print("Error: Failed to generate the Spotify authorization URL.")
                }
            }

            
            // ✅ Saved Message
            if showSavedMessage {
                Text("Entry Saved")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.gray.opacity(0.8)) //
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .cornerRadius(10) // Optional: can keep if you want rounded corners without a background
                    .transition(.opacity)
            }

        

            // ─────────── History Panel ───────────
            if showHistoryPanel {
              Divider()  // optional thin line

              ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(fileList, id: \.self) { url in
                      // Wrap the entire row in a Button:
                      Button(action: {
                        // Load file into your TextEditor
                        loadFileContent(from: url)
                        // Close the sidebar
                        withAnimation { showHistoryPanel = false }
                      }) {
                        HStack {
                          VStack(alignment: .leading, spacing: 4) {
                            Text(url.deletingPathExtension().lastPathComponent)
                              .lineLimit(1)
                            Text(displayDate(for: url))
                              .font(.caption)
                              .foregroundColor(.secondary)
                          }
                          Spacer()
                          // Keep delete button as-is
                          Button(action: {
                            deleteHistoryFile(at: url)
                          }) {
                            Text("🗑️")
                          }
                          .buttonStyle(.plain)
                          .help("Delete this file")
                        }
                        .padding(.horizontal)
                      }
                      .buttonStyle(.plain)  // ensure only your custom highlight
                      Divider()
                    }

                }
              }
              .frame(width: geo.size.width * 0.25)    // 25% width for history panel
              .background((colorScheme == .light ? Color("Cream") : Color.black))
              .transition(.move(edge: .trailing))
              .animation(.easeInOut, value: showHistoryPanel)
            }

               }
               .sheet(isPresented: $showingFile) {
                 if let selectedFile = selectedFile {
                   MarkdownViewer(fileURL: selectedFile)
                 }
               }
               .onAppear(perform: loadSavedFiles)
               .preferredColorScheme(colorScheme)
             }
           }

    


    // MARK: - File Management
    private var saveDirectoryURL: URL {
        // Retrieve the Downloads directory
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        return downloadsDirectory.appendingPathComponent("Entries", isDirectory: true)
    }

    private func createSaveDirectoryIfNeeded() {
        let fm = FileManager.default
        let dir = saveDirectoryURL
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                print("Created Entries folder in Downloads folder at:", dir.path)
            } catch {
                print("❌ Failed to create Entries folder in Downloads:", error)
            }
        }
    }

    private func saveEntryToFile() {
        createSaveDirectoryIfNeeded()

        // Build a timestamped filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Entry-\(timestamp).md"

        // Full URL for the new markdown file
        let fileURL = saveDirectoryURL.appendingPathComponent(filename)

        // Build markdown content
        let md = """
        # \(mood)
        **Song:** \(song)

        \(notes)
        """

        // Write the markdown file
        do {
            try md.write(to: fileURL, atomically: true, encoding: .utf8)
            showSavedMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSavedMessage = false
            }
            loadSavedFiles()
        } catch {
            print("❌ Write error:", error)
        }
    }

    private func loadSavedFiles() {
        let fm = FileManager.default
        let folderURL = saveDirectoryURL

        do {
            if !fm.fileExists(atPath: folderURL.path) {
                fileList = []
                return
            }

            let files = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            fileList = files.filter { $0.pathExtension.lowercased() == "md" }
        } catch {
            print("❌ Error loading files:", error)
            fileList = []
        }
    }
    private func displayDate(for url: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let creationDate = attributes?[.creationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: creationDate)
        }
        return "Unknown Date"
    }

    private func deleteHistoryFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadSavedFiles()
        } catch {
            print("❌ Failed to delete file:", error)
        }
    }

    private func moodBasedSuggestions(for mood: String) -> [String] {
        // Just an example. You can implement based on your needs.
        switch mood {
        case "Chill":
            return ["Lo-fi Beats", "Acoustic", "Jazz"]
        case "Focused":
            return ["Classical", "Instrumental", "Electronic"]
        case "Reflective":
            return ["Indie", "Ambient", "Acoustic"]
        case "Angsty":
            return ["Rock", "Punk", "Alternative"]
        case "Joyful":
            return ["Pop", "Dance", "Happy Tunes"]
        default:
            return []
        }
    }

    private func playSong() {
        guard let url = selectedFile else {
            print("No audio file selected!")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing song: \(error.localizedDescription)")
        }
    }


    private func cycleMood() {
        if let currentIndex = moods.firstIndex(of: mood), currentIndex < moods.count - 1 {
            mood = moods[currentIndex + 1]
        } else {
            mood = moods.first!
        }
    }

    // MARK: – Timer Controls

    private func cycleTimer() {
        // advance through [nil, 15, 30, 60]
        if let idx = timerOptions.firstIndex(of: timerMinutes) {
            timerMinutes = timerOptions[(idx + 1) % timerOptions.count]
        } else {
            timerMinutes = timerOptions.first!
        }

        // stop any old timer
        timer?.invalidate()

        // if we've picked a minute value, start counting down
        if let mins = timerMinutes {
            startTimer(minutes: mins)
        } else {
            timeRemaining = nil
        }
    }

    private func startTimer(minutes: Int) {
        timeRemaining = minutes * 60

        // schedule new timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let tr = timeRemaining, tr > 0 {
                timeRemaining = tr - 1
            } else {
                // once we hit zero, stop the timer
                timer?.invalidate()
                timeRemaining = nil
            }
        }
    }

    private func formatTime(_ time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func fileTimeString(_ file: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        if let creationDate = attributes?[.creationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy HH:mm"
            return formatter.string(from: creationDate)
        }
        return "Unknown"
    }

    private func loadFileContent(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            notes = content
        } catch {
            print("Error loading file content: \(error.localizedDescription)")
        }
    }
    
    private func fontForMood(mood: String) -> Font {
        switch mood {
        case "Chill":
            return .system(size: 24, weight: .light, design: .default)
        case "Focused":
            return .system(size: 24, weight: .bold, design: .serif)
        case "Reflective":
            return .system(size: 24, weight: .regular, design: .rounded)
        case "Angsty":
            return .system(size: 24, weight: .heavy, design: .monospaced)
        case "Joyful":
            return .system(size: 24, weight: .medium, design: .default)
        default:
            return .system(size: 24, weight: .regular, design: .default)
        }
    }
    
    /// Appends a simple “Now Playing” line using file name + player.duration
    private func embedSimpleMetadata(from url: URL) {
        // 1) Title = file name without extension
        let title = url.deletingPathExtension().lastPathComponent
        
        // 2) Duration = audioPlayer’s duration (in seconds)
        let totalSeconds = Int(audioPlayer?.duration ?? 0)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        let durationStr = String(format: "%02d:%02d", mins, secs)
        
        // 3) Build your line and append to notes
        let nowPlaying = "Now Playing: \(title) [\(durationStr)]"
        notes += "\n\n" + nowPlaying + "\n"
    }
    
}
