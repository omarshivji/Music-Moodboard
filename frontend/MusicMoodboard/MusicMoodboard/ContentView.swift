import SwiftUI
import AVFoundation

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



    let moods = ["Chill", "Focused", "Reflective", "Angsty", "Joyful"]
    let timerOptions: [Int?] = [nil, 15, 30, 60]

    var body: some View {
        ZStack {
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

                        // ✍️ Notes
                        TextEditor(text: $notes)
                            .font(fontForMood(mood: mood))
                            .padding() // Padding inside the TextEditor for more space
                            .frame(minHeight: 1000, maxHeight: 1000) // Adjust the height as needed
                            .background(Color.clear) // Make the background completely clear to remove any box appearance
                            .cornerRadius(10) // Optional: Rounded corners for the background
                            .foregroundColor(.gray.opacity(1.8))
                            .overlay(alignment: .topLeading) {
                                if notes.isEmpty {
                                    Text(placeholderText)
                                        .foregroundColor(colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.7))
                                        .padding()
                                }
                            }

                            .border(Color.clear) // Ensure no border is visible

                        if showHistory {
                            Text("Previous Entries")
                                .font(.headline)
                                .foregroundColor(.gray.opacity(1.8))
                                .padding(.horizontal)

                            let sortedFiles = fileList.sorted { $0.lastPathComponent > $1.lastPathComponent }
                            ForEach(Array(sortedFiles.enumerated()), id: \.element) { index, file in
                                Button(action: {
                                    selectedFile = file
                                    showingFile = true
                                }) {
                                    HStack {
                                        Text("Entry \(index + 1) – \(displayDate(for: file))")
                                            .font(.subheadline)
                                            .foregroundColor(.gray.opacity(1.8))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(fileTimeString(file))
                                            .font(.caption)
                                            .foregroundColor(colorScheme == .light ? .black.opacity(0.6) : .white.opacity(0.6))
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                    }
                    .padding(.bottom, 70)
                }

                // 🔽 Bottom Bar
                HStack {
                    Button(action: cycleMood) {
                        Text(mood)
                            .foregroundColor(.gray.opacity(1.8))
                            .padding(.horizontal)
                    }

                    Spacer()

                    Button(action: cycleTimer) {
                        Text(timerMinutes == nil ? "Timer" : "\(timerMinutes!) min")
                            .foregroundColor(.gray.opacity(1.8))
                            .padding(.horizontal)
                    }

                    if let time = timeRemaining {
                        Text("⏱ \(formatTime(time))")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(1.8))
                            .padding(.leading)
                    }

                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            showHistoryPicker.toggle()
                        }
                    }) {
                        Text("History")
                            .foregroundColor(.gray.opacity(1.8))
                            .padding(.horizontal)
                    }

                    Spacer()

                    // After: this simply toggles play/pause on the existing player
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
                            .padding(.horizontal, 10)
                    }


                    Spacer()
                    
                    Button(action: {
                        showingFileImporter = true
                    }) {
                        Label("Import MP3", systemImage: "square.and.arrow.down")
                            .padding()
                            .foregroundColor(.gray.opacity(1.8))
                    }
                    .fileImporter(
                      isPresented: $showingFileImporter,
                      allowedContentTypes: [.mp3],
                      allowsMultipleSelection: false
                    ) { result in
                      do {
                        guard let url = try result.get().first else { return }
                        selectedFile = url

                        // auto-fill your “song” field from the file name
                        song = url.deletingPathExtension().lastPathComponent

                        // prepare the player
                        audioPlayer = try AVAudioPlayer(contentsOf: url)
                        audioPlayer?.prepareToPlay()
                        audioPlayer?.play()
                        isPlaying = true

                        // **embed simplified metadata** now that `audioPlayer` is ready
                        embedSimpleMetadata(from: url)

                      } catch {
                        print("Import failed:", error)
                      }
                    }

                    Spacer()
                    
                    Button(action: {
                        colorScheme = (colorScheme == .light) ? .dark : .light
                    }) {
                        Image(systemName: colorScheme == .light ? "sun.max.fill" : "moon.fill")
                            .foregroundColor(.gray.opacity(1.8))
                            .padding(.horizontal)
                    }

                    Button(action: saveEntryToFile) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.gray.opacity(1.8))  // Adjust text color based on colorScheme
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background((colorScheme == .light ? Color("Cream") : Color.black).opacity(0.8))
            }

            // ✅ Saved Message
            if showSavedMessage {
                Text("Entry Saved")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(Color("Cream"))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .transition(.opacity)
            }
            
            // History Picker View
            if showHistoryPicker {
                VStack {
                    Text("Select a previous entry:")
                        .font(.headline)
                        .padding()

                    Button(action: {
                        // Action to show the popover
                        showHistoryPicker.toggle()
                    }) {
                        Text("History")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .popover(isPresented: $showHistoryPicker) {
                        VStack {
                            ForEach(fileList.prefix(3), id: \.self) { file in
                                Button(action: {
                                    if let url = URL(string: file.absoluteString) {
                                        loadFileContent(from: url)
                                        showHistoryPicker = false
                                    }
                                }) {
                                    Text(displayDate(for: file))
                                        .padding()
                                }
                            }
                        }
                        .padding()
                    }

                    Button("Load Entry") {
                        if let selectedEntry = selectedHistoryEntry,
                           let url = URL(string: selectedEntry) {
                            loadFileContent(from: url)
                            showHistoryPicker = false
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 10)
                .padding()
            }


        }
        .onAppear(perform: loadSavedFiles)
        .sheet(isPresented: $showingFile) {
            if let selectedFile = selectedFile {
                MarkdownViewer(fileURL: selectedFile)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSavedMessage)
        .preferredColorScheme(colorScheme)
    }

    // MARK: - File Management

    // 1. Computed property for our target folder
    private var saveDirectoryURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MusicMoodboard")
    }

    // 2. Ensure the folder exists
    private func createSaveDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: saveDirectoryURL.path) {
            do {
                try fm.createDirectory(
                    at: saveDirectoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("❌ Failed to create directory:", error)
            }
        }
    }

    // 3. The replacement for your old saveEntryToFile()
    private func saveEntryToFile() {
        // 3a. Make sure the folder exists
        createSaveDirectoryIfNeeded()

        // 3b. Build a timestamped filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Entry-\(timestamp).md"

        // 3c. Full URL for the new markdown file
        let fileURL = saveDirectoryURL.appendingPathComponent(filename)

        // 3d. Build markdown content
        let md = """
        # \(mood)
        **Song:** \(song)

        \(notes)
        """

        // 3e. Write it out
        do {
            try md.write(to: fileURL, atomically: true, encoding: .utf8)
            showSavedMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSavedMessage = false
            }
            // Reload your history if needed
            loadSavedFiles()
        } catch {
            print("❌ Write error:", error)
        }
    }


    // 2. Adjusted loader
    private func loadSavedFiles() {
        let fm = FileManager.default
        let folderURL = saveDirectoryURL

        do {
            // Ensure the folder exists (optional)
            if !fm.fileExists(atPath: folderURL.path) {
                fileList = []
                return
            }

            // Grab all files, pick out the .md ones
            let files = try fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            fileList = files.filter { $0.pathExtension.lowercased() == "md" }
        } catch {
            print("❌ Error loading files:", error)
            fileList = []
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

    private func displayDate(for file: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        if let creationDate = attributes?[.creationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
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
