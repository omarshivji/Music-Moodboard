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
    @State private var showHistoryPanel = false
    @State private var showSpotifyPanel = false   // ← new!
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var showingFileImporter = false
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
                        VStack(alignment: .leading, spacing: 16) {
//                            // 🎵 Currently Listening To
//                            VStack(alignment: .leading) {
//                                Text("Currently Listening To:")
//                                    .font(.headline)
//                                    .foregroundColor(.gray.opacity(1.8))
//                                    .padding(.horizontal, 10)
//                                TextField("Enter song name...", text: $song)
//                                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                                    .font(.title3)
//                                    .foregroundColor(.gray.opacity(1.8))
//                                    .padding(.horizontal, 10)
//                            }

                            // 🌈 Mood Suggestions
                            if !moodBasedSuggestions(for: mood).isEmpty {
                                Text("Suggestions for ‘\(mood)’:")
                                    .font(.headline)
                                    .foregroundColor(.gray.opacity(1.8))
                                    .padding(.horizontal, 10)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(moodBasedSuggestions(for: mood), id: \.self) { suggestion in
                                            Text(suggestion)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(8)
                                                .foregroundColor(.gray.opacity(1.8))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                }
                            }

                            // ✍️ Notes
                            TextEditor(text: $notes)
                                .font(fontForMood(mood: mood))
                                .padding(8)
                                .frame(minHeight: 200)
                                .scrollContentBackground(.hidden)
                                .background(colorScheme == .light ? Color("Cream") : Color.black)
                                .foregroundColor(.gray.opacity(1.8))
                                .overlay(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text(placeholderText)
                                            .font(fontForMood(mood: mood))
                                            .foregroundColor(colorScheme == .light
                                                             ? .gray.opacity(0.7)
                                                             : .white.opacity(0.7))
                                            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                                    }
                                }

                            // ─────────── SpotifyLibraryView ───────────
                            // (only visible when panel open, but you can leave here if needed)
                            // .opacity(showSpotifyPanel ? 1 : 0)
                        }
                    }

                    // 🔽 Bottom Bar
                    HStack {
                        Button(action: cycleMood) {
                            Text(mood)
                                .foregroundColor(.gray.opacity(1.8))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(action: cycleTimer) {
                            Text(timerMinutes == nil ? "Timer" : "\(timerMinutes!) min")
                                .foregroundColor(.gray.opacity(1.8))
                        }
                        .buttonStyle(.plain)

                        if let time = timeRemaining {
                            Text("⏱ \(formatTime(time))")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(1.8))
                        }

                        Spacer()

                        // ← music.note now toggles Spotify panel →
                        Button(action: {
                            withAnimation { showSpotifyPanel.toggle() }
                        }) {
                            Image(systemName: "music.note")
                                .font(.system(size: 18))
                                .foregroundColor(.gray.opacity(1.8))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(action: {
                            withAnimation { showHistoryPanel.toggle() }
                        }) {
                            Text("History")
                                .foregroundColor(.gray.opacity(1.8))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Dark/Light Toggle
                        Button(action: {
                            colorScheme = (colorScheme == .light ? .dark : .light)
                        }) {
                            Image(systemName: colorScheme == .light ? "sun.max.fill" : "moon.fill")
                                .foregroundColor(.gray.opacity(1.8))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Save
                        Button(action: saveEntryToFile) {
                            Text("Save")
                                .foregroundColor(.gray.opacity(1.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background((colorScheme == .light ? Color("Cream") : Color.black).opacity(0.8))
                }

                // ─────────── Spotify Panel ───────────
                if showSpotifyPanel {
                    Divider()
                    SpotifyLibraryView()
                        .environmentObject(authManager)
                        .frame(width: geo.size.width * 0.25)
                        .background(colorScheme == .light ? Color("Cream") : Color.black)
                        .transition(.move(edge: .leading))
                }

                // ─────────── History Panel ───────────
                if showHistoryPanel {
                    Divider()
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(fileList, id: \.self) { url in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                        Text(displayDate(for: url))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("🗑️") { deleteHistoryFile(at: url) }
                                        .buttonStyle(.plain)
                                }
                                .padding(.horizontal)
                                Divider()
                            }
                        }
                    }
                    .frame(width: geo.size.width * 0.25)
                    .background((colorScheme == .light ? Color("Cream") : Color.black))
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .sheet(isPresented: $showingFile) {
            if let file = selectedFile {
                MarkdownViewer(fileURL: file)
            }
        }
        .onAppear(perform: loadSavedFiles)
        .preferredColorScheme(colorScheme)
    }

    // … all of your existing helper methods (saveEntryToFile, loadSavedFiles, displayDate, fontForMood, cycleMood, cycleTimer, etc.) go here unchanged …

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
